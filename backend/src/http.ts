import type { Context } from 'hono';
import { z } from 'zod';
import type { RequestContext } from './context.js';
import { ApiError, badRequest } from './lib/errors.js';

export type Env = { Variables: { ctx: RequestContext } };

export const ctxOf = (c: Context<Env>): RequestContext => c.get('ctx');

export async function readJson<T>(c: Context, schema: z.ZodType<T>): Promise<T> {
  let body: unknown;
  try {
    body = await c.req.json();
  } catch {
    throw badRequest('Request body must be JSON.');
  }
  return parseWith(schema, body);
}

export function parseWith<T>(schema: z.ZodType<T>, value: unknown): T {
  const r = schema.safeParse(value);
  if (!r.success) {
    throw new ApiError(
      400,
      'validation_failed',
      'Some fields are missing or invalid.',
      r.error.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
    );
  }
  return r.data;
}

export function intParam(v: string | undefined, fallback: number, max: number): number {
  const n = v === undefined ? fallback : Number(v);
  if (!Number.isInteger(n) || n < 0) throw badRequest('limit/offset must be non-negative integers.');
  return Math.min(n, max);
}
