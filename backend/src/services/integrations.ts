import { createHmac, randomBytes } from 'node:crypto';
import { lookup } from 'node:dns/promises';
import { isIP } from 'node:net';
import { Hono } from 'hono';
import { z } from 'zod';
import { requireCan, type RequestContext } from '../context.js';
import { TextArray } from '../db/sql.js';
import type { Row } from '../db/types.js';
import { ctxOf, intParam, readJson, type Env } from '../http.js';
import { conflict, notFound, unprocessable } from '../lib/errors.js';
import { isUuid, sha256 } from '../lib/ids.js';
import { audit, num, sectionGuard } from './section.js';

/// Integrations (/v1/integrations): the apps a restaurant links, outgoing
/// webhooks, partner API keys, the sync-job queue and their logs.
///
/// What is live: webhook test deliveries are really sent (HTTPS, public
/// hosts only, HMAC-signed); API keys are generated and stored as hashes.
/// What is not: no provider adapter exists yet, so a connection request
/// stays "pending" until the Proviyaa team links it, and a sync job for an
/// app that is not connected fails with that reason.

export interface Provider {
  key: string;
  name: string;
  category: 'delivery' | 'payments' | 'communication' | 'ecommerce' | 'accounting';
  description: string;
  capabilities?: string[];
  beta?: boolean;
}

export const PROVIDERS: Provider[] = [
  { key: 'zomato', name: 'Zomato Restaurant', category: 'delivery', description: 'Orders, menu and item availability with Zomato.' },
  { key: 'swiggy', name: 'Swiggy Partner', category: 'delivery', description: 'Orders, menu and item availability with Swiggy.' },
  { key: 'razorpay', name: 'Razorpay', category: 'payments', description: 'Online payments, payment links and settlements.' },
  { key: 'phonepe_business', name: 'PhonePe Business', category: 'payments', description: 'PhonePe Business settlements integration.' },
  { key: 'paytm_business', name: 'Paytm Business', category: 'payments', description: 'Paytm Business settlements & ledger sync.' },
  { key: 'google_pay_business', name: 'Google Pay Business', category: 'payments', description: 'Google Pay Business payments workflow.' },
  { key: 'whatsapp_business', name: 'WhatsApp Business', category: 'communication', description: 'Order updates, campaigns, OTPs over Cloud API.' },
  { key: 'sms_gateway', name: 'SMS Gateway', category: 'communication', description: 'Transactional SMS for direct guest notifications.' },
  { key: 'email_smtp', name: 'Email SMTP', category: 'communication', description: 'Invoices, reports, and marketing dispatch channel.' },
  { key: 'push_notifications', name: 'Push Notifications', category: 'communication', description: 'Real-time push alerts to staff and customer mobile apps.' },
  { key: 'google_calendar', name: 'Google Calendar', category: 'communication', description: 'Push reservations, shifts and production plans to Calendar.', beta: true },
  { key: 'google_drive', name: 'Google Drive', category: 'communication', description: 'Auto-archive reports, invoices and exports to Drive folders.' },
  { key: 'amazon_marketplace', name: 'Amazon Marketplace', category: 'ecommerce', description: 'Sync orders, inventory and product listings with Amazon Seller Central.', capabilities: ['Orders', 'Inventory', 'Listings'] },
  { key: 'tally_prime', name: 'Tally Prime', category: 'accounting', description: 'Push sales, purchases and payments to Tally.' },
];
const providerByKey = (key: string) => PROVIDERS.find((p) => p.key === key);

export const WEBHOOK_EVENTS = [
  'order.created',
  'order.status_changed',
  'order.paid',
  'kot.created',
  'inventory.low_stock',
  'customer.created',
  'settlement.completed',
];

export const API_SCOPES = [
  'orders:read',
  'orders:write',
  'menu:read',
  'menu:write',
  'payments:read',
  'reports:read',
  'customers:read',
  'inventory:read',
];

async function integrationRows(ctx: RequestContext): Promise<Row[]> {
  const rows = await ctx.db.query<Row>(`select * from pos_integrations where organization_id = $1`, [ctx.m.organization_id]);
  const channels = await ctx.db.query<Row>(`select channel, is_connected from channel_integrations where organization_id = $1`, [
    ctx.m.organization_id,
  ]);
  return PROVIDERS.map((p) => {
    const row = rows.find((r) => r.provider === p.key);
    const channel = channels.find((ch) => ch.channel === p.key);
    const status = channel?.is_connected === true ? 'connected' : ((row?.status as string) ?? 'not_connected');
    return {
      ...p,
      status,
      account_ref: row?.account_ref ?? '',
      last_sync_at: row?.last_sync_at ?? null,
      last_error: row?.last_error ?? '',
      requested_at: row?.created_at ?? null,
      updated_at: row?.updated_at ?? null,
    };
  });
}

// ── webhook delivery (outgoing) ────────────────────────────────────────────

const PRIVATE_V4 = [/^10\./, /^127\./, /^169\.254\./, /^172\.(1[6-9]|2\d|3[01])\./, /^192\.168\./, /^0\./, /^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\./];
function isPrivateAddress(ip: string): boolean {
  if (isIP(ip) === 4) return PRIVATE_V4.some((r) => r.test(ip));
  const v6 = ip.toLowerCase();
  return v6 === '::1' || v6 === '::' || v6.startsWith('fc') || v6.startsWith('fd') || v6.startsWith('fe80') || v6.startsWith('::ffff:');
}

/// Only public HTTPS hosts: a webhook must never be a way to reach the
/// server's own network.
export async function assertPublicUrl(raw: string): Promise<URL> {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw unprocessable('Enter a full URL, e.g. https://example.com/hooks/orders.');
  }
  if (url.protocol !== 'https:') throw unprocessable('Webhook URLs must use https://.');
  const host = url.hostname.replace(/^\[|\]$/g, '');
  if (host === 'localhost' || host.endsWith('.localhost') || host.endsWith('.local') || host.endsWith('.internal')) {
    throw unprocessable('Webhook URLs must point to a public host.');
  }
  if (isIP(host) && isPrivateAddress(host)) throw unprocessable('Webhook URLs must point to a public host.');
  return url;
}

async function deliver(ctx: RequestContext, endpoint: Row, event: string, payload: unknown) {
  const started = Date.now();
  let status: 'success' | 'failed' = 'failed';
  let httpStatus: number | null = null;
  let error = '';
  try {
    const url = await assertPublicUrl(String(endpoint.url));
    if (!isIP(url.hostname)) {
      const addrs = await lookup(url.hostname, { all: true });
      if (!addrs.length || addrs.some((a) => isPrivateAddress(a.address))) throw new Error('The host resolves to a private address.');
    }
    const body = JSON.stringify({ event, sent_at: new Date().toISOString(), data: payload });
    const signature = createHmac('sha256', String(endpoint.signing_secret)).update(body).digest('hex');
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Proviyaa-Event': event, 'X-Proviyaa-Signature': `sha256=${signature}` },
      body,
      redirect: 'manual',
      signal: AbortSignal.timeout(5000),
    });
    httpStatus = res.status;
    status = res.status >= 200 && res.status < 300 ? 'success' : 'failed';
    if (status === 'failed') error = `HTTP ${res.status}`;
  } catch (e) {
    error = e instanceof Error ? e.message : String(e);
  }
  const duration = Date.now() - started;
  await ctx.db.query(
    `insert into pos_webhook_deliveries (organization_id, endpoint_id, event, status, http_status, error, duration_ms)
     values ($1, $2, $3, $4, $5, $6, $7)`,
    [ctx.m.organization_id, endpoint.id, event, status, httpStatus, error.slice(0, 500), duration],
  );
  await ctx.db.query(`update pos_webhook_endpoints set last_tried_at = now(), last_status = $3 where id = $1 and organization_id = $2`, [
    endpoint.id,
    ctx.m.organization_id,
    status === 'success' ? `HTTP ${httpStatus}` : error.slice(0, 200),
  ]);
  return { status, http_status: httpStatus, error, duration_ms: duration };
}

const endpointView = (r: Row): Row => {
  const { signing_secret: secret, ...rest } = r;
  return { ...rest, signing_secret_hint: `…${String(secret).slice(-4)}` };
};

// ── API keys ───────────────────────────────────────────────────────────────

function newKey() {
  const key = `pv_live_${randomBytes(24).toString('base64url')}`;
  return { key, prefix: key.slice(0, 12), hash: sha256(key) };
}

const keyView = (r: Row): Row => {
  const now = Date.now();
  const status = r.revoked_at ? 'revoked' : r.expires_at && Date.parse(String(r.expires_at)) < now ? 'expired' : 'active';
  const { key_hash: _hash, ...rest } = r;
  return { ...rest, status };
};

async function createKey(ctx: RequestContext, name: string, scopes: string[], expiresInDays: number | null) {
  const k = newKey();
  const [row] = await ctx.db.insert<Row>('pos_api_keys', [
    {
      organization_id: ctx.m.organization_id,
      name,
      prefix: k.prefix,
      key_hash: k.hash,
      scopes: new TextArray(scopes),
      expires_at: expiresInDays ? new Date(Date.now() + expiresInDays * 86_400_000).toISOString() : null,
      created_by: ctx.identity.user_id,
    },
  ]);
  return { ...keyView(row!), key: k.key } as Row & { key: string };
}

export function integrationsRoutes(): Hono<Env> {
  const app = new Hono<Env>();
  app.use('*', sectionGuard('integrations'));

  app.get('/overview', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'read');
    const org = ctx.m.organization_id;
    const apps = await integrationRows(ctx);
    const [jobs] = await ctx.db.query<Row>(
      `select count(*) filter (where status = 'success')::int as ok, count(*) filter (where status = 'failed')::int as failed,
              count(*) filter (where status = 'queued')::int as queued
         from pos_sync_jobs where organization_id = $1`,
      [org],
    );
    const [hooks] = await ctx.db.query<Row>(
      `select count(*) filter (where active and direction = 'outgoing')::int as active,
              (select count(*) from pos_webhook_deliveries d where d.organization_id = $1 and d.status = 'success'
                  and d.created_at >= date_trunc('day', now()))::int as delivered_today
         from pos_webhook_endpoints where organization_id = $1 and deleted_at is null`,
      [org],
    );
    const [keys] = await ctx.db.query<Row>(
      `select count(*) filter (where revoked_at is null and (expires_at is null or expires_at > now()))::int as active
         from pos_api_keys where organization_id = $1`,
      [org],
    );
    const attention = await ctx.db.query<Row>(
      `select * from (
         select 'sync' as kind, provider as source, resource as detail, error, finished_at as at from pos_sync_jobs
          where organization_id = $1 and status = 'failed'
         union all
         select 'webhook', coalesce(e.name, 'Webhook'), d.event, d.error, d.created_at from pos_webhook_deliveries d
           left join pos_webhook_endpoints e on e.id = d.endpoint_id
          where d.organization_id = $1 and d.status = 'failed'
       ) t order by at desc nulls last limit 5`,
      [org],
    );
    const ok = num(jobs?.ok);
    const failed = num(jobs?.failed);
    const monthStart = new Date();
    monthStart.setDate(1);
    return c.json({
      data: {
        connected: apps.filter((a) => a.status === 'connected').length,
        pending: apps.filter((a) => a.status === 'pending').length,
        requested_this_month: apps.filter((a) => a.requested_at && Date.parse(String(a.requested_at)) >= monthStart.getTime()).length,
        sync_success_rate: ok + failed ? Math.round((ok / (ok + failed)) * 1000) / 10 : null,
        sync_failed: failed,
        sync_queued: num(jobs?.queued),
        webhook_endpoints: num(hooks?.active),
        deliveries_today: num(hooks?.delivered_today),
        api_keys: num(keys?.active),
        attention: attention.map((a) => ({ ...a, source: providerByKey(String(a.source))?.name ?? a.source })),
        pipelines: apps
          .filter((a) => a.status !== 'not_connected' && a.status !== 'disconnected')
          .map((a) => ({ key: a.key, name: a.name, status: a.status === 'connected' ? (a.last_error ? 'error' : 'healthy') : 'pending' })),
      },
    });
  });

  // ── connected apps ──
  app.get('/apps', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'read');
    const category = c.req.query('category');
    const rows = await integrationRows(ctx);
    return c.json({ data: category ? rows.filter((r) => r.category === category) : rows });
  });

  app.post('/apps/:provider/connect', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'write');
    const p = providerByKey(c.req.param('provider'));
    if (!p) throw notFound('This app is not in the Proviyaa app list.');
    const body = await readJson(c, z.object({ account_ref: z.string().trim().min(1, 'Enter your account / merchant ID.').max(120), note: z.string().trim().max(300).default('') }).strict());
    await ctx.db.query(
      `insert into pos_integrations (organization_id, provider, category, status, account_ref, config, connected_by)
       values ($1, $2, $3, 'pending', $4, $5, $6)
       on conflict (organization_id, provider) do update set status = 'pending', account_ref = excluded.account_ref,
         config = excluded.config, connected_by = excluded.connected_by, last_error = ''`,
      [ctx.m.organization_id, p.key, p.category, body.account_ref, { note: body.note }, ctx.identity.user_id],
    );
    await audit(ctx, 'Requested integration', 'Integration', null, { provider: p.key });
    const row = (await integrationRows(ctx)).find((r) => r.key === p.key);
    return c.json({
      data: row,
      message: `${p.name} connection requested. The Proviyaa team links it with your partner credentials; it shows "connected" once live.`,
    });
  });

  app.post('/apps/:provider/disconnect', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'write');
    const p = providerByKey(c.req.param('provider'));
    if (!p) throw notFound('This app is not in the Proviyaa app list.');
    const rows = await ctx.db.query(
      `update pos_integrations set status = 'disconnected' where organization_id = $1 and provider = $2 returning id`,
      [ctx.m.organization_id, p.key],
    );
    if (!rows.length) throw conflict(`${p.name} is not connected.`);
    await audit(ctx, 'Disconnected integration', 'Integration', null, { provider: p.key });
    return c.json({ data: (await integrationRows(ctx)).find((r) => r.key === p.key) });
  });

  // ── webhooks ──
  const webhookBody = z
    .object({
      name: z.string().trim().min(1, 'Name the endpoint.').max(120),
      url: z.string().trim().max(500),
      events: z.array(z.enum(WEBHOOK_EVENTS as [string, ...string[]])).min(1, 'Pick at least one event.'),
      active: z.boolean().default(true),
    })
    .strict();

  app.get('/webhooks', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'read');
    const rows = await ctx.db.query<Row>(
      `select * from pos_webhook_endpoints where organization_id = $1 and deleted_at is null order by created_at`,
      [ctx.m.organization_id],
    );
    const [counts] = await ctx.db.query<Row>(
      `select count(*)::int as deliveries, count(*) filter (where status = 'failed')::int as failed
         from pos_webhook_deliveries where organization_id = $1`,
      [ctx.m.organization_id],
    );
    return c.json({ data: rows.map(endpointView), events: WEBHOOK_EVENTS, counts: { deliveries: num(counts?.deliveries), dead_letter: num(counts?.failed) } });
  });

  app.post('/webhooks', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'write');
    const body = await readJson(c, webhookBody);
    await assertPublicUrl(body.url);
    const secret = `whsec_${randomBytes(20).toString('hex')}`;
    const [row] = await ctx.db.insert<Row>('pos_webhook_endpoints', [
      {
        organization_id: ctx.m.organization_id,
        direction: 'outgoing',
        name: body.name,
        url: body.url,
        events: new TextArray(body.events),
        active: body.active,
        signing_secret: secret,
        created_by: ctx.identity.user_id,
      },
    ]);
    await audit(ctx, 'Added webhook', 'Webhook', String(row!.id), { url: body.url });
    return c.json({ data: { ...endpointView(row!), signing_secret: secret } }, 201);
  });

  app.patch('/webhooks/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'write');
    const id = c.req.param('id');
    if (!isUuid(id)) throw notFound('This webhook was not found.');
    const body = await readJson(c, webhookBody.partial().strict());
    if (body.url !== undefined) await assertPublicUrl(body.url);
    const [row] = await ctx.db.query<Row>(
      `update pos_webhook_endpoints set name = coalesce($3, name), url = coalesce($4, url),
              events = coalesce($5::text[], events), active = coalesce($6, active)
        where id = $1 and organization_id = $2 and deleted_at is null returning *`,
      [id, ctx.m.organization_id, body.name ?? null, body.url ?? null, body.events ? new TextArray(body.events) : null, body.active ?? null],
    );
    if (!row) throw notFound('This webhook was not found.');
    return c.json({ data: endpointView(row) });
  });

  app.delete('/webhooks/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'delete');
    const id = c.req.param('id');
    if (!isUuid(id)) throw notFound('This webhook was not found.');
    const rows = await ctx.db.query(
      `update pos_webhook_endpoints set deleted_at = now() where id = $1 and organization_id = $2 and deleted_at is null returning id`,
      [id, ctx.m.organization_id],
    );
    if (!rows.length) throw notFound('This webhook was not found.');
    await audit(ctx, 'Deleted webhook', 'Webhook', id);
    return c.body(null, 204);
  });

  app.post('/webhooks/:id/test', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'write');
    const id = c.req.param('id');
    if (!isUuid(id)) throw notFound('This webhook was not found.');
    const [endpoint] = await ctx.db.query<Row>(
      `select * from pos_webhook_endpoints where id = $1 and organization_id = $2 and deleted_at is null`,
      [id, ctx.m.organization_id],
    );
    if (!endpoint) throw notFound('This webhook was not found.');
    const result = await deliver(ctx, endpoint, 'test.ping', { organization: ctx.m.organization_name, message: 'Test delivery from Proviyaa' });
    return c.json({ data: result });
  });

  app.get('/webhooks/deliveries', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'read');
    const status = c.req.query('status');
    const rows = await ctx.db.query<Row>(
      `select d.*, e.name as endpoint_name, e.url from pos_webhook_deliveries d
         left join pos_webhook_endpoints e on e.id = d.endpoint_id
        where d.organization_id = $1 and ($2::text is null or d.status = $2)
        order by d.created_at desc limit 200`,
      [ctx.m.organization_id, status || null],
    );
    return c.json({ data: rows });
  });

  // ── API keys ──
  const keyBody = z
    .object({
      name: z.string().trim().min(1, 'Name the key.').max(120),
      scopes: z.array(z.enum(API_SCOPES as [string, ...string[]])).min(1, 'Pick at least one scope.'),
      expires_in_days: z.union([z.literal(30), z.literal(90), z.literal(180), z.literal(365)]).nullable().default(365),
    })
    .strict();

  app.get('/api-keys', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'read');
    const rows = await ctx.db.query<Row>(`select * from pos_api_keys where organization_id = $1 order by created_at desc`, [
      ctx.m.organization_id,
    ]);
    const trail = await ctx.db.query<Row>(
      `select action, actor_name, details, created_at from pos_audit_log
        where organization_id = $1 and entity = 'API key' order by created_at desc limit 50`,
      [ctx.m.organization_id],
    );
    return c.json({ data: rows.map(keyView), scopes: API_SCOPES, audit: trail });
  });

  app.post('/api-keys', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'write');
    const body = await readJson(c, keyBody);
    const out = await createKey(ctx, body.name, body.scopes, body.expires_in_days);
    await audit(ctx, 'Generated key', 'API key', String(out.id), { name: body.name, scopes: body.scopes });
    return c.json({ data: out }, 201);
  });

  const oneKey = async (ctx: RequestContext, id: string) => {
    if (!isUuid(id)) throw notFound('This API key was not found.');
    const [row] = await ctx.db.query<Row>(`select * from pos_api_keys where id = $1 and organization_id = $2`, [id, ctx.m.organization_id]);
    if (!row) throw notFound('This API key was not found.');
    return row;
  };

  app.post('/api-keys/:id/revoke', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'write');
    const key = await oneKey(ctx, c.req.param('id'));
    if (key.revoked_at) throw conflict('This key is already revoked.');
    const [row] = await ctx.db.query<Row>(`update pos_api_keys set revoked_at = now() where id = $1 and organization_id = $2 returning *`, [
      key.id,
      ctx.m.organization_id,
    ]);
    await audit(ctx, 'Revoked key', 'API key', String(key.id), { name: key.name });
    return c.json({ data: keyView(row!) });
  });

  app.post('/api-keys/:id/rotate', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'write');
    const key = await oneKey(ctx, c.req.param('id'));
    if (key.revoked_at) throw conflict('A revoked key cannot be rotated; generate a new one.');
    const days = key.expires_at ? Math.max(1, Math.round((Date.parse(String(key.expires_at)) - Date.parse(String(key.created_at))) / 86_400_000)) : null;
    await ctx.db.query(`update pos_api_keys set revoked_at = now() where id = $1 and organization_id = $2`, [key.id, ctx.m.organization_id]);
    const out = await createKey(ctx, String(key.name), (key.scopes as string[]) ?? [], days);
    await audit(ctx, 'Rotated key', 'API key', String(out.id), { name: key.name, replaced: key.id });
    return c.json({ data: out }, 201);
  });

  // ── sync jobs ──
  app.get('/sync-jobs', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'read');
    const status = c.req.query('status');
    const rows = await ctx.db.query<Row>(
      `select * from pos_sync_jobs where organization_id = $1 and ($2::text is null or status = $2) order by created_at desc limit 200`,
      [ctx.m.organization_id, status || null],
    );
    return c.json({ data: rows.map((r) => ({ ...r, provider_name: providerByKey(String(r.provider))?.name ?? r.provider })) });
  });

  app.post('/sync-jobs', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'write');
    const body = await readJson(
      c,
      z
        .object({
          provider: z.string(),
          resource: z.enum(['menu', 'inventory', 'orders', 'payments', 'customers', 'settlements']),
          mode: z.enum(['full', 'delta', 'manual', 'pull']).default('delta'),
          direction: z.enum(['inbound', 'outbound']).default('inbound'),
        })
        .strict(),
    );
    if (!providerByKey(body.provider)) throw unprocessable('This app is not in the Proviyaa app list.');
    const [row] = await ctx.db.insert<Row>('pos_sync_jobs', [{ ...body, organization_id: ctx.m.organization_id, created_by: ctx.identity.user_id }]);
    return c.json({ data: row }, 201);
  });

  /// Runs every queued job now. There is no provider adapter yet, so a job
  /// fails with the reason instead of pretending to sync.
  app.post('/sync-jobs/run', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'write');
    const queued = await ctx.db.query<Row>(
      `select * from pos_sync_jobs where organization_id = $1 and status = 'queued' order by created_at limit 50`,
      [ctx.m.organization_id],
    );
    const apps = await integrationRows(ctx);
    let failed = 0;
    for (const job of queued) {
      const started = Date.now();
      const app = apps.find((a) => a.key === job.provider);
      const name = app?.name ?? String(job.provider);
      const error = app?.status === 'connected' ? `No sync adapter for ${name} is available yet.` : `${name} is not connected.`;
      await ctx.db.query(
        `update pos_sync_jobs set status = 'failed', attempts = attempts + 1, error = $3, duration_ms = $4, finished_at = now()
          where id = $1 and organization_id = $2`,
        [job.id, ctx.m.organization_id, error, Date.now() - started],
      );
      failed++;
    }
    return c.json({ data: { ran: queued.length, succeeded: 0, failed } });
  });

  // ── logs ──
  app.get('/logs', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'integrations', 'read');
    const page = intParam(c.req.query('page'), 1, 10_000);
    const size = 15;
    const q = (c.req.query('q') ?? '').trim();
    const base = `
      select 'sync' as kind, provider as source, resource as detail, status, error, coalesce(finished_at, created_at) as at
        from pos_sync_jobs where organization_id = $1 and status in ('success', 'failed')
      union all
      select 'webhook', coalesce(e.name, 'Webhook'), d.event, d.status, d.error, d.created_at
        from pos_webhook_deliveries d left join pos_webhook_endpoints e on e.id = d.endpoint_id
       where d.organization_id = $1`;
    const filter = `where ($2 = '' or source ilike '%' || $2 || '%' or detail ilike '%' || $2 || '%' or error ilike '%' || $2 || '%')`;
    const [{ total }] = (await ctx.db.query<{ total: number }>(`select count(*)::int as total from (${base}) t ${filter}`, [
      ctx.m.organization_id,
      q,
    ])) as [{ total: number }];
    const rows = await ctx.db.query<Row>(`select * from (${base}) t ${filter} order by at desc limit ${size} offset $3`, [
      ctx.m.organization_id,
      q,
      (page - 1) * size,
    ]);
    return c.json({
      data: rows.map((r) => ({ ...r, source: providerByKey(String(r.source))?.name ?? r.source })),
      page,
      pages: Math.max(1, Math.ceil(total / size)),
      total,
    });
  });

  return app;
}
