import { Hono } from 'hono';
import { ctxOf, readJson, type Env } from '../http.js';
import { contract } from '../schema/contract.js';
import { resourceInfo } from '../schema/resources.js';
import { pull, pullSchema, push, pushSchema } from '../services/sync/service.js';

/// The device sync API (offline-first POS ↔ central database).
export function syncRoutes(): Hono<Env> {
  const app = new Hono<Env>();

  app.get('/contract', (c) =>
    c.json({
      data: {
        contract_version: contract.contract_version,
        drift_schema_version: contract.drift_schema_version,
        resources: contract.tables.map((t) => {
          const info = resourceInfo(t.resource);
          return {
            resource: t.resource,
            module: t.module,
            local_table: t.local_table,
            primary_key: t.primary_key,
            scope: info.scope,
            storage: info.kind === 'mirrored' ? [info.table] : info.tables,
          };
        }),
      },
    }),
  );

  app.post('/push', async (c) => {
    const ctx = ctxOf(c);
    const { changes } = await readJson(c, pushSchema);
    const results = await push(ctx, changes);
    const count = (s: string) => results.filter((r) => r.status === s).length;
    return c.json({
      data: {
        results,
        summary: { accepted: count('accepted'), duplicate: count('duplicate'), rejected: count('rejected'), conflict: count('conflict') },
      },
    });
  });

  app.post('/pull', async (c) => {
    const ctx = ctxOf(c);
    const body = await readJson(c, pullSchema);
    const serverTime = new Date().toISOString();
    return c.json({ data: { server_time: serverTime, resources: await pull(ctx, body.resources, body.cursors ?? {}) } });
  });

  return app;
}
