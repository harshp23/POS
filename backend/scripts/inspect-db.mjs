const SUPABASE_URL = 'https://ywylhzcxuoeilygzdonx.supabase.co';
const KEY = 'sb_publishable_jx2WYiDuTQYrfIFd2BdGew_G_xNg1bG';

const tables = [
  'pos_entity_extras', 'pos_sync_receipts', 'pos_franchise_records',
  'pos_branch_targets', 'pos_franchise_exceptions', 'pos_offers',
  'pos_media_assets', 'pos_suppliers', 'pos_supplier_prices',
  'pos_recipes', 'pos_recipe_lines', 'pos_raw_materials',
  'pos_purchase_orders', 'pos_purchase_order_lines', 'pos_goods_receipts',
  'pos_stock_movements', 'pos_shifts', 'pos_deliveries',
  'pos_reservations', 'pos_qr_codes', 'pos_qr_sessions',
  'pos_staff', 'pos_staff_roles', 'pos_staff_attendance', 'pos_staff_shifts',
  'pos_staff_roster', 'pos_staff_advances', 'pos_staff_salaries', 'pos_staff_approvals',
  'pos_training_modules', 'pos_training_attempts', 'pos_login_security',
  'pos_login_events', 'pos_audit_log', 'pos_token_revocations',
  'organizations', 'org_locations', 'orders', 'dining_tables', 'dining_areas',
  'ol_orders', 'ol_order_items', 'menu_categories', 'menu_items', 'roles'
];

async function check() {
  console.log('--- Probing Supabase DB Status (Read-Only) ---');
  for (const t of tables) {
    try {
      const res = await fetch(`${SUPABASE_URL}/rest/v1/${t}?select=*&limit=0`, {
        headers: { apikey: KEY, Authorization: `Bearer ${KEY}` }
      });
      const body = await res.json().catch(() => ({}));
      const code = body.code || res.status;
      const message = body.message || '';
      const exists = code === '42501' || res.status === 200;
      const missing = code === 'PGRST205';
      console.log(`${t.padEnd(28)}: status=${res.status}, code=${code}, exists=${exists}, missing=${missing} ${message ? `(${message.slice(0, 45)})` : ''}`);
    } catch (e) {
      console.error(`${t}: error`, e.message);
    }
  }

  console.log('\n--- Checking column existence (location_id) on core tables ---');
  for (const t of ['orders', 'dining_tables', 'dining_areas']) {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/${t}?select=location_id&limit=0`, {
      headers: { apikey: KEY, Authorization: `Bearer ${KEY}` }
    });
    const body = await res.json().catch(() => ({}));
    const code = body.code || res.status;
    console.log(`${t}.location_id : status=${res.status}, code=${code}, message=${body.message || ''}`);
  }

  console.log('\n--- Checking RPC functions ---');
  for (const fn of ['is_platform_admin', 'current_org_id', 'pos_touch_server_updated_at', 'pos_apply_member_rls']) {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
      method: 'POST',
      headers: {
        apikey: KEY,
        Authorization: `Bearer ${KEY}`,
        'Content-Type': 'application/json'
      },
      body: '{}'
    });
    let body;
    try { body = await res.json(); } catch { body = await res.text(); }
    console.log(`RPC ${fn.padEnd(28)}: status=${res.status}, body=${JSON.stringify(body)}`);
  }

  // is_org_admin takes an argument
  const orgAdminRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/is_org_admin`, {
    method: 'POST',
    headers: {
      apikey: KEY,
      Authorization: `Bearer ${KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ org: '00000000-0000-0000-0000-000000000000' })
  });
  let orgAdminBody;
  try { orgAdminBody = await orgAdminRes.json(); } catch { orgAdminBody = await orgAdminRes.text(); }
  console.log(`RPC is_org_admin (with org param): status=${orgAdminRes.status}, body=${JSON.stringify(orgAdminBody)}`);
}

check();
