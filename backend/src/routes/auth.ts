import { Hono, type Context, type MiddlewareHandler } from 'hono';
import { z } from 'zod';
import type { AuthUser } from '../auth/types.js';
import {
  forgetMembership,
  loadIdentity,
  loadMembership,
  optionalTable,
  pickLocation,
  type Identity,
  type Location,
  type Membership,
} from '../context.js';
import { ctxOf, readJson, type Env } from '../http.js';
import { ApiError, unauthorized } from '../lib/errors.js';
import { RateLimiter } from '../lib/rate-limit.js';
import { capabilities, panelFor } from '../permissions.js';
import type { Platform } from '../platform.js';

export function meView(
  id: Identity,
  m: Membership | null,
  location: Location | null,
  organizations?: unknown[],
  mustChangePassword = false,
) {
  return {
    user: { id: id.user_id, email: id.email },
    platform_admin: id.platform_admin,
    organization: m ? { id: m.organization_id, name: m.organization_name, status: m.organization_status } : null,
    member: {
      full_name: id.full_name,
      email: id.email,
      role: m?.role ?? null,
      role_name: m?.staff_role?.name ?? m?.role_name ?? null,
      staff_role: m?.staff_role ?? null,
    },
    panel: m ? panelFor(m.role) : 'vendor',
    capabilities: m ? capabilities(m.role) : {},
    /// Screens this account opens; the app shows nothing else.
    screens: m?.screens ?? [],
    must_change_password: mustChangePassword,
    locations: m?.locations ?? [],
    location,
    ...(organizations ? { organizations } : {}),
  };
}

async function mustChangePassword(platform: Platform, userId: string): Promise<boolean> {
  const [row] = await optionalTable(
    () =>
      platform.db.query<{ force_password_change: boolean }>(
        `select force_password_change from pos_login_security where user_id = $1`,
        [userId],
      ),
    [],
  );
  return row?.force_password_change === true;
}

/// Last activity per account, written at most once a minute ("Online now").
const lastSeenWrites = new Map<string, number>();
async function touchLastSeen(platform: Platform, identity: Identity) {
  const now = Date.now();
  if ((lastSeenWrites.get(identity.user_id) ?? 0) > now - 60_000) return;
  lastSeenWrites.set(identity.user_id, now);
  await optionalTable(
    () =>
      platform.db.query(
        `insert into pos_login_security (user_id, organization_id, last_seen_at) values ($1, $2, now())
         on conflict (user_id) do update set last_seen_at = now()`,
        [identity.user_id, identity.organization_id],
      ),
    [],
  );
}

const bearer = (c: Context) => /^Bearer\s+(.+)$/i.exec(c.req.header('authorization') ?? '')?.[1];

async function organizationsFor(platform: Platform, id: Identity) {
  if (!id.platform_admin) return undefined;
  return platform.db.query(
    `select id, business_name as name, status, domain from organizations order by business_name`,
  );
}

/// Identity + the organization the request acts for, or null for a platform
/// admin who hasn't picked one yet.
async function resolve(platform: Platform, user: AuthUser, org: string | undefined) {
  const identity = await loadIdentity(platform.db, user);
  let m: Membership | null = null;
  try {
    m = await loadMembership(platform.db, identity, org);
  } catch (e) {
    if (!(e instanceof ApiError && e.code === 'organization_required')) throw e;
  }
  return { identity, m };
}

/// Verifies the bearer token (master-admin JWT), resolves the account and
/// its organization / role / branch, and binds the database handle.
export function requireSession(platform: Platform): MiddlewareHandler<Env> {
  return async (c, next) => {
    const token = bearer(c);
    if (!token) throw unauthorized();
    const user = await platform.auth.verify(token);
    const identity = await loadIdentity(platform.db, user);
    const m = await loadMembership(platform.db, identity, c.req.header('x-organization-id'));
    const location = pickLocation(m, c.req.header('x-location-id'));
    await touchLastSeen(platform, identity);
    c.set('ctx', { user, accessToken: token, db: platform.db, identity, m, location, locationKey: location?.id ?? 'org' });
    await next();
  };
}

export interface AuthRouteOptions {
  /// Sign-in attempts allowed per client address / per email in 5 minutes.
  loginLimitPerIp?: number;
  loginLimitPerEmail?: number;
}

export function authRoutes(platform: Platform, opts: AuthRouteOptions = {}): Hono<Env> {
  const app = new Hono<Env>();
  const perIp = new RateLimiter(opts.loginLimitPerIp ?? 100, 5 * 60_000);
  const perEmail = new RateLimiter(opts.loginLimitPerEmail ?? 20, 5 * 60_000);
  // Wrong "current password" guesses on change-password, per account.
  const perAccountChange = new RateLimiter(5, 15 * 60_000);
  const clientIp = (c: Context) => c.req.header('x-forwarded-for')?.split(',')[0]?.trim() ?? c.req.header('x-real-ip') ?? 'direct';

  app.post('/login', async (c) => {
    const { email, password } = await readJson(c, z.object({ email: z.string().trim().email(), password: z.string().min(1).max(200) }));
    const wait = Math.max(perIp.hit(clientIp(c)), perEmail.hit(email.toLowerCase()));
    if (wait > 0) {
      c.header('Retry-After', String(wait));
      throw new ApiError(429, 'rate_limited', `Too many sign-in attempts. Try again in ${Math.ceil(wait / 60)} minute(s).`);
    }
    const session = await platform.auth.signIn(email, password, {
      ip: c.req.header('x-forwarded-for')?.split(',')[0]?.trim() ?? c.req.header('x-real-ip') ?? null,
      userAgent: c.req.header('user-agent') ?? null,
    });
    // A fresh sign-in always sees the branches and roles master changed.
    forgetMembership();
    const { identity, m } = await resolve(platform, session.user, c.req.header('x-organization-id'));
    return c.json({
      data: {
        session,
        me: meView(
          identity,
          m,
          m ? pickLocation(m, null) : null,
          await organizationsFor(platform, identity),
          await mustChangePassword(platform, identity.user_id),
        ),
      },
    });
  });

  app.post('/refresh', async (c) => {
    const { refresh_token } = await readJson(c, z.object({ refresh_token: z.string().min(10) }));
    return c.json({ data: { session: await platform.auth.refresh(refresh_token) } });
  });

  app.get('/me', async (c) => {
    const token = bearer(c);
    if (!token) throw unauthorized();
    const user = await platform.auth.verify(token);
    const { identity, m } = await resolve(platform, user, c.req.header('x-organization-id'));
    const location = m ? pickLocation(m, c.req.header('x-location-id')) : null;
    return c.json({
      data: meView(identity, m, location, await organizationsFor(platform, identity), await mustChangePassword(platform, identity.user_id)),
    });
  });

  app.post('/change-password', async (c) => {
    const token = bearer(c);
    if (!token) throw unauthorized();
    const user = await platform.auth.verify(token);
    const body = await readJson(
      c,
      z.object({ current_password: z.string().min(1).max(200), new_password: z.string().min(8, 'Use at least 8 characters.').max(128) }),
    );
    const wait = perAccountChange.hit(user.id);
    if (wait > 0) {
      c.header('Retry-After', String(wait));
      throw new ApiError(429, 'rate_limited', 'Too many attempts. Try again later.');
    }
    const session = await platform.auth.changePassword(user.id, body.current_password, body.new_password);
    return c.json({ data: { session } });
  });

  const authed = new Hono<Env>();
  authed.use('*', requireSession(platform));
  // Signs this token out: the POS backend refuses it from now on. (Its
  // master-admin twin is a stateless JWT and simply expires.)
  authed.post('/logout', async (c) => {
    await platform.auth.revoke(ctxOf(c).accessToken);
    return c.body(null, 204);
  });
  app.route('/', authed);
  return app;
}
