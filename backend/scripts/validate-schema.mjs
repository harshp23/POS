import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';

async function testSql() {
  console.log('--- Testing SQL migration execution in Postgres (PGlite) ---');
  const pg = new PGlite();
  await pg.waitReady;
  console.log('PGlite ready.');

  // Load stubs
  const stubs = readFileSync('sql/local/00_supabase_stubs.sql', 'utf8');
  await pg.exec(stubs);
  console.log('Stubs applied.');

  // Load master-admin migrations (001-008)
  const masterAdminMigrationsDir = '../master-admin/backend/migrations';
  const migrationFiles = [
    '001_create_users_table.sql',
    '002_add_user_roles_and_status.sql',
    '003_drop_business_and_last_login.sql',
    '004_create_organizations_table.sql',
    '005_create_locations_table.sql',
    '006_create_security_roles_table.sql',
    '007_drop_role_and_panel_from_users.sql',
    '008_link_users_to_restaurants.sql',
  ];
  for (const f of migrationFiles) {
    const sql = readFileSync(`${masterAdminMigrationsDir}/${f}`, 'utf8');
    await pg.exec(sql);
  }
  console.log('Master-admin base migrations (001-008) applied.');

  const snapshot = readFileSync('sql/local/10_live_schema_snapshot.sql', 'utf8');
  await pg.exec(snapshot);
  console.log('Live schema snapshot applied.');

  // Load the schema under test
  const migration = readFileSync('../supabase/migrations/20260928_pos_vendor_backend.sql', 'utf8');
  await pg.exec(migration);
  console.log('Schema 20260928_pos_vendor_backend.sql executed successfully without errors!\n');

  // Check tables created
  const res = await pg.query(
    "select tablename, rowsecurity as rls from pg_tables where schemaname = 'public' and tablename like 'pos_%' order by 1"
  );
  console.log(`Found ${res.rows.length} pos_* tables created:`);
  for (const r of res.rows) {
    console.log(`  - ${r.tablename}: rls=${r.rls}`);
  }

  // Check columns on core tables
  const cols = await pg.query(
    "select table_name, column_name, data_type from information_schema.columns where table_schema = 'public' and column_name = 'location_id' and table_name in ('orders', 'dining_tables', 'dining_areas')"
  );
  console.log(`\nlocation_id added to core tables:`);
  for (const c of cols.rows) {
    console.log(`  - ${c.table_name}.${c.column_name} (${c.data_type})`);
  }

  // Check constraints
  const constr = await pg.query(
    "select conname, conrelid::regclass as tbl from pg_constraint where conname like '%location%label%' or conname like '%location%name%'"
  );
  console.log(`\nUnique branch constraints:`);
  for (const c of constr.rows) {
    console.log(`  - ${c.tbl}: ${c.conname}`);
  }

  // Test re-running the migration (idempotency check!)
  console.log('\nTesting migration re-run idempotency...');
  await pg.exec(migration);
  console.log('Re-run succeeded with zero errors! (Idempotent safe to re-run verified)');
  await pg.close();
}

testSql().catch(e => {
  console.error('Execution error message:', e?.message || e);
  console.error('Execution error stack:', e?.stack);
  process.exit(1);
});
