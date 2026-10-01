import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';

async function testSeed() {
  console.log('--- Testing 20260928_restaurant_vendor_test_seed.sql ---');
  const pg = new PGlite();
  await pg.waitReady;

  // Stubs
  await pg.exec(readFileSync('sql/local/00_supabase_stubs.sql', 'utf8'));
  // Master Admin Migrations
  const masterAdminMigrationsDir = '../master-admin/backend/migrations';
  for (const f of [
    '001_create_users_table.sql',
    '002_add_user_roles_and_status.sql',
    '003_drop_business_and_last_login.sql',
    '004_create_organizations_table.sql',
    '005_create_locations_table.sql',
    '006_create_security_roles_table.sql',
    '007_drop_role_and_panel_from_users.sql',
    '008_link_users_to_restaurants.sql',
  ]) {
    await pg.exec(readFileSync(`${masterAdminMigrationsDir}/${f}`, 'utf8'));
  }
  // Snapshot
  await pg.exec(readFileSync('sql/local/10_live_schema_snapshot.sql', 'utf8'));
  // Migration
  await pg.exec(readFileSync('../supabase/migrations/20260928_pos_vendor_backend.sql', 'utf8'));

  // Now run the seed script!
  const seedSql = readFileSync('../supabase/migrations/20260928_restaurant_vendor_test_seed.sql', 'utf8');
  await pg.exec(seedSql);
  console.log('Seed SQL executed successfully on first run!');

  // Test re-run idempotency
  await pg.exec(seedSql);
  console.log('Seed SQL executed successfully on second run (idempotent)!');

  // Verify rows in seeded tables
  const tables = [
    'organizations', 'org_locations', 'menu_categories', 'menu_items',
    'dining_areas', 'dining_tables', 'orders', 'order_items', 'kot_tickets',
    'ol_orders', 'ol_order_items', 'pos_suppliers', 'pos_supplier_prices',
    'pos_raw_materials', 'pos_purchase_orders', 'pos_purchase_order_lines',
    'pos_goods_receipts', 'pos_stock_movements', 'pos_recipes', 'pos_recipe_lines',
    'pos_offers', 'pos_media_assets', 'pos_shifts', 'pos_deliveries',
    'pos_reservations', 'pos_qr_codes', 'pos_qr_sessions', 'pos_branch_targets',
    'pos_franchise_records', 'pos_franchise_exceptions'
  ];

  console.log('\n--- Row Counts in Seeded Tables ---');
  for (const t of tables) {
    const r = await pg.query(`select count(*) as c from public.${t}`);
    console.log(`  ${t.padEnd(28)}: ${r.rows[0].c} rows`);
  }
  await pg.close();
}

testSeed().catch(e => {
  console.error('Seed test error message:', e?.message || e);
  console.error('Seed test error stack:', e?.stack);
  process.exit(1);
});
