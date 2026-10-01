import { z } from 'zod';

const schema = z.object({
  PORT: z.coerce.number().int().positive().default(8787),
  /// Postgres connection string — the same DATABASE_URL master-admin's
  /// backend uses (Supabase → Project Settings → Database → Connection
  /// string, session pooler). Server-side only.
  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required (the same one master-admin uses)'),
  DB_POOL_MAX: z.coerce.number().int().positive().default(10),
  /// Must equal master-admin's JWT_SECRET: tokens are shared.
  JWT_SECRET: z.string().min(16, 'JWT_SECRET must be at least 16 characters (use master-admin\'s)'),
  JWT_EXPIRES_IN: z.string().default('7d'),
  CORS_ORIGINS: z.string().default(''),
});

export type Config = z.infer<typeof schema> & { corsOrigins: string[] };

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = schema.safeParse(env);
  if (!parsed.success) {
    const lines = parsed.error.issues.map((i) => `  ${i.path.join('.')}: ${i.message}`);
    throw new Error(`Invalid backend configuration (backend/.env):\n${lines.join('\n')}`);
  }
  return {
    ...parsed.data,
    corsOrigins: parsed.data.CORS_ORIGINS.split(',').map((s) => s.trim()).filter(Boolean),
  };
}
