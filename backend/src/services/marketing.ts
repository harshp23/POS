import { Hono } from 'hono';
import { z } from 'zod';
import { requireCan, type RequestContext } from '../context.js';
import type { Row } from '../db/types.js';
import { ctxOf, readJson, type Env } from '../http.js';
import { conflict, notFound, unprocessable } from '../lib/errors.js';
import { isUuid } from '../lib/ids.js';
import { mirroredResources } from '../schema/resources.js';
import { segmentMembers, segmentNames } from './crm.js';
import { audit, money, num, sectionGuard } from './section.js';
import { MirroredAdapter } from './sync/mirrored.js';

/// Marketing (/v1/marketing): customer campaigns, promotions (the offers of
/// Master → Offers, plus their marketing rules) and ad requests for the
/// Proviyaa customer app.
///
/// No messaging provider is connected yet, so a campaign that is "sent" is
/// queued with its audience counted and a note saying nothing was
/// delivered; ad requests wait for the Proviyaa team's review.

export const CHANNEL_PROVIDER: Record<string, { key: string; name: string; optIn: string }> = {
  whatsapp: { key: 'whatsapp_business', name: 'WhatsApp Business', optIn: 'allow_whatsapp' },
  sms: { key: 'sms_gateway', name: 'SMS Gateway', optIn: 'allow_sms' },
  email: { key: 'email_smtp', name: 'Email SMTP', optIn: 'allow_email' },
  push: { key: 'push_notifications', name: 'Push Notifications', optIn: 'allow_push' },
};

async function audience(ctx: RequestContext, segment: string, channel: string) {
  const members = await segmentMembers(ctx, segment);
  const optIn = CHANNEL_PROVIDER[channel]?.optIn;
  return { total: members.length, reachable: optIn ? members.filter((m) => m[optIn] === true).length : members.length };
}

async function providerStatus(ctx: RequestContext, channel: string): Promise<{ name: string; connected: boolean }> {
  const p = CHANNEL_PROVIDER[channel]!;
  const [row] = await ctx.db.query<Row>(`select status from pos_integrations where organization_id = $1 and provider = $2`, [
    ctx.m.organization_id,
    p.key,
  ]);
  return { name: p.name, connected: row?.status === 'connected' };
}

// ── promotions (pos_offers + pos_offer_rules) ──────────────────────────────

const offers = new MirroredAdapter(mirroredResources.find((r) => r.resource === 'offers')!);

export type OfferState = 'active' | 'scheduled' | 'ended';

export function offerState(o: Row, now = Date.now()): OfferState {
  const status = String(o.status ?? '');
  const end = o.end_date ? Date.parse(String(o.end_date)) : null;
  const start = o.start_date ? Date.parse(String(o.start_date)) : null;
  if ((end !== null && end < now) || status === 'Inactive' || status === 'Cancelled') return 'ended';
  if ((start !== null && start > now) || ['Draft', 'Approved', 'Scheduled', 'Paused'].includes(status)) return 'scheduled';
  return 'active';
}

const CHANNEL_LABELS: Record<string, string> = { pos: 'POS Dine-In', qr: 'QR Ordering', app: 'App' };

const promotionBody = z
  .object({
    title: z.string().trim().min(1, 'Offer name is required.').max(120),
    offer_type: z.enum(['promo_code', 'auto_apply', 'combo', 'free_delivery']),
    code: z.string().trim().max(40).default(''),
    target_segment: z.string().trim().max(80).default('all'),
    discount_type: z.enum(['percent', 'flat']),
    discount_value: z.number().min(0),
    max_discount: z.number().min(0).default(0),
    min_order: z.number().min(0).default(0),
    per_customer_limit: z.number().int().min(0).default(1),
    start_date: z.string().datetime({ offset: true }).nullable().default(null),
    end_date: z.string().datetime({ offset: true }).nullable().default(null),
    channels: z.array(z.enum(['pos', 'qr', 'app'])).min(1, 'Pick at least one channel.'),
    auto_apply: z.boolean().default(false),
    active: z.boolean().default(true),
    linked_items: z.string().trim().max(500).default(''),
  })
  .strict();
type PromotionBody = z.infer<typeof promotionBody>;

function deviceOffer(id: string, b: PromotionBody, usage: number): Row {
  if (b.discount_type === 'percent' && b.discount_value > 100) throw unprocessable('A percentage discount cannot be over 100%.');
  if (b.offer_type === 'promo_code' && !b.code) throw unprocessable('A promo code offer needs a coupon code.');
  if (b.start_date && b.end_date && Date.parse(b.end_date) <= Date.parse(b.start_date)) {
    throw unprocessable('"Valid until" must be after "Valid from".');
  }
  const rule =
    b.discount_type === 'percent'
      ? `${b.discount_value}% OFF${b.max_discount ? ` (Upto ₹${b.max_discount})` : ''}`
      : `₹${b.discount_value} OFF`;
  const campaignType =
    b.offer_type === 'combo' ? 'Combo Deal' : b.discount_type === 'percent' ? 'Percentage Off' : 'Flat Discount';
  const starts = b.start_date ? Date.parse(b.start_date) : null;
  return {
    id,
    title: b.title,
    code: (b.code || b.title.replace(/[^A-Za-z0-9]/g, '').slice(0, 12)).toUpperCase(),
    campaign_type: campaignType,
    discount_rule: rule,
    min_order: b.min_order,
    max_discount: b.max_discount,
    start_date: b.start_date,
    end_date: b.end_date,
    channels: b.channels.map((c) => CHANNEL_LABELS[c]).join(', '),
    linked_items: b.linked_items,
    status: !b.active ? 'Paused' : starts !== null && starts > Date.now() ? 'Scheduled' : 'Active',
    usage_count: usage,
    updated_at: new Date().toISOString(),
  };
}

async function promotionRows(ctx: RequestContext): Promise<Row[]> {
  const rows = await ctx.db.query<Row>(
    `select o.row_id, o.id, o.title, o.code, o.campaign_type, o.discount_rule, o.min_order, o.max_discount, o.start_date,
            o.end_date, o.channels, o.linked_items, o.status, o.usage_count, o.server_updated_at,
            r.offer_type, r.discount_type, r.discount_value, r.target_segment, r.per_customer_limit, r.auto_apply
       from pos_offers o
       left join pos_offer_rules r on r.organization_id = o.organization_id and r.offer_id = o.id
      where o.organization_id = $1 and o.deleted_at is null
      order by o.server_updated_at desc`,
    [ctx.m.organization_id],
  );
  const now = Date.now();
  return rows.map((o) => ({
    ...o,
    min_order: num(o.min_order),
    max_discount: num(o.max_discount),
    usage_count: num(o.usage_count),
    discount_value: o.discount_value === null || o.discount_value === undefined ? null : num(o.discount_value),
    state: offerState(o, now),
  }));
}

async function saveRules(ctx: RequestContext, offerId: string, b: PromotionBody) {
  await ctx.db.query(
    `insert into pos_offer_rules (organization_id, offer_id, offer_type, discount_type, discount_value, target_segment,
                                  per_customer_limit, auto_apply)
     values ($1, $2, $3, $4, $5, $6, $7, $8)
     on conflict (organization_id, offer_id) do update set offer_type = excluded.offer_type, discount_type = excluded.discount_type,
       discount_value = excluded.discount_value, target_segment = excluded.target_segment,
       per_customer_limit = excluded.per_customer_limit, auto_apply = excluded.auto_apply`,
    [ctx.m.organization_id, offerId, b.offer_type, b.discount_type, b.discount_value, b.target_segment, b.per_customer_limit, b.auto_apply],
  );
}

// ── campaigns ──────────────────────────────────────────────────────────────

const campaignBody = z
  .object({
    name: z.string().trim().min(1, 'Campaign name is required.').max(120),
    channel: z.enum(['whatsapp', 'sms', 'email', 'push']),
    segment: z.string().trim().max(80).default('all'),
    offer_code: z.string().trim().max(40).nullable().default(null),
    schedule_at: z.string().datetime({ offset: true }).nullable().default(null),
    recurrence: z.enum(['once', 'daily', 'weekly', 'monthly']).default('once'),
    title: z.string().trim().max(200).default(''),
    message: z.string().trim().min(1, 'Write the message.').max(2000),
  })
  .strict();

async function oneCampaign(ctx: RequestContext, id: string): Promise<Row> {
  if (!isUuid(id)) throw notFound('This campaign was not found.');
  const [row] = await ctx.db.query<Row>(
    `select * from pos_campaigns where id = $1 and organization_id = $2 and deleted_at is null`,
    [id, ctx.m.organization_id],
  );
  if (!row) throw notFound('This campaign was not found.');
  return row;
}

/// Queues a campaign: counts its audience (customers in the segment who
/// opted in to the channel) and records why nothing went out yet.
async function queueCampaign(ctx: RequestContext, row: Row): Promise<Row> {
  const channel = String(row.channel);
  const aud = await audience(ctx, String(row.segment), channel);
  const provider = await providerStatus(ctx, channel);
  const note = provider.connected
    ? `Queued for ${provider.name}.`
    : `Not sent: ${provider.name} is not connected. Connect it in Integrations → Connected apps; nothing was delivered.`;
  const [updated] = await ctx.db.query<Row>(
    `update pos_campaigns set status = 'queued', audience_count = $3, status_note = $4
      where id = $1 and organization_id = $2 returning *`,
    [row.id, ctx.m.organization_id, aud.reachable, note],
  );
  return updated!;
}

const adBody = z
  .object({
    title: z.string().trim().min(1, 'Ad title is required.').max(120),
    description: z.string().trim().max(1000).default(''),
    discount_text: z.string().trim().max(60).default(''),
    placement: z.enum(['home_carousel', 'offer_strip', 'restaurant_section']).default('home_carousel'),
    banner_url: z.union([z.string().trim().url().max(500), z.literal('')]).nullable().default(null),
  })
  .strict();

export function marketingRoutes(): Hono<Env> {
  const app = new Hono<Env>();
  app.use('*', sectionGuard('marketing'));

  app.get('/dashboard', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'read');
    const org = ctx.m.organization_id;
    const [camp] = await ctx.db.query<Row>(
      `select coalesce(sum(revenue), 0) as revenue, coalesce(sum(sent_count), 0)::int as sent,
              coalesce(sum(delivered_count), 0)::int as delivered, coalesce(sum(clicks), 0)::int as clicks,
              count(*)::int as total, count(*) filter (where status = 'queued')::int as queued
         from pos_campaigns where organization_id = $1 and deleted_at is null`,
      [org],
    );
    const [ads] = await ctx.db.query<Row>(
      `select coalesce(sum(spend), 0) as spend, count(*) filter (where status = 'live')::int as live,
              coalesce(sum(clicks), 0)::int as clicks, coalesce(sum(impressions), 0)::int as impressions,
              coalesce(sum(orders), 0)::int as orders
         from pos_ad_requests where organization_id = $1 and deleted_at is null`,
      [org],
    );
    const promos = await promotionRows(ctx);
    const soon = Date.now() + 7 * 86_400_000;
    const active = promos.filter((p) => p.state === 'active');
    const redemptions = promos.reduce((s, p) => s + num(p.usage_count), 0);
    const revenue = money(camp?.revenue);
    const spend = money(ads?.spend);
    const sent = num(camp?.sent);
    const channels = await ctx.db.query<Row>(
      `select channel, count(*)::int as campaigns, coalesce(sum(audience_count), 0)::int as audience
         from pos_campaigns where organization_id = $1 and deleted_at is null group by channel order by 2 desc`,
      [org],
    );
    const activity = await ctx.db.query<Row>(
      `select to_char(created_at, 'YYYY-MM-DD') as day, count(*)::int as campaigns, coalesce(sum(audience_count), 0)::int as audience
         from pos_campaigns where organization_id = $1 and deleted_at is null and created_at >= now() - interval '30 days'
        group by 1 order by 1`,
      [org],
    );
    const top = await ctx.db.query<Row>(
      `select id, name, channel, status, audience_count, revenue from pos_campaigns
        where organization_id = $1 and deleted_at is null order by revenue desc, created_at desc limit 5`,
      [org],
    );
    return c.json({
      data: {
        attributed_revenue: revenue,
        marketing_spend: spend,
        roas: spend > 0 ? Math.round((revenue / spend) * 100) / 100 : null,
        reach: sent,
        delivered: num(camp?.delivered),
        click_through_rate: sent ? Math.round((num(camp?.clicks) / sent) * 1000) / 10 : 0,
        clicks: num(camp?.clicks),
        conversion_rate: sent ? Math.round((redemptions / sent) * 1000) / 10 : 0,
        redemptions,
        cost_per_conversion: redemptions && spend ? money(spend / redemptions) : null,
        live_coupons: active.length,
        expiring_7d: active.filter((p) => p.end_date && Date.parse(String(p.end_date)) <= soon).length,
        auto_apply: active.filter((p) => p.auto_apply === true).length,
        automation_flows: 0,
        ads_live: num(ads?.live),
        ad_clicks: num(ads?.clicks),
        ad_impressions: num(ads?.impressions),
        ad_orders: num(ads?.orders),
        campaigns: num(camp?.total),
        queued_campaigns: num(camp?.queued),
        channel_mix: channels,
        activity_30d: activity,
        top_campaigns: top.map((t) => ({ ...t, revenue: money(t.revenue) })),
        coupon_performance: [...promos]
          .sort((a, b) => num(b.usage_count) - num(a.usage_count))
          .slice(0, 5)
          .map((p) => ({ id: p.id, title: p.title, code: p.code, usage_count: num(p.usage_count), state: p.state })),
      },
    });
  });

  // ── campaigns ──
  app.get('/campaigns', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'read');
    const channel = c.req.query('channel');
    const q = (c.req.query('q') ?? '').trim();
    const rows = await ctx.db.query<Row>(
      `select * from pos_campaigns
        where organization_id = $1 and deleted_at is null
          and ($2::text is null or channel = $2) and ($3::text = '' or name ilike '%' || $3 || '%')
        order by created_at desc limit 200`,
      [ctx.m.organization_id, channel || null, q],
    );
    const names = await segmentNames(ctx);
    return c.json({ data: rows.map((r) => ({ ...r, revenue: money(r.revenue), segment_name: names.get(String(r.segment ?? 'all')) ?? 'Deleted segment' })) });
  });

  app.get('/audience', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'read');
    const channel = c.req.query('channel') ?? 'whatsapp';
    if (!CHANNEL_PROVIDER[channel]) throw unprocessable('This channel is not supported.');
    return c.json({ data: await audience(ctx, c.req.query('segment') ?? 'all', channel) });
  });

  app.post('/campaigns', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'write');
    const body = await readJson(c, campaignBody.extend({ action: z.enum(['draft', 'schedule', 'send']).default('draft') }).strict());
    const { action, ...fields } = body;
    if (action === 'schedule' && (!fields.schedule_at || Date.parse(fields.schedule_at) <= Date.now())) {
      throw unprocessable('Pick a time in the future to schedule the campaign.');
    }
    await segmentMembers(ctx, fields.segment); // the segment must exist
    const [row] = await ctx.db.insert<Row>('pos_campaigns', [
      {
        ...fields,
        organization_id: ctx.m.organization_id,
        status: action === 'schedule' ? 'scheduled' : 'draft',
        audience_count: (await audience(ctx, fields.segment, fields.channel)).reachable,
        created_by: ctx.identity.user_id,
      },
    ]);
    const out = action === 'send' ? await queueCampaign(ctx, row!) : row!;
    await audit(ctx, action === 'send' ? 'Sent campaign' : action === 'schedule' ? 'Scheduled campaign' : 'Saved campaign draft', 'Campaign', String(out.id), {
      channel: fields.channel,
    });
    return c.json({ data: out }, 201);
  });

  app.patch('/campaigns/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'write');
    const cur = await oneCampaign(ctx, c.req.param('id'));
    if (!['draft', 'scheduled'].includes(String(cur.status))) throw conflict(`This campaign is ${cur.status}; it can no longer be edited.`);
    const body = await readJson(c, campaignBody.partial().strict());
    const next = { ...cur, ...body };
    if (body.segment) await segmentMembers(ctx, body.segment);
    const [row] = await ctx.db.query<Row>(
      `update pos_campaigns set name = $3, channel = $4, segment = $5, offer_code = $6, schedule_at = $7, recurrence = $8,
              title = $9, message = $10, audience_count = $11
        where id = $1 and organization_id = $2 returning *`,
      [
        cur.id,
        ctx.m.organization_id,
        next.name,
        next.channel,
        next.segment,
        next.offer_code ?? null,
        next.schedule_at ?? null,
        next.recurrence,
        next.title,
        next.message,
        (await audience(ctx, String(next.segment), String(next.channel))).reachable,
      ],
    );
    return c.json({ data: row });
  });

  app.post('/campaigns/:id/send', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'write');
    const cur = await oneCampaign(ctx, c.req.param('id'));
    if (!['draft', 'scheduled'].includes(String(cur.status))) throw conflict(`This campaign is already ${cur.status}.`);
    const out = await queueCampaign(ctx, cur);
    await audit(ctx, 'Sent campaign', 'Campaign', String(cur.id), { channel: cur.channel });
    return c.json({ data: out });
  });

  app.post('/campaigns/:id/cancel', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'write');
    const cur = await oneCampaign(ctx, c.req.param('id'));
    if (cur.status === 'sent' || cur.status === 'cancelled') throw conflict(`This campaign is already ${cur.status}.`);
    const [row] = await ctx.db.query<Row>(
      `update pos_campaigns set status = 'cancelled', status_note = 'Cancelled' where id = $1 and organization_id = $2 returning *`,
      [cur.id, ctx.m.organization_id],
    );
    return c.json({ data: row });
  });

  app.delete('/campaigns/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'delete');
    const cur = await oneCampaign(ctx, c.req.param('id'));
    await ctx.db.query(`update pos_campaigns set deleted_at = now() where id = $1 and organization_id = $2`, [cur.id, ctx.m.organization_id]);
    return c.body(null, 204);
  });

  // ── promotions ──
  app.get('/promotions', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'read');
    const state = c.req.query('state');
    const names = await segmentNames(ctx);
    const rows = (await promotionRows(ctx)).map((r): Row => ({
      ...r,
      target_segment_name: names.get(String(r.target_segment ?? 'all')) ?? 'Deleted segment',
    }));
    return c.json({ data: state ? rows.filter((r) => r.state === state) : rows });
  });

  app.post('/promotions', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'write');
    requireCan(ctx, 'master', 'write');
    const body = await readJson(c, promotionBody);
    if (body.target_segment !== 'all') await segmentMembers(ctx, body.target_segment);
    const code = body.code.toUpperCase();
    if (code) {
      const [dup] = await ctx.db.query<Row>(
        `select title from pos_offers where organization_id = $1 and deleted_at is null and upper(code) = $2`,
        [ctx.m.organization_id, code],
      );
      if (dup) throw conflict(`The code ${code} is already used by "${dup.title}".`);
    }
    const id = `OFF-${Date.now().toString(36).toUpperCase()}`;
    await offers.upsert(ctx, null, deviceOffer(id, { ...body, code }, 0));
    await saveRules(ctx, id, body);
    await audit(ctx, 'Created offer', 'Offer', id, { code });
    return c.json({ data: (await promotionRows(ctx)).find((r) => r.id === id) }, 201);
  });

  app.patch('/promotions/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'write');
    requireCan(ctx, 'master', 'write');
    const id = c.req.param('id');
    const cur = (await promotionRows(ctx)).find((r) => r.id === id);
    if (!cur) throw notFound('This offer was not found.');
    const body = await readJson(c, promotionBody);
    await offers.upsert(ctx, null, deviceOffer(id, { ...body, code: body.code.toUpperCase() }, num(cur.usage_count)));
    await saveRules(ctx, id, body);
    return c.json({ data: (await promotionRows(ctx)).find((r) => r.id === id) });
  });

  app.delete('/promotions/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'delete');
    requireCan(ctx, 'master', 'delete');
    const id = c.req.param('id');
    const removed = await offers.remove(ctx, null, { id });
    if (!removed) throw notFound('This offer was not found.');
    await ctx.db.query(`delete from pos_offer_rules where organization_id = $1 and offer_id = $2`, [ctx.m.organization_id, id]);
    return c.body(null, 204);
  });

  // ── ads ──
  app.get('/ads', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'read');
    const rows = await ctx.db.query<Row>(
      `select * from pos_ad_requests where organization_id = $1 and deleted_at is null order by created_at desc`,
      [ctx.m.organization_id],
    );
    return c.json({ data: rows.map((r) => ({ ...r, spend: money(r.spend) })) });
  });

  app.post('/ads', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'write');
    const body = await readJson(c, adBody);
    const [row] = await ctx.db.insert<Row>('pos_ad_requests', [
      { ...body, banner_url: body.banner_url || null, organization_id: ctx.m.organization_id, created_by: ctx.identity.user_id },
    ]);
    await audit(ctx, 'Requested ad', 'Ad request', String(row!.id), { placement: body.placement });
    return c.json({ data: row }, 201);
  });

  app.delete('/ads/:id', async (c) => {
    const ctx = ctxOf(c);
    requireCan(ctx, 'marketing', 'delete');
    const id = c.req.param('id');
    if (!isUuid(id)) throw notFound('This ad request was not found.');
    const rows = await ctx.db.query<Row>(
      `update pos_ad_requests set deleted_at = now()
        where id = $1 and organization_id = $2 and deleted_at is null and status = 'pending' returning id`,
      [id, ctx.m.organization_id],
    );
    if (!rows.length) throw conflict('Only a pending ad request can be withdrawn.');
    return c.body(null, 204);
  });

  return app;
}
