import { createHash } from 'node:crypto';
import bcrypt from 'bcryptjs';
import { decodeJwt, jwtVerify, SignJWT } from 'jose';
import { optionalTable } from '../context.js';
import type { Db } from '../db/types.js';
import { ApiError, unauthorized } from '../lib/errors.js';
import type { AuthProvider, AuthSession, AuthUser, SignInMeta } from './types.js';

/// Consecutive wrong passwords before a login is locked, and for how long.
export const MAX_FAILED_SIGN_INS = 5;
export const LOCK_MINUTES = 15;
/// A sign-in can be refreshed for at most this long; then the user signs in
/// again with their password.
export const MAX_SESSION_DAYS = 30;
// Compared against for unknown emails, so they take as long as real ones.
const DUMMY_HASH = bcrypt.hashSync('not-a-real-password-' + Math.random(), 10);

export const tokenHash = (token: string) => createHash('sha256').update(token).digest('hex');

/// Ends every session of [userId] issued before [at] (password change,
/// admin reset). [at] is this server's clock — the same clock that stamps
/// tokens (iat_ms) — so database clock skew cannot matter.
export async function endSessions(db: Db, userId: string, orgId: string | null, at = new Date()): Promise<void> {
  await optionalTable(
    () =>
      db.query(
        `insert into pos_login_security (user_id, organization_id, sessions_valid_after)
         values ($1, $2, $3)
         on conflict (user_id) do update set sessions_valid_after = excluded.sessions_valid_after, updated_at = now()`,
        [userId, orgId, at.toISOString()],
      ),
    [],
  );
}

/// bcrypt with 10 rounds — master-admin's AuthService.register uses the same.
export const hashPassword = (password: string): Promise<string> => bcrypt.hash(password, 10);

/// Sign-in against master-admin's `users` table: the same bcrypt check and
/// the same JWT ({ userId, email }, HS256, JWT_SECRET, JWT_EXPIRES_IN) as
/// master-admin's AuthService, so one account and one token work for both
/// the Proviyaa master panel and the restaurant POS.
export class MasterAdminAuth implements AuthProvider {
  private readonly key: Uint8Array;

  constructor(
    private readonly db: Db,
    secret: string,
    private readonly expiresIn = '7d',
  ) {
    this.key = new TextEncoder().encode(secret);
  }

  private async issue(user: AuthUser, authTime?: number): Promise<AuthSession> {
    // iat_ms: when the token was issued, to the millisecond (JWT iat has
    // whole seconds), so sign-outs at a password change are exact.
    const token = await new SignJWT({ userId: user.id, email: user.email, iat_ms: Date.now(), auth_time: authTime ?? Math.floor(Date.now() / 1000) })
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
      .setIssuedAt()
      .setExpirationTime(this.expiresIn)
      .sign(this.key);
    return { access_token: token, refresh_token: token, expires_at: Number(decodeJwt(token).exp), user };
  }

  async signIn(email: string, password: string, meta: SignInMeta = {}): Promise<AuthSession> {
    const [user] = await this.db.query<{
      id: string;
      email: string;
      password: string;
      status: string | null;
      organization_id: string | null;
    }>(`select id, email, password, status, organization_id from users where lower(email) = lower($1) limit 1`, [email.trim()]);
    // Same answer for "no such user" and "wrong password".
    const invalid = new ApiError(401, 'invalid_credentials', 'Invalid email or password.');
    if (!user) {
      await bcrypt.compare(password, DUMMY_HASH);
      throw invalid;
    }

    const [sec] = await optionalTable(
      () =>
        this.db.query<{ failed_attempts: number; locked_until: string | null }>(
          `select failed_attempts, locked_until from pos_login_security where user_id = $1`,
          [user.id],
        ),
      [],
    );
    const now = new Date();
    const passwordOk = await bcrypt.compare(password, user.password ?? '');
    const locked = sec?.locked_until && new Date(sec.locked_until) > now;
    if (locked) {
      await this.event(user, false, 'locked', meta);
      // Only someone who knows the password learns that the login is locked.
      if (!passwordOk) throw invalid;
      throw new ApiError(
        423,
        'account_locked',
        `Too many wrong passwords. Try again after ${new Date(sec!.locked_until!).toISOString().slice(11, 16)} UTC, or ask your admin to reset the password.`,
      );
    }
    if (!passwordOk) {
      const failed = (sec?.failed_attempts ?? 0) + 1;
      const lockedUntil = failed >= MAX_FAILED_SIGN_INS ? new Date(now.getTime() + LOCK_MINUTES * 60_000).toISOString() : null;
      await this.security(user, { failed_attempts: failed, locked_until: lockedUntil });
      await this.event(user, false, 'wrong_password', meta);
      throw invalid;
    }
    if (user.status && user.status.toLowerCase() !== 'active') {
      await this.event(user, false, 'inactive', meta);
      throw new ApiError(403, 'account_inactive', 'This account has been deactivated or suspended.');
    }
    await this.security(user, { failed_attempts: 0, locked_until: null, last_login_at: now.toISOString(), last_seen_at: now.toISOString() });
    await this.event(user, true, null, meta);
    return this.issue({ id: user.id, email: user.email });
  }

  async changePassword(userId: string, current: string, next: string): Promise<AuthSession> {
    const [user] = await this.db.query<{ id: string; email: string; password: string; organization_id: string | null }>(
      `select id, email, password, organization_id from users where id = $1`,
      [userId],
    );
    if (!user || !(await bcrypt.compare(current, user.password ?? ''))) {
      throw new ApiError(400, 'wrong_password', 'The current password is not correct.');
    }
    if (current === next) throw new ApiError(422, 'same_password', 'Choose a password different from the current one.');
    await this.db.query(`update users set password = $2, updated_at = now() where id = $1`, [userId, await hashPassword(next)]);
    await optionalTable(
      () => this.db.query(`update pos_login_security set force_password_change = false, updated_at = now() where user_id = $1`, [userId]),
      [],
    );
    // Other devices signed in with the old password are signed out; the
    // caller continues with a new token.
    await endSessions(this.db, userId, user.organization_id);
    return this.issue({ id: user.id, email: user.email });
  }

  async revoke(token: string): Promise<void> {
    let exp = Math.floor(Date.now() / 1000) + 7 * 86_400;
    let userId: string | null = null;
    try {
      const claims = decodeJwt(token);
      if (typeof claims.exp === 'number') exp = claims.exp;
      if (typeof claims.userId === 'string') userId = claims.userId;
    } catch {
      return; // not a token we issued
    }
    await optionalTable(async () => {
      await this.db.query(`delete from pos_token_revocations where expires_at < now()`);
      await this.db.query(
        `insert into pos_token_revocations (token_hash, user_id, organization_id, expires_at)
         values ($1, $2, (select organization_id from users where id = $2), to_timestamp($3))
         on conflict (token_hash) do nothing`,
        [tokenHash(token), userId, exp],
      );
      return [];
    }, []);
  }

  /// Upserts the account's pos_login_security row (skipped before the POS
  /// migration has been run).
  private async security(user: { id: string; organization_id: string | null }, patch: Record<string, unknown>) {
    const cols = Object.keys(patch);
    await optionalTable(
      () =>
        this.db.query(
          `insert into pos_login_security (user_id, organization_id, ${cols.join(', ')})
           values ($1, $2, ${cols.map((_, i) => `$${i + 3}`).join(', ')})
           on conflict (user_id) do update set ${cols.map((c) => `${c} = excluded.${c}`).join(', ')}, updated_at = now()`,
          [user.id, user.organization_id, ...Object.values(patch)],
        ),
      [],
    );
  }

  private async event(user: { id: string; email: string; organization_id: string | null }, success: boolean, reason: string | null, meta: SignInMeta) {
    await optionalTable(
      () =>
        this.db.query(
          `insert into pos_login_events (organization_id, user_id, email, success, reason, ip, user_agent) values ($1, $2, $3, $4, $5, $6, $7)`,
          [user.organization_id, user.id, user.email, success, reason, meta.ip ?? null, meta.userAgent?.slice(0, 300) ?? null],
        ),
      [],
    );
  }

  async verify(token: string): Promise<AuthUser> {
    let payload: Awaited<ReturnType<typeof jwtVerify>>['payload'];
    try {
      ({ payload } = await jwtVerify(token, this.key, { algorithms: ['HS256'] }));
      if (typeof payload.userId !== 'string') throw new Error('no userId');
    } catch {
      throw unauthorized('Your session has expired. Sign in again.');
    }
    const userId = payload.userId as string;
    const [state] = await optionalTable(
      () =>
        this.db.query<{ revoked: boolean; valid_after: string | null }>(
          `select exists (select 1 from pos_token_revocations where token_hash = $1) as revoked,
                  (select sessions_valid_after from pos_login_security where user_id = $2) as valid_after`,
          [tokenHash(token), userId],
        ),
      [],
    );
    if (state?.revoked) throw unauthorized('You signed out on this device. Sign in again.');
    const issuedMs = typeof payload.iat_ms === 'number' ? payload.iat_ms : typeof payload.iat === 'number' ? payload.iat * 1000 : 0;
    if (state?.valid_after && issuedMs < Date.parse(state.valid_after)) {
      throw unauthorized('Your password was changed. Sign in again.');
    }
    return { id: userId, email: String(payload.email ?? '') };
  }

  async refresh(token: string): Promise<AuthSession> {
    const user = await this.verify(token);
    const claims = decodeJwt(token);
    const authTime = typeof claims.auth_time === 'number' ? claims.auth_time : typeof claims.iat === 'number' ? claims.iat : 0;
    if (Date.now() / 1000 - authTime > MAX_SESSION_DAYS * 86_400) {
      throw unauthorized(`For security, sign in again with your password (every ${MAX_SESSION_DAYS} days).`);
    }
    return this.issue(user, authTime);
  }
}
