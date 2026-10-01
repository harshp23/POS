import { Hono } from 'hono';
import type { Env } from '../http.js';
import { mirroredResources } from '../schema/resources.js';
import { mountTableResource } from './crud.js';
import { mountMirroredResource } from './mirrored-rest.js';

/// Master service: the chain's catalogue and back-office data.
///   OS tables:  menu-categories, menu-items, menu-item-variants
///   pos_* :     offers, media-assets, suppliers, supplier-prices, recipes,
///               recipe-lines, raw-materials, purchase-orders,
///               purchase-order-lines, goods-receipts, stock-movements
export function masterRoutes(): Hono<Env> {
  const app = new Hono<Env>();

  mountTableResource(app, {
    path: 'menu-categories',
    table: 'menu_categories',
    module: 'master',
    columns: { name: 'text!', sort_order: 'int' },
    order: [{ col: 'sort_order' }, { col: 'name' }],
    remove: 'hard',
  });

  mountTableResource(app, {
    path: 'menu-items',
    table: 'menu_items',
    module: 'master',
    columns: {
      name: 'text!',
      price: 'numeric!',
      category_id: 'uuid?',
      description: 'text?',
      sku: 'text?',
      image_url: 'text?',
      is_available: 'bool',
      is_recommended: 'bool',
      sort_order: 'int',
      station: 'text',
      course: 'enum:eat|drink',
      food_type: 'enum:veg|non_veg|egg',
      prep_minutes: 'int',
    },
    filters: ['category_id', 'is_available', 'food_type'],
    refs: { category_id: { table: 'menu_categories' } },
    order: [{ col: 'sort_order' }, { col: 'name' }],
    versionColumn: 'updated_at',
    remove: 'hard',
  });

  mountTableResource(app, {
    path: 'menu-item-variants',
    table: 'menu_item_variants',
    module: 'master',
    columns: { menu_item_id: 'uuid!', name: 'text!', price: 'numeric!', is_default: 'bool', sort_order: 'int' },
    filters: ['menu_item_id'],
    refs: { menu_item_id: { table: 'menu_items' } },
    order: [{ col: 'sort_order' }],
    remove: 'none',
  });

  for (const r of mirroredResources.filter((m) => m.resource !== 'shifts' && !isOperations(m.resource))) {
    mountMirroredResource(app, r);
  }
  return app;
}

const OPERATIONS_MIRRORS = ['shifts', 'deliveries', 'reservations', 'qr-codes', 'qr-sessions'];
export const isOperations = (resource: string) => OPERATIONS_MIRRORS.includes(resource);
