import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    testTimeout: 60_000,
    hookTimeout: 120_000,
    // Each file boots its own embedded Postgres; keep them sequential so
    // the WASM instances don't compete for memory on small machines.
    fileParallelism: false,
  },
});
