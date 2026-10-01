import { contract } from '../../schema/contract.js';
import { resources } from '../../schema/resources.js';
import { MenuCategoriesAdapter, MenuItemsAdapter } from './mapped/menu.js';
import { TablesAdapter } from './mapped/floor.js';
import { KitchenTicketsAdapter, OrderLinesAdapter, OrdersAdapter, PaymentsAdapter } from './mapped/orders.js';
import { SettingsAdapter } from './mapped/settings.js';
import { MirroredAdapter } from './mirrored.js';
import type { SyncAdapter } from './types.js';

const mapped: Record<string, () => SyncAdapter> = {
  'menu-categories': () => new MenuCategoriesAdapter(),
  'menu-items': () => new MenuItemsAdapter(),
  tables: () => new TablesAdapter(),
  orders: () => new OrdersAdapter(),
  'order-lines': () => new OrderLinesAdapter(),
  'kitchen-tickets': () => new KitchenTicketsAdapter(),
  payments: () => new PaymentsAdapter(),
  settings: () => new SettingsAdapter(),
};

/// One adapter per contract resource, in the device's dependency order
/// (parents before children) — pushes are applied in this order.
export const adapters: SyncAdapter[] = contract.tables.map((t) => {
  const info = resources.find((r) => r.resource === t.resource);
  if (!info) throw new Error(`Resource ${t.resource} has no storage mapping in schema/resources.ts`);
  if (info.kind === 'mirrored') return new MirroredAdapter(info);
  const make = mapped[t.resource];
  if (!make) throw new Error(`Mapped resource ${t.resource} has no adapter`);
  return make();
});

export const adapterFor = (resource: string): SyncAdapter | undefined => adapters.find((a) => a.resource === resource);

export const resourceRank = (resource: string): number => adapters.findIndex((a) => a.resource === resource);
