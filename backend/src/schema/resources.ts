/// Where each device resource lives in the central database.
///
/// "mapped" resources have a home in the existing Proviyaa OS schema
/// (menu_items, dining_tables, orders, order_items, kot_tickets, payments,
/// kitchen_stations …) and are translated by a hand-written mapper in
/// src/services/sync/mapped/. "mirrored" resources had no table in the
/// live database, so they're stored verbatim in a new pos_* table created
/// by supabase/migrations/20260928_pos_vendor_backend.sql.
///
/// scope "org" = one copy for the whole chain (the franchise master
/// catalogue); "location" = one copy per branch (org_locations row).

export type Scope = 'org' | 'location';

export interface MirroredResource {
  kind: 'mirrored';
  resource: string;
  table: string;
  scope: Scope;
}

export interface MappedResource {
  kind: 'mapped';
  resource: string;
  scope: Scope;
  /// Central tables the mapper writes, for documentation and the API index.
  tables: string[];
}

export type ResourceInfo = MirroredResource | MappedResource;

const mirrored = (resource: string, scope: Scope): MirroredResource => ({
  kind: 'mirrored',
  resource,
  table: `pos_${resource.replace(/-/g, '_')}`,
  scope,
});

const mapped = (resource: string, scope: Scope, tables: string[]): MappedResource => ({
  kind: 'mapped',
  resource,
  scope,
  tables,
});

export const resources: ResourceInfo[] = [
  // Master — existing OS tables.
  mapped('menu-categories', 'org', ['menu_categories']),
  mapped('menu-items', 'org', ['menu_items']),
  // Master — new pos_* tables (no OS table exists).
  mirrored('offers', 'org'),
  mirrored('media-assets', 'org'),
  mirrored('suppliers', 'org'),
  mirrored('supplier-prices', 'org'),
  mirrored('recipes', 'org'),
  mirrored('recipe-lines', 'org'),
  mirrored('raw-materials', 'location'),
  mirrored('purchase-orders', 'location'),
  mirrored('purchase-order-lines', 'location'),
  mirrored('goods-receipts', 'location'),
  mirrored('stock-movements', 'location'),
  // Operations — existing OS tables.
  mapped('settings', 'location', ['kitchen_stations']),
  mapped('tables', 'location', ['dining_tables', 'dining_areas']),
  mapped('orders', 'location', ['orders']),
  mapped('order-lines', 'location', ['order_items']),
  mapped('kitchen-tickets', 'location', ['kot_tickets']),
  mapped('payments', 'location', ['payments']),
  // Operations — new pos_* tables.
  mirrored('shifts', 'location'),
  mirrored('deliveries', 'location'),
  mirrored('reservations', 'location'),
  mirrored('qr-codes', 'location'),
  mirrored('qr-sessions', 'location'),
];

export function resourceInfo(resource: string): ResourceInfo {
  const r = resources.find((x) => x.resource === resource);
  if (!r) throw new Error(`No storage mapping for resource "${resource}"`);
  return r;
}

export const mirroredResources = resources.filter(
  (r): r is MirroredResource => r.kind === 'mirrored',
);

/// Columns every pos_* mirror table adds around the device columns. A
/// device column with one of these names is stored as device_<name>.
export const MIRROR_SERVER_COLUMNS = [
  'row_id',
  'organization_id',
  'location_id',
  'server_created_at',
  'server_updated_at',
  'updated_by',
  'deleted_at',
] as const;

export function mirrorColumnName(deviceColumn: string): string {
  return (MIRROR_SERVER_COLUMNS as readonly string[]).includes(deviceColumn)
    ? `device_${deviceColumn}`
    : deviceColumn;
}
