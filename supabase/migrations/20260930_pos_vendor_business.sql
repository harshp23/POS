-- ============================================================================
-- 20260930 — Proviyaa POS vendor panel: Customers & CRM, Marketing, Finance,
-- Integrations, Task Manager and Settings (additive).
--
-- Run once in the Supabase SQL editor, after 20260928_pos_vendor_backend.sql
-- (it uses public.pos_apply_member_rls and the touch functions from there).
-- Safe to re-run: every statement is guarded.
--
-- It does NOT drop or change any existing table, column or row. Every table
-- below is new, organization-scoped and RLS-on exactly like the other pos_*
-- tables: no access for the publishable (anon) key; the POS backend
-- connects with DATABASE_URL and enforces tenancy in code as well.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Customers & CRM
-- ----------------------------------------------------------------------------

create table if not exists public.pos_customers (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id) on delete cascade,
  location_id      uuid references public.org_locations (id) on delete set null,
  first_name       text not null check (length(btrim(first_name)) > 0),
  last_name        text not null default '',
  phone            text not null check (length(btrim(phone)) > 0),
  email            text,
  gst_number       text,
  date_of_birth    date,
  anniversary      date,
  preferred_dining text not null default 'dine_in' check (preferred_dining in ('dine_in', 'takeaway', 'delivery')),
  address          text not null default '',
  tags             text[] not null default '{}',
  notes            text not null default '',
  allow_whatsapp   boolean not null default true,
  allow_sms        boolean not null default true,
  allow_email      boolean not null default false,
  allow_push       boolean not null default false,
  created_by       uuid references public.users (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);
comment on table public.pos_customers is
  'Restaurant customers. Orders are linked by phone (orders.customer_phone), so one profile covers POS, QR and online orders.';
create unique index if not exists pos_customers_phone_uq
  on public.pos_customers (organization_id, phone) where deleted_at is null;
create index if not exists pos_customers_org_idx on public.pos_customers (organization_id, created_at desc);
drop trigger if exists pos_customers_touch on public.pos_customers;
create trigger pos_customers_touch before update on public.pos_customers
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_customers', true);

create table if not exists public.pos_customer_segments (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name            text not null check (length(btrim(name)) > 0),
  description     text not null default '',
  rules           jsonb not null default '{}'::jsonb,
  created_by      uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
comment on table public.pos_customer_segments is
  'Custom customer segments: rules {tags, min_spend, min_orders, inactive_days, channel} evaluated by the backend.';
create unique index if not exists pos_customer_segments_name_uq
  on public.pos_customer_segments (organization_id, lower(name)) where deleted_at is null;
drop trigger if exists pos_customer_segments_touch on public.pos_customer_segments;
create trigger pos_customer_segments_touch before update on public.pos_customer_segments
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_customer_segments', true);

create table if not exists public.pos_loyalty_settings (
  organization_id   uuid primary key references public.organizations (id) on delete cascade,
  enabled           boolean not null default true,
  earn_per_amount   numeric(12, 2) not null default 100 check (earn_per_amount > 0),
  points_per_earn   integer not null default 5 check (points_per_earn >= 0),
  point_value       numeric(12, 2) not null default 1 check (point_value >= 0),
  min_redeem_points integer not null default 100 check (min_redeem_points >= 0),
  max_redeem_pct    numeric(5, 2) not null default 20 check (max_redeem_pct between 0 and 100),
  expiry_days       integer not null default 365 check (expiry_days >= 0),
  tiers             jsonb not null default '[{"name":"Silver","min_spend":0},{"name":"Gold","min_spend":10000},{"name":"Platinum","min_spend":50000}]'::jsonb,
  updated_by        uuid references public.users (id) on delete set null,
  updated_at        timestamptz not null default now()
);
drop trigger if exists pos_loyalty_settings_touch on public.pos_loyalty_settings;
create trigger pos_loyalty_settings_touch before update on public.pos_loyalty_settings
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_loyalty_settings', false);

create table if not exists public.pos_loyalty_ledger (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  customer_id     uuid not null references public.pos_customers (id) on delete cascade,
  entry_type      text not null check (entry_type in ('earn', 'redeem', 'adjust', 'expire')),
  points          integer not null check (points <> 0),
  balance_after   integer not null check (balance_after >= 0),
  note            text not null default '',
  order_ref       text,
  created_by      uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now()
);
comment on table public.pos_loyalty_ledger is 'Loyalty points ledger (append-only).';
create index if not exists pos_loyalty_ledger_org_idx on public.pos_loyalty_ledger (organization_id, created_at desc);
create index if not exists pos_loyalty_ledger_customer_idx on public.pos_loyalty_ledger (customer_id, created_at desc);
-- One earn row per bill, so crediting a bill twice is impossible.
create unique index if not exists pos_loyalty_ledger_order_uq
  on public.pos_loyalty_ledger (organization_id, order_ref) where entry_type = 'earn' and order_ref is not null;
select public.pos_apply_member_rls('public.pos_loyalty_ledger', false);

create table if not exists public.pos_wallet_ledger (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  customer_id     uuid not null references public.pos_customers (id) on delete cascade,
  entry_type      text not null check (entry_type in ('topup', 'redeem', 'refund', 'adjust')),
  amount          numeric(12, 2) not null check (amount <> 0),
  method          text not null default 'cash',
  balance_after   numeric(12, 2) not null check (balance_after >= 0),
  note            text not null default '',
  created_by      uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now()
);
comment on table public.pos_wallet_ledger is 'Customer store-credit wallet ledger (append-only).';
create index if not exists pos_wallet_ledger_org_idx on public.pos_wallet_ledger (organization_id, created_at desc);
create index if not exists pos_wallet_ledger_customer_idx on public.pos_wallet_ledger (customer_id, created_at desc);
select public.pos_apply_member_rls('public.pos_wallet_ledger', false);

create table if not exists public.pos_customer_feedback (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  location_id     uuid references public.org_locations (id) on delete set null,
  customer_id     uuid references public.pos_customers (id) on delete set null,
  customer_name   text not null default '',
  rating          integer not null check (rating between 1 and 5),
  comment         text not null default '',
  channel         text not null default 'dine_in' check (channel in ('dine_in', 'takeaway', 'delivery', 'qr', 'online')),
  order_ref       text,
  status          text not null default 'new' check (status in ('new', 'acknowledged', 'resolved')),
  response        text not null default '',
  created_by      uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
create index if not exists pos_customer_feedback_org_idx on public.pos_customer_feedback (organization_id, created_at desc);
drop trigger if exists pos_customer_feedback_touch on public.pos_customer_feedback;
create trigger pos_customer_feedback_touch before update on public.pos_customer_feedback
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_customer_feedback', true);

-- ----------------------------------------------------------------------------
-- Marketing (promotions themselves are public.pos_offers — Master → Offers)
-- ----------------------------------------------------------------------------

create table if not exists public.pos_campaigns (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name            text not null check (length(btrim(name)) > 0),
  channel         text not null check (channel in ('whatsapp', 'sms', 'email', 'push')),
  segment         text not null default 'all',
  offer_code      text,
  schedule_at     timestamptz,
  recurrence      text not null default 'once' check (recurrence in ('once', 'daily', 'weekly', 'monthly')),
  title           text not null default '',
  message         text not null check (length(btrim(message)) > 0),
  status          text not null default 'draft' check (status in ('draft', 'scheduled', 'queued', 'sent', 'cancelled')),
  status_note     text not null default '',
  audience_count  integer not null default 0,
  sent_count      integer not null default 0,
  delivered_count integer not null default 0,
  clicks          integer not null default 0,
  revenue         numeric(12, 2) not null default 0,
  created_by      uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
comment on table public.pos_campaigns is
  'Customer campaigns. Nothing is delivered until a messaging provider is connected (status stays queued with a note).';
create index if not exists pos_campaigns_org_idx on public.pos_campaigns (organization_id, created_at desc);
drop trigger if exists pos_campaigns_touch on public.pos_campaigns;
create trigger pos_campaigns_touch before update on public.pos_campaigns
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_campaigns', true);

create table if not exists public.pos_offer_rules (
  organization_id      uuid not null references public.organizations (id) on delete cascade,
  offer_id             text not null,
  offer_type           text not null default 'promo_code' check (offer_type in ('promo_code', 'auto_apply', 'combo', 'free_delivery')),
  discount_type        text not null default 'percent' check (discount_type in ('percent', 'flat')),
  discount_value       numeric(12, 2) not null default 0 check (discount_value >= 0),
  target_segment       text not null default 'all',
  per_customer_limit   integer not null default 1 check (per_customer_limit >= 0),
  auto_apply           boolean not null default false,
  updated_at           timestamptz not null default now(),
  primary key (organization_id, offer_id)
);
comment on table public.pos_offer_rules is 'Marketing details of an offer in pos_offers (keyed by its device id).';
drop trigger if exists pos_offer_rules_touch on public.pos_offer_rules;
create trigger pos_offer_rules_touch before update on public.pos_offer_rules
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_offer_rules', true);

create table if not exists public.pos_ad_requests (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  title           text not null check (length(btrim(title)) > 0),
  description     text not null default '',
  discount_text   text not null default '',
  placement       text not null default 'home_carousel' check (placement in ('home_carousel', 'offer_strip', 'restaurant_section')),
  banner_url      text,
  status          text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'live', 'ended')),
  review_note     text not null default '',
  impressions     integer not null default 0,
  clicks          integer not null default 0,
  orders          integer not null default 0,
  spend           numeric(12, 2) not null default 0,
  created_by      uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
comment on table public.pos_ad_requests is 'Ad requests for the Proviyaa customer app; reviewed by the Proviyaa team.';
create index if not exists pos_ad_requests_org_idx on public.pos_ad_requests (organization_id, created_at desc);
drop trigger if exists pos_ad_requests_touch on public.pos_ad_requests;
create trigger pos_ad_requests_touch before update on public.pos_ad_requests
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_ad_requests', true);

-- ----------------------------------------------------------------------------
-- Finance (sales and payments are the OS tables orders / payments)
-- ----------------------------------------------------------------------------

create table if not exists public.pos_finance_entries (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  location_id     uuid references public.org_locations (id) on delete set null,
  entry_date      date not null default current_date,
  direction       text not null check (direction in ('in', 'out')),
  kind            text not null default 'other' check (kind in ('cash_register', 'top_up', 'withdrawal', 'capital', 'expense', 'transfer', 'other')),
  account         text not null default 'cash' check (account in ('cash', 'bank', 'upi', 'wallet')),
  category        text not null default '',
  amount          numeric(12, 2) not null check (amount > 0),
  party           text not null default '',
  reference       text not null default '',
  note            text not null default '',
  status          text not null default 'approved' check (status in ('pending', 'approved', 'rejected')),
  created_by      uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
comment on table public.pos_finance_entries is
  'Money in and out outside POS bills: cash register entries, owner top-ups and withdrawals, capital, expenses.';
create index if not exists pos_finance_entries_org_idx on public.pos_finance_entries (organization_id, entry_date desc);
drop trigger if exists pos_finance_entries_touch on public.pos_finance_entries;
create trigger pos_finance_entries_touch before update on public.pos_finance_entries
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_finance_entries', true);

create table if not exists public.pos_expense_heads (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name            text not null check (length(btrim(name)) > 0),
  monthly_budget  numeric(12, 2) not null default 0 check (monthly_budget >= 0),
  active          boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create unique index if not exists pos_expense_heads_name_uq on public.pos_expense_heads (organization_id, lower(name));
drop trigger if exists pos_expense_heads_touch on public.pos_expense_heads;
create trigger pos_expense_heads_touch before update on public.pos_expense_heads
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_expense_heads', true);

create table if not exists public.pos_settlements (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  location_id     uuid references public.org_locations (id) on delete set null,
  settlement_no   text not null,
  source          text not null check (source in ('zomato', 'swiggy', 'online_orders', 'pos_collections', 'upi', 'card', 'cash')),
  amount          numeric(12, 2) not null check (amount > 0),
  utr             text not null default '',
  method          text not null default 'bank_transfer' check (method in ('bank_transfer', 'bank_deposit', 'upi', 'cheque')),
  status          text not null default 'pending' check (status in ('pending', 'completed', 'failed')),
  expected_on     date,
  settled_at      timestamptz,
  note            text not null default '',
  created_by      uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
create unique index if not exists pos_settlements_no_uq on public.pos_settlements (organization_id, settlement_no);
create index if not exists pos_settlements_org_idx on public.pos_settlements (organization_id, created_at desc);
drop trigger if exists pos_settlements_touch on public.pos_settlements;
create trigger pos_settlements_touch before update on public.pos_settlements
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_settlements', true);

create table if not exists public.pos_business_documents (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  location_id     uuid references public.org_locations (id) on delete set null,
  name            text not null check (length(btrim(name)) > 0),
  doc_type        text not null default 'business' check (doc_type in ('tax', 'food_safety', 'business', 'safety', 'liquor', 'environment', 'other')),
  doc_no          text not null default '',
  issue_date      date,
  expiry_date     date,
  file_url        text,
  review_status   text not null default 'verified' check (review_status in ('pending', 'verified')),
  note            text not null default '',
  created_by      uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
create index if not exists pos_business_documents_org_idx on public.pos_business_documents (organization_id, expiry_date);
drop trigger if exists pos_business_documents_touch on public.pos_business_documents;
create trigger pos_business_documents_touch before update on public.pos_business_documents
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_business_documents', true);

-- ----------------------------------------------------------------------------
-- Integrations (Zomato / Swiggy channels themselves are public.channel_integrations)
-- ----------------------------------------------------------------------------

create table if not exists public.pos_integrations (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  provider        text not null,
  category        text not null check (category in ('delivery', 'payments', 'communication', 'ecommerce', 'accounting', 'other')),
  status          text not null default 'pending' check (status in ('pending', 'connected', 'error', 'disconnected')),
  account_ref     text not null default '',
  config          jsonb not null default '{}'::jsonb,
  last_sync_at    timestamptz,
  last_error      text not null default '',
  connected_by    uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
comment on table public.pos_integrations is
  'Third-party apps a restaurant asked to connect. No secrets are stored here; status stays pending until the provider link is live.';
create unique index if not exists pos_integrations_provider_uq on public.pos_integrations (organization_id, provider);
drop trigger if exists pos_integrations_touch on public.pos_integrations;
create trigger pos_integrations_touch before update on public.pos_integrations
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_integrations', true);

create table if not exists public.pos_webhook_endpoints (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  direction       text not null default 'outgoing' check (direction in ('outgoing', 'incoming')),
  name            text not null check (length(btrim(name)) > 0),
  url             text not null default '',
  events          text[] not null default '{}',
  signing_secret  text not null,
  active          boolean not null default true,
  last_tried_at   timestamptz,
  last_status     text not null default '',
  created_by      uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
create index if not exists pos_webhook_endpoints_org_idx on public.pos_webhook_endpoints (organization_id);
drop trigger if exists pos_webhook_endpoints_touch on public.pos_webhook_endpoints;
create trigger pos_webhook_endpoints_touch before update on public.pos_webhook_endpoints
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_webhook_endpoints', true);

create table if not exists public.pos_webhook_deliveries (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  endpoint_id     uuid references public.pos_webhook_endpoints (id) on delete set null,
  event           text not null,
  status          text not null check (status in ('success', 'failed')),
  http_status     integer,
  error           text not null default '',
  duration_ms     integer not null default 0,
  created_at      timestamptz not null default now()
);
create index if not exists pos_webhook_deliveries_org_idx on public.pos_webhook_deliveries (organization_id, created_at desc);
select public.pos_apply_member_rls('public.pos_webhook_deliveries', false);

create table if not exists public.pos_api_keys (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name            text not null check (length(btrim(name)) > 0),
  prefix          text not null,
  key_hash        text not null,
  scopes          text[] not null default '{}',
  expires_at      timestamptz,
  last_used_at    timestamptz,
  revoked_at      timestamptz,
  created_by      uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now()
);
comment on table public.pos_api_keys is 'Partner API keys: only a SHA-256 hash is stored; the key is shown once at creation.';
create unique index if not exists pos_api_keys_hash_uq on public.pos_api_keys (key_hash);
create index if not exists pos_api_keys_org_idx on public.pos_api_keys (organization_id, created_at desc);
select public.pos_apply_member_rls('public.pos_api_keys', false);

create table if not exists public.pos_sync_jobs (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  provider        text not null,
  resource        text not null check (resource in ('menu', 'inventory', 'orders', 'payments', 'customers', 'settlements')),
  mode            text not null default 'delta' check (mode in ('full', 'delta', 'manual', 'pull')),
  direction       text not null default 'inbound' check (direction in ('inbound', 'outbound')),
  status          text not null default 'queued' check (status in ('queued', 'running', 'success', 'failed')),
  attempts        integer not null default 0,
  max_attempts    integer not null default 3,
  duration_ms     integer not null default 0,
  error           text not null default '',
  created_by      uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  finished_at     timestamptz
);
create index if not exists pos_sync_jobs_org_idx on public.pos_sync_jobs (organization_id, created_at desc);
select public.pos_apply_member_rls('public.pos_sync_jobs', true);

-- ----------------------------------------------------------------------------
-- Task Manager
-- ----------------------------------------------------------------------------

create table if not exists public.pos_tasks (
  id                 uuid primary key default gen_random_uuid(),
  organization_id    uuid not null references public.organizations (id) on delete cascade,
  location_id        uuid references public.org_locations (id) on delete set null,
  title              text not null check (length(btrim(title)) > 0),
  description        text not null default '',
  priority           text not null default 'medium' check (priority in ('low', 'medium', 'high')),
  category           text not null default 'operations',
  assignee_staff_id  uuid references public.pos_staff (id) on delete set null,
  assignee_name      text not null default '',
  assignee_role      text not null default '',
  roles              text[] not null default '{}',
  due_date           date,
  cadence            text not null default 'once' check (cadence in ('once', 'daily', 'weekly', 'monthly')),
  photo_required     boolean not null default false,
  checklist_required boolean not null default false,
  approval_required  boolean not null default false,
  video_required     boolean not null default false,
  checklist          jsonb not null default '[]'::jsonb,
  status             text not null default 'assigned' check (status in ('draft', 'assigned', 'in_progress', 'submitted', 'completed', 'failed', 'reassigned')),
  evidence_url       text,
  evidence_note      text not null default '',
  failure_reason     text not null default '',
  corrective_note    text not null default '',
  reviewed_by_name   text not null default '',
  reviewed_at        timestamptz,
  created_by         uuid references public.users (id) on delete set null,
  created_by_name    text not null default '',
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  deleted_at         timestamptz
);
create index if not exists pos_tasks_org_idx on public.pos_tasks (organization_id, due_date);
drop trigger if exists pos_tasks_touch on public.pos_tasks;
create trigger pos_tasks_touch before update on public.pos_tasks
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_tasks', true);

create table if not exists public.pos_task_events (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  task_id         uuid not null references public.pos_tasks (id) on delete cascade,
  event           text not null,
  note            text not null default '',
  actor_name      text not null default '',
  created_by      uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now()
);
-- seq keeps the timeline in insertion order when two events share a timestamp.
alter table public.pos_task_events add column if not exists seq bigint generated by default as identity;
create index if not exists pos_task_events_task_idx on public.pos_task_events (task_id, seq);
select public.pos_apply_member_rls('public.pos_task_events', false);

-- ----------------------------------------------------------------------------
-- Settings
-- ----------------------------------------------------------------------------

create table if not exists public.pos_settings (
  organization_id uuid not null references public.organizations (id) on delete cascade,
  key             text not null check (key in ('outlet', 'bill_format', 'kds', 'updates', 'notifications', 'print_agent')),
  value           jsonb not null default '{}'::jsonb,
  updated_by      uuid references public.users (id) on delete set null,
  updated_at      timestamptz not null default now(),
  primary key (organization_id, key)
);
comment on table public.pos_settings is 'Restaurant panel settings, one JSON document per section.';
drop trigger if exists pos_settings_touch on public.pos_settings;
create trigger pos_settings_touch before update on public.pos_settings
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_settings', false);

create table if not exists public.pos_devices (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  location_id     uuid references public.org_locations (id) on delete set null,
  name            text not null check (length(btrim(name)) > 0),
  device_type     text not null check (device_type in ('kds', 'pos_terminal', 'receipt_printer', 'kot_printer', 'cash_drawer', 'scanner')),
  station         text not null default '',
  ip              text not null default '',
  mac             text not null default '',
  connection      text not null default 'lan' check (connection in ('lan', 'wifi', 'usb', 'bluetooth')),
  firmware        text not null default '',
  model           text not null default '',
  active          boolean not null default true,
  last_seen_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
create index if not exists pos_devices_org_idx on public.pos_devices (organization_id, device_type);
drop trigger if exists pos_devices_touch on public.pos_devices;
create trigger pos_devices_touch before update on public.pos_devices
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_devices', true);

create table if not exists public.pos_printers (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  location_id     uuid references public.org_locations (id) on delete set null,
  name            text not null check (length(btrim(name)) > 0),
  printer_type    text not null default 'receipt' check (printer_type in ('receipt', 'kot', 'label')),
  station         text not null default '',
  connection      text not null default 'lan' check (connection in ('lan', 'usb', 'bluetooth')),
  address         text not null default '',
  paper_mm        integer not null default 80 check (paper_mm in (58, 80)),
  density         integer not null default 8 check (density between 1 and 15),
  copies          integer not null default 1 check (copies between 1 and 5),
  auto_cut        boolean not null default true,
  active          boolean not null default true,
  last_test_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
create index if not exists pos_printers_org_idx on public.pos_printers (organization_id);
drop trigger if exists pos_printers_touch on public.pos_printers;
create trigger pos_printers_touch before update on public.pos_printers
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_printers', true);

create table if not exists public.pos_plan_requests (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  plan_key        text not null,
  plan_name       text not null,
  cycle_months    integer not null check (cycle_months in (1, 3, 6, 12)),
  price           numeric(12, 2) not null check (price >= 0),
  status          text not null default 'requested' check (status in ('requested', 'active', 'cancelled')),
  starts_on       date,
  ends_on         date,
  requested_by    uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
comment on table public.pos_plan_requests is
  'Subscription plans a restaurant chose; the Proviyaa team activates them (no online payment yet).';
create index if not exists pos_plan_requests_org_idx on public.pos_plan_requests (organization_id, created_at desc);
drop trigger if exists pos_plan_requests_touch on public.pos_plan_requests;
create trigger pos_plan_requests_touch before update on public.pos_plan_requests
  for each row execute function public.pos_touch_updated_at();
select public.pos_apply_member_rls('public.pos_plan_requests', false);

-- ----------------------------------------------------------------------------
-- Check: every table above should now be listed with rls = true.
-- select tablename, rowsecurity as rls from pg_tables
--  where schemaname = 'public' and tablename like 'pos\_%' order by 1;
-- ----------------------------------------------------------------------------
