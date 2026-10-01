import { Hono, type MiddlewareHandler } from 'hono';
import { cors } from 'hono/cors';
import { HTTPException } from 'hono/http-exception';
import { ZodError } from 'zod';
import type { Env } from './http.js';
import { ApiError, DbError, fromDbError } from './lib/errors.js';
import { isUuid } from './lib/ids.js';
import type { Platform } from './platform.js';
import { authRoutes, requireSession, type AuthRouteOptions } from './routes/auth.js';
import { syncRoutes } from './routes/sync.js';
import { franchiseRoutes } from './services/franchise.js';
import { masterRoutes } from './services/master.js';
import { operationsRoutes } from './services/operations.js';
import { crmRoutes } from './services/crm.js';
import { financeRoutes } from './services/finance.js';
import { integrationsRoutes } from './services/integrations.js';
import { marketingRoutes } from './services/marketing.js';
import { settingsRoutes } from './services/settings.js';
import { staffRoutes } from './services/staff.js';
import { tasksRoutes } from './services/tasks.js';

export interface AppOptions {
  corsOrigins?: string[];
  auth?: AuthRouteOptions;
  log?: (line: string) => void;
}

/// The Proviyaa POS backend HTTP API.
///
///   /health
///   /v1/auth         login · refresh · me · logout
///   /v1/franchise    organization, branches, staff, records, targets,
///                    exceptions, chain analytics, stock transfers
///   /v1/master       menu, offers, media, suppliers, inventory, recipes,
///                    purchasing
///   /v1/operations   floor, orders, KOT, payments, online orders,
///                    channels, bill settings, reservations, deliveries …
///   /v1/staff        employees, logins & roles, attendance, shifts,
///                    advances, salaries, approvals, audit log, reports,
///                    training
///   /v1/crm          customers, segments, loyalty, wallet, feedback, ideas
///   /v1/marketing    campaigns, promotions (offers), ad requests
///   /v1/finance      payments, money in/out, expenses, settlements, documents
///   /v1/integrations connected apps, webhooks, API keys, sync jobs, logs
///   /v1/tasks        staff tasks with checklists, evidence and sign-off
///   /v1/settings     outlet, bill format, devices, printers, KDS, updates,
///                    notifications, subscription, system health
///   /v1/sync         device push / pull
/// Records successful changes made through a module's REST routes in the
/// panel's audit log (Staff → Audit log). Staff routes log their own,
/// more specific entries; device sync is not a panel action.
function auditWrites(module: string): MiddlewareHandler<Env> {
  const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
  return async (c, next) => {
    await next();
    const method = c.req.method;
    if (method === 'GET' || method === 'HEAD' || method === 'OPTIONS' || c.res.status >= 400) return;
    const ctx = c.get('ctx');
    if (!ctx) return;
    const segs = new URL(c.req.url).pathname.split('/').filter(Boolean).slice(2);
    const words = segs.filter((s): boolean => !isUuid(s)).map((s) => s.replace(/-/g, ' '));
    const entity = `${cap(module)} · ${words[0] ?? module}`;
    const action =
      method === 'DELETE' ? 'Deleted' : method === 'POST' ? (words.length > 1 ? cap(words.slice(1).join(' ')) : 'Created') : 'Updated';
    try {
      await ctx.db.query(
        `insert into pos_audit_log (organization_id, actor_id, actor_name, action, entity, entity_id) values ($1, $2, $3, $4, $5, $6)`,
        [ctx.m.organization_id, ctx.identity.user_id, ctx.identity.full_name || ctx.identity.email, action, entity, segs.find((s): boolean => isUuid(s)) ?? null],
      );
    } catch {
      // The audit trail must never fail the change it records.
    }
  };
}

export function createApp(platform: Platform, opts: AppOptions = {}): Hono<Env> {
  const app = new Hono<Env>();
  const log = opts.log ?? (() => undefined);

  app.use(
    '*',
    cors({
      origin: (origin) => (opts.corsOrigins?.includes(origin) ? origin : null),
      allowHeaders: ['Authorization', 'Content-Type', 'X-Location-Id', 'X-Organization-Id', 'If-Match'],
      allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      maxAge: 600,
    }),
  );

  app.use('*', async (c, next) => {
    const started = Date.now();
    await next();
    log(`${c.req.method} ${new URL(c.req.url).pathname} ${c.res.status} ${Date.now() - started}ms`);
  });

  app.get('/health', (c) => c.json({ ok: true, service: 'proviyaa-pos-backend' }));

  app.route('/v1/auth', authRoutes(platform, opts.auth));
  const protect = (routes: Hono<Env>, audited?: string) => {
    const sub = new Hono<Env>();
    sub.use('*', requireSession(platform));
    if (audited) sub.use('*', auditWrites(audited));
    sub.route('/', routes);
    return sub;
  };
  app.route('/v1/franchise', protect(franchiseRoutes(), 'franchise'));
  app.route('/v1/master', protect(masterRoutes(), 'master'));
  app.route('/v1/operations', protect(operationsRoutes(), 'operations'));
  app.route('/v1/staff', protect(staffRoutes()));
  app.route('/v1/crm', protect(crmRoutes()));
  app.route('/v1/marketing', protect(marketingRoutes()));
  app.route('/v1/finance', protect(financeRoutes()));
  app.route('/v1/integrations', protect(integrationsRoutes()));
  app.route('/v1/tasks', protect(tasksRoutes()));
  app.route('/v1/settings', protect(settingsRoutes()));
  app.route('/v1/sync', protect(syncRoutes()));

  app.notFound((c) => c.json({ error: { code: 'not_found', message: `No route ${c.req.method} ${new URL(c.req.url).pathname}` } }, 404));

  app.onError((err, c) => {
    let e: ApiError;
    if (err instanceof ApiError) e = err;
    else if (err instanceof DbError) e = fromDbError(err);
    else if (err instanceof ZodError) {
      e = new ApiError(400, 'validation_failed', 'Some fields are missing or invalid.', err.issues);
    } else if (err instanceof HTTPException) e = new ApiError(err.status, 'http_error', err.message);
    else {
      log(`ERROR ${c.req.method} ${new URL(c.req.url).pathname}: ${err instanceof Error ? (err.stack ?? err.message) : String(err)}`);
      e = new ApiError(500, 'internal', 'Something went wrong on the server.');
    }
    if (e.status >= 500 && !(err instanceof ApiError && e.code === 'internal')) {
      log(`ERROR ${c.req.method} ${new URL(c.req.url).pathname}: ${e.code} ${e.message} ${JSON.stringify(e.details ?? '')}`);
    }
    return c.json({ error: { code: e.code, message: e.message, details: e.details } }, e.status as 400);
  });

  return app;
}
