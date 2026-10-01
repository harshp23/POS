-- Local mode / tests only: the Proviyaa OS tables the POS backend uses, as
-- they exist on the live Supabase project (docs/EXISTING-DATABASE-MAP.txt).
-- organizations, org_locations and users come from master-admin's own
-- migrations (master-admin/backend/migrations), applied before this file.
--
-- Column names and types are the ones discovered on the live project.
-- Constraints, defaults and RLS policies come from the Proviyaa OS repo
-- migrations (loki1514/Repo-1-, 0001–0010), whose columns match the live
-- tables one for one. For the tables that differ from the repo
-- (organizations, org_locations, ol_orders, ol_order_items), the live
-- policies can't be seen with a publishable key, so this snapshot gives
-- them the most restrictive plausible shape — platform admins / owners
-- only — which is exactly the situation the additive migration
-- (supabase/migrations/20260928_pos_vendor_backend.sql) has to handle.

-- ----------------------------------------------------------------------------
-- Tenancy
-- ----------------------------------------------------------------------------

create table public.platform_admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  email      text not null,
  created_at timestamptz not null default now()
);
alter table public.platform_admins enable row level security;

create or replace function public.is_platform_admin()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$ select exists (select 1 from public.platform_admins where user_id = auth.uid()); $$;

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public, pg_temp
as $$ begin new.updated_at = now(); return new; end; $$;

create table public.roles (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  name        text not null,
  description text,
  is_system   boolean not null default false,
  created_at  timestamptz not null default now()
);
insert into public.roles (slug, name, is_system) values
  ('org_admin', 'Organization Admin', true), ('manager', 'Manager', true),
  ('biller', 'Biller / POS', true), ('captain', 'Captain', true), ('kitchen', 'KOT / Kitchen', true),
  ('org_owner', 'Organization Owner', true), ('business_manager', 'Business Manager', true),
  ('location_manager', 'Branch / Location Manager', true), ('operations_manager', 'Operations Manager', true),
  ('finance_manager', 'Finance Manager', true), ('accountant', 'Accountant', true),
  ('hr_manager', 'HR / Staff Manager', true), ('marketing_manager', 'Marketing Manager', true),
  ('inventory_manager', 'Inventory Manager', true), ('procurement_manager', 'Procurement Manager', true),
  ('support_user', 'Customer Support User', true), ('analyst', 'Analyst / Reporting User', true),
  ('staff_user', 'Staff User', true), ('viewer', 'Viewer', true);
alter table public.roles enable row level security;
create policy roles_read on public.roles for select to authenticated using (true);
grant select on public.roles to authenticated;

create type public.member_status as enum ('active', 'suspended');

create table public.org_users (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  user_id         uuid not null references auth.users (id) on delete cascade,
  role_id         uuid not null references public.roles (id),
  email           text not null,
  full_name       text,
  status          public.member_status not null default 'active',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint org_users_org_user_unique unique (organization_id, user_id)
);

create or replace function public.current_org_id()
returns uuid language sql stable security definer set search_path = public, pg_temp
as $$ select organization_id from public.org_users where user_id = auth.uid() and status = 'active' limit 1; $$;

create or replace function public.is_org_admin(org uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$
  select exists (select 1 from public.org_users u join public.roles r on r.id = u.role_id
                 where u.user_id = auth.uid() and u.organization_id = org
                   and u.status = 'active' and r.slug = 'org_admin');
$$;
grant execute on function public.is_platform_admin() to anon, authenticated, service_role;
grant execute on function public.current_org_id() to authenticated, service_role;
grant execute on function public.is_org_admin(uuid) to authenticated, service_role;

alter table public.org_users enable row level security;
create policy org_users_platform_admin_all on public.org_users for all
  using (public.is_platform_admin()) with check (public.is_platform_admin());
create policy org_users_member_select on public.org_users for select
  using (organization_id = public.current_org_id());
create policy org_users_admin_update on public.org_users for update
  using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));
grant select, insert, update, delete on public.org_users to authenticated;

-- ----------------------------------------------------------------------------
-- 0006 POS domain
-- ----------------------------------------------------------------------------

create table public.org_counters (
  organization_id uuid not null references public.organizations (id) on delete cascade,
  kind            text not null,
  value           bigint not null default 0,
  primary key (organization_id, kind)
);
alter table public.org_counters enable row level security;
create policy org_counters_member_select on public.org_counters for select
  using (organization_id = public.current_org_id());

create or replace function public.next_org_seq(org uuid, counter_kind text)
returns bigint language plpgsql security definer set search_path = public, pg_temp
as $$
declare next_value bigint;
begin
  insert into public.org_counters (organization_id, kind, value) values (org, counter_kind, 1)
  on conflict (organization_id, kind) do update set value = org_counters.value + 1
  returning value into next_value;
  return next_value;
end;
$$;
grant execute on function public.next_org_seq(uuid, text) to authenticated, service_role;
grant select, insert, update on public.org_counters to authenticated;

create table public.menu_categories (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name            text not null,
  sort_order      int not null default 0,
  created_at      timestamptz not null default now(),
  constraint menu_categories_name_not_blank check (length(btrim(name)) > 0)
);

create table public.menu_items (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  category_id     uuid references public.menu_categories (id) on delete set null,
  name            text not null,
  sku             text,
  price           numeric(10, 2) not null,
  image_url       text,
  is_available    boolean not null default true,
  sort_order      int not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  description     text,
  food_type       text not null default 'veg' check (food_type in ('veg', 'non_veg', 'egg')),
  course          text not null default 'eat' check (course in ('eat', 'drink')),
  is_recommended  boolean not null default false,
  prep_minutes    int not null default 10,
  station         text not null default 'main',
  constraint menu_items_name_not_blank check (length(btrim(name)) > 0),
  constraint menu_items_price_non_negative check (price >= 0)
);
create trigger menu_items_set_updated_at before update on public.menu_items
  for each row execute function public.set_updated_at();

create table public.dining_areas (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name            text not null,
  sort_order      int not null default 0,
  created_at      timestamptz not null default now(),
  constraint dining_areas_name_not_blank check (length(btrim(name)) > 0),
  constraint dining_areas_org_name_unique unique (organization_id, name)
);

create table public.dining_tables (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  label           text not null,
  seats           int not null default 4,
  is_active       boolean not null default true,
  sort_order      int not null default 0,
  created_at      timestamptz not null default now(),
  area_id         uuid references public.dining_areas (id) on delete set null,
  qr_token        text unique,
  min_capacity    int not null default 1,
  constraint dining_tables_label_not_blank check (length(btrim(label)) > 0),
  constraint dining_tables_seats_positive check (seats > 0),
  constraint dining_tables_org_label_unique unique (organization_id, label)
);

create table public.table_sessions (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  table_id        uuid not null references public.dining_tables (id) on delete cascade,
  pin             text not null,
  guest_name      text,
  guest_phone     text,
  guest_count     int not null default 1,
  status          text not null default 'open' check (status in ('open', 'billed', 'closed')),
  opened_at       timestamptz not null default now(),
  closed_at       timestamptz,
  constraint table_sessions_pin_shape check (pin ~ '^[0-9]{4}$'),
  constraint table_sessions_guest_count_positive check (guest_count > 0)
);

create table public.orders (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  order_no        bigint not null,
  display_no      text not null,
  channel         text not null default 'dine_in'
    check (channel in ('dine_in', 'delivery', 'pickup', 'online', 'swiggy', 'zomato', 'other')),
  status          text not null default 'new'
    check (status in ('new', 'in_billing', 'sent_to_kitchen', 'ready', 'awaiting_payment', 'paid', 'delivered', 'cancelled')),
  table_id        uuid references public.dining_tables (id) on delete set null,
  customer_name   text,
  customer_phone  text,
  captain_name    text,
  subtotal        numeric(10, 2) not null default 0,
  gst_pct         numeric(4, 2) not null default 5,
  gst_amount      numeric(10, 2) not null default 0,
  total           numeric(10, 2) not null default 0,
  payment_method  text check (payment_method is null or payment_method in ('cash', 'upi', 'card', 'split')),
  created_by      uuid references auth.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  session_id      uuid references public.table_sessions (id) on delete set null,
  placed_by       text not null default 'pos' check (placed_by in ('pos', 'captain', 'guest', 'integration')),
  guest_count     int not null default 1,
  discount        numeric(10, 2) not null default 0,
  service_charge  numeric(10, 2) not null default 0,
  round_off       numeric(10, 2) not null default 0,
  paid_at         timestamptz,
  notes           text,
  external_ref    text,
  constraint orders_org_order_no_unique unique (organization_id, order_no)
);
create trigger orders_set_updated_at before update on public.orders
  for each row execute function public.set_updated_at();

create table public.kot_tickets (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  order_id        uuid not null references public.orders (id) on delete cascade,
  kot_no          bigint not null,
  station         text not null default 'main',
  status          text not null default 'new' check (status in ('new', 'preparing', 'ready', 'delivered')),
  priority        text not null default 'normal' check (priority in ('normal', 'urgent')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint kot_tickets_org_kot_no_unique unique (organization_id, kot_no)
);
create trigger kot_tickets_set_updated_at before update on public.kot_tickets
  for each row execute function public.set_updated_at();

create table public.order_items (
  id            uuid primary key default gen_random_uuid(),
  order_id      uuid not null references public.orders (id) on delete cascade,
  menu_item_id  uuid references public.menu_items (id) on delete set null,
  name          text not null,
  qty           int not null check (qty > 0),
  unit_price    numeric(10, 2) not null check (unit_price >= 0),
  add_ons       jsonb not null default '[]'::jsonb,
  notes         text,
  created_at    timestamptz not null default now(),
  variant_name  text,
  status        text not null default 'pending'
    check (status in ('pending', 'preparing', 'ready', 'delivered', 'cancelled')),
  kot_ticket_id uuid references public.kot_tickets (id) on delete set null,
  course        text not null default 'eat',
  station       text not null default 'main'
);

-- Member policies of 0006 (orders: no member delete).
do $$
declare t text;
begin
  foreach t in array array['menu_categories', 'menu_items', 'dining_tables', 'kot_tickets'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy %I on public.%I for all using (public.is_platform_admin()) with check (public.is_platform_admin())', t || '_platform_admin_all', t);
    execute format('create policy %I on public.%I for select using (organization_id = public.current_org_id())', t || '_member_select', t);
    execute format('create policy %I on public.%I for insert with check (organization_id = public.current_org_id())', t || '_member_insert', t);
    execute format('create policy %I on public.%I for update using (organization_id = public.current_org_id()) with check (organization_id = public.current_org_id())', t || '_member_update', t);
    execute format('create policy %I on public.%I for delete using (organization_id = public.current_org_id())', t || '_member_delete', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end;
$$;

alter table public.orders enable row level security;
create policy orders_platform_admin_all on public.orders for all
  using (public.is_platform_admin()) with check (public.is_platform_admin());
create policy orders_member_select on public.orders for select using (organization_id = public.current_org_id());
create policy orders_member_insert on public.orders for insert with check (organization_id = public.current_org_id());
create policy orders_member_update on public.orders for update
  using (organization_id = public.current_org_id()) with check (organization_id = public.current_org_id());
grant select, insert, update on public.orders to authenticated;

alter table public.order_items enable row level security;
create policy order_items_member_select on public.order_items for select using (exists (
  select 1 from public.orders o where o.id = order_items.order_id and o.organization_id = public.current_org_id()));
create policy order_items_member_insert on public.order_items for insert with check (exists (
  select 1 from public.orders o where o.id = order_items.order_id and o.organization_id = public.current_org_id()));
create policy order_items_member_update on public.order_items for update using (exists (
  select 1 from public.orders o where o.id = order_items.order_id and o.organization_id = public.current_org_id()))
  with check (exists (
  select 1 from public.orders o where o.id = order_items.order_id and o.organization_id = public.current_org_id()));
create policy order_items_member_delete on public.order_items for delete using (exists (
  select 1 from public.orders o where o.id = order_items.order_id and o.organization_id = public.current_org_id()));
grant select, insert, update, delete on public.order_items to authenticated;

-- ----------------------------------------------------------------------------
-- 0010 restaurant operations (apply_org_rls shape: no member delete)
-- ----------------------------------------------------------------------------

create table public.menu_item_variants (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  menu_item_id    uuid not null references public.menu_items (id) on delete cascade,
  name            text not null,
  price           numeric(10, 2) not null check (price >= 0),
  is_default      boolean not null default false,
  sort_order      int not null default 0,
  constraint menu_item_variants_item_name_unique unique (menu_item_id, name)
);

create table public.kitchen_stations (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  key             text not null,
  name            text not null,
  colour          text not null default '#79bc0d',
  sort_order      int not null default 0,
  constraint kitchen_stations_org_key_unique unique (organization_id, key)
);

create table public.order_events (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  order_id        uuid not null references public.orders (id) on delete cascade,
  kind            text not null,
  message         text not null,
  actor           text,
  meta            jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);

create table public.org_bill_settings (
  organization_id    uuid primary key references public.organizations (id) on delete cascade,
  legal_name         text,
  address            text,
  gstin              text,
  fssai              text,
  phone              text,
  sgst_pct           numeric(5, 2) not null default 2.5,
  cgst_pct           numeric(5, 2) not null default 2.5,
  service_charge_pct numeric(5, 2) not null default 0,
  round_off_enabled  boolean not null default true,
  footer_note        text,
  updated_at         timestamptz not null default now()
);

create table public.payments (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  order_id        uuid not null references public.orders (id) on delete cascade,
  method          text not null check (method in ('cash', 'upi', 'card', 'wallet', 'due', 'other')),
  amount          numeric(10, 2) not null check (amount > 0),
  reference       text,
  created_by      uuid references auth.users (id) on delete set null,
  created_at      timestamptz not null default now()
);

create table public.channel_integrations (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  channel         text not null check (channel in ('swiggy', 'zomato', 'ondc', 'website', 'whatsapp', 'qr')),
  display_name    text not null,
  is_connected    boolean not null default false,
  is_accepting    boolean not null default true,
  next_open_at    timestamptz,
  auto_accept     boolean not null default true,
  commission_pct  numeric(5, 2) not null default 0,
  config          jsonb not null default '{}'::jsonb,
  updated_at      timestamptz not null default now(),
  constraint channel_integrations_org_channel_unique unique (organization_id, channel)
);

create table public.item_channel_status (
  organization_id uuid not null references public.organizations (id) on delete cascade,
  menu_item_id    uuid not null references public.menu_items (id) on delete cascade,
  channel         text not null,
  is_available    boolean not null default true,
  off_until       timestamptz,
  updated_at      timestamptz not null default now(),
  primary key (menu_item_id, channel)
);

do $$
declare t text;
begin
  foreach t in array array['dining_areas', 'table_sessions', 'menu_item_variants', 'kitchen_stations',
                           'order_events', 'org_bill_settings', 'payments', 'channel_integrations',
                           'item_channel_status'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy %I on public.%I for all using (public.is_platform_admin()) with check (public.is_platform_admin())', t || '_platform_admin_all', t);
    execute format('create policy %I on public.%I for select using (organization_id = public.current_org_id())', t || '_member_select', t);
    execute format('create policy %I on public.%I for insert with check (organization_id = public.current_org_id())', t || '_member_write', t);
    execute format('create policy %I on public.%I for update using (organization_id = public.current_org_id()) with check (organization_id = public.current_org_id())', t || '_member_update', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end;
$$;

-- ----------------------------------------------------------------------------
-- One Latur marketplace (live shape; customer-owned policies only)
-- ----------------------------------------------------------------------------

create table public.ol_orders (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid references public.organizations (id) on delete set null,
  user_id          uuid references auth.users (id) on delete set null,
  status           text not null default 'placed',
  subtotal         numeric(10, 2) not null default 0,
  discount         numeric(10, 2) not null default 0,
  gst              numeric(10, 2) not null default 0,
  delivery_fee     numeric(10, 2) not null default 0,
  total            numeric(10, 2) not null default 0,
  payment_method   text,
  payment_status   text,
  prep_minutes     int,
  eta_minutes      int,
  items            jsonb not null default '[]'::jsonb,
  delivery_address jsonb,
  rider_name       text,
  rider_phone      text,
  customer_hash    text,
  cancelled_by     uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
alter table public.ol_orders enable row level security;
create policy ol_orders_customer_select on public.ol_orders for select using (user_id = auth.uid());

create table public.ol_order_items (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references public.ol_orders (id) on delete cascade,
  product_id   text,
  menu_item_id uuid references public.menu_items (id) on delete set null,
  name         text not null,
  image        text,
  price        numeric(10, 2) not null default 0,
  mrp          numeric(10, 2),
  discount     numeric(10, 2) not null default 0,
  qty          int not null default 1,
  line_total   numeric(10, 2) not null default 0,
  created_at   timestamptz not null default now()
);
alter table public.ol_order_items enable row level security;
create policy ol_order_items_customer_select on public.ol_order_items for select using (exists (
  select 1 from public.ol_orders o where o.id = ol_order_items.order_id and o.user_id = auth.uid()));

grant select on public.ol_orders, public.ol_order_items to service_role;
