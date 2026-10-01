import type { MiddlewareHandler } from 'hono';
import { requireScreen, type RequestContext } from '../context.js';
import type { Row } from '../db/types.js';
import { ctxOf, type Env } from '../http.js';
import { unprocessable } from '../lib/errors.js';

/// Every route of a panel section needs the section's screen (src/access.ts);
/// the module rules (src/permissions.ts) are checked per route on top.
export function sectionGuard(screen: string): MiddlewareHandler<Env> {
  return async (c, next) => {
    requireScreen(ctxOf(c), screen);
    await next();
  };
}

export const actorName = (ctx: RequestContext) => ctx.identity.full_name || ctx.identity.email;

export async function audit(ctx: RequestContext, action: string, entity: string, entityId?: string | null, details: Row = {}) {
  try {
    await ctx.db.query(
      `insert into pos_audit_log (organization_id, actor_id, actor_name, action, entity, entity_id, details)
       values ($1, $2, $3, $4, $5, $6, $7)`,
      [ctx.m.organization_id, ctx.identity.user_id, actorName(ctx), action, entity, entityId ?? null, details],
    );
  } catch {
    // The audit trail must never fail the change it records.
  }
}

/// Numeric columns come back as strings from Postgres; money is rupees.
export const num = (v: unknown): number => {
  const n = typeof v === 'number' ? v : Number(v ?? 0);
  return Number.isFinite(n) ? n : 0;
};
export const money = (v: unknown): number => Math.round(num(v) * 100) / 100;

/// Phone numbers are stored as digits only (10–15), so "+91 98765 43210"
/// and "9876543210" are the same customer. Orders are matched on the last
/// ten digits.
export function normalizePhone(raw: string): string {
  const digits = raw.replace(/\D/g, '');
  if (digits.length < 10 || digits.length > 15) throw unprocessable('Enter a phone number with 10 digits.');
  return digits.length > 10 && digits.startsWith('91') && digits.length === 12 ? digits.slice(2) : digits;
}

/// SQL: the last ten digits of a phone column, for matching orders.
export const phoneKey = (col: string) => `right(regexp_replace(coalesce(${col}, ''), '\\D', '', 'g'), 10)`;

/// Today in YYYY-MM-DD (server local calendar, Asia/Kolkata by default).
export const isoDate = (d: Date) => d.toISOString().slice(0, 10);
