# Proviyaa POS backend

The vendor panel's server. It hosts the Franchise/Chain, Master, Operations and Sync services. It is the **only** component that talks to the database. The Flutter app talks to this backend and holds no database URL, Supabase URL or key.

```
master-admin (React + Express)            Flutter POS / vendor panel (Drift, offline-first)
  platform admins onboard restaurants,       │  HTTPS /v1/...  bearer = master-admin JWT
  branches and POS accounts                  ▼
        │                                  backend/ (this service, Hono)
        ▼                                    │  pg, one pool
   ┌───────────────── the same Postgres (Supabase) ─────────────────┐
   │ master-admin: users, security_roles, organizations, org_locations │
   │ OS tables: menu_items, dining_tables, orders, payments, ol_orders … │
   │ POS: pos_* tables for domains the OS has no table for             │
   └───────────────────────────────────────────────────────────────────┘
```

## Accounts and sign-in

There is one set of accounts: master-admin's `users` table. It uses bcrypt passwords and a JWT `{userId, email}` signed with the shared `JWT_SECRET`, so a token from either backend works in both.

- **Restaurant accounts** have `users.organization_id`, an optional home branch (`location_id`) and a `pos_role` (migration `master-admin/backend/migrations/008`). Platform admins create them in master-admin under **Partners → a restaurant → Restaurant POS accounts**. Owners, admins and HR can also create them from the vendor panel (Staff & Users → Login Security, `/v1/staff/logins`).
- **Platform admins** have `security_roles.key = 'super_admin'` and no organization. They choose which restaurant to open with the `X-Organization-Id` header, and the app shows a restaurant picker. Inside it they act as its owner.
- Suspending an account in master-admin locks it out of the POS at once. Every request re-checks `users.status`.

### Roles and screens

Each account's role decides which **screens** it opens (`src/access.ts`, mirrored in `lib/domain/access.dart`). `GET /v1/auth/me` returns them, the app shows nothing else, and the server checks them again.

- **Six restaurant roles:**
  - **Owner** (`org_owner`) and **Restaurant Admin** (`org_admin`): the whole vendor panel, every branch, including Task Manager, Customers & CRM, Marketing, Finance, Integrations and Settings. Only the owner can change the owner.
  - **Branch Manager** (`location_manager`): one branch. Dashboard, menu and stock, all of Operations, the branch's staff (logins, attendance, shifts, approvals, training), and the branch's Customers & CRM and Finance. Verifies UPI/card. No chain views, no payroll, no marketing, integrations, tasks or settings.
  - **Cashier** (`biller`): POS billing, tables, takeaway, delivery, online, orders and menu. Takes payment.
  - **Captain** (`captain`): new order, tables, dine-in and orders. Cannot take money.
  - **Kitchen (KOT)** (`kitchen`): the kitchen display only.
- **Older role values** that master-admin and the database still accept are mapped: `manager`, `business_manager` and `operations_manager` → Branch Manager, `staff_user` → Captain. Any other old value has no access until an admin assigns one of the six.
- **Staff roles** are the restaurant's own roles, made in Staff → Roles & permissions:
  - "Seed default roles" creates Restaurant Admin, Branch Manager, Cashier, Captain and Kitchen (KOT). Restaurants seeded with the earlier defaults have them renamed.
  - "Create Custom Role" picks one of the six as the base and a subset of the screens that base may have, for example a Store Keeper on Branch Manager with only Inventory.
  - Assigning a staff role to a login sets `users.pos_role` to its base role, which the server enforces for data access. The role's screens decide what the app shows.
- **Nobody can grant more than they have.** Only the owner can create owners. A Branch Manager can create the Cashier, Captain and Kitchen logins for their branch, but not an admin.

### Sign-in security

- Five wrong passwords lock a login for 15 minutes. While locked, and for unknown emails, the answer is the same generic 401 as a wrong password; only the right password on a locked login gets 423. Unknown emails still run a bcrypt compare, so timing does not reveal which emails exist.
- Sign-in is rate limited per IP (100) and per email (20) every 5 minutes, and wrong current passwords on change-password to 5 per 15 minutes. The limiter is in memory, per process.
- Every sign-in (and failure) is recorded in `pos_login_events`.
- An admin can reset a password with "ask to change at next login". The app then makes the staff member choose their own password (`POST /v1/auth/change-password`).
- **Sessions end for real:**
  - `POST /v1/auth/logout` revokes the token (`pos_token_revocations` keeps its SHA-256 until it expires).
  - A password change or an admin reset ends every earlier session (`pos_login_security.sessions_valid_after`). Change-password answers with a new session for the device that made the change.
  - Refreshing never extends a sign-in past 30 days (the `auth_time` claim).
- "Online now" comes from each account's last request.

### Branches

Accounts with a home branch (`users.location_id`) in a branch role (location_manager, biller, captain, kitchen, staff_user, support_user) see **only that branch**. This covers lists, records by id, `?location_id`, `X-Location-Id` and sync. Chain-wide franchise views need an organization-level role.

### Orders and payments

- Menu items are billed at the menu price; a client price is ignored.
- An order becomes `paid` only through payments. `POST /orders/:id/status` refuses `paid`.
- **Cash** settles the order.
- **Every other method** (card, UPI, wallet, due, other) is recorded as pending verification: the order waits in `awaiting_payment` until a verifier confirms the money arrived with `POST /orders/:id/verify-payment`. Verifiers are owners, admins, managers, location managers, finance managers and accountants. Both steps are written to `order_events`.
- There is no payment provider integration yet, so verification is manual.
- Order routes accept the order id or the id a POS device shows (its order key, in the caller's branch). Finance and accountants cannot upload operations changes, so the app sends their verification here directly.
- Paid and cancelled set on the server are final for sync: devices pull them as settled / cancelled, and an older device copy cannot undo them.
- Payments run in one locked transaction. Paying more than the balance is a 422, and an `Idempotency-Key` header makes a retried payment a no-op.
- Kitchen accounts cannot place orders. Only billers and verifiers take payments, so captains and waiters cannot. The same rules apply through sync.

### Tenancy

Tenancy is enforced in code, because the backend's database role bypasses RLS:

- every query is scoped to the caller's organization;
- foreign keys a client sends (branch, material, order…) are checked for ownership;
- upserts refuse to update another organization's row.

Every `pos_*` table also has RLS enabled with no policies, so the public (anon) key cannot read it. `test/auth-and-tenancy.test.ts` attacks all of this with a second tenant.

## One-time database setup

Run **`../supabase/RUN-IN-SUPABASE.sql`** once in the Supabase SQL editor. It is additive and safe to re-run. It contains:

1. master-admin migrations 006–008 (location status/type, the permissions template, and linking users to restaurants). Each is recorded in `_migrations`, so master-admin's own runner skips them later;
2. the POS migration (`migrations/20260928_pos_vendor_backend.sql`):
   - new `pos_*` tables (RLS on, no anon access), including the Staff & Users tables: employees, staff roles, attendance, shifts and roster, advances, salaries, approvals, training, login security and the panel's audit log;
   - a nullable `location_id` (branch) on `orders`, `dining_areas` and `dining_tables`;
3. the business sections migration (`migrations/20260930_pos_vendor_business.sql`, hand-written, additive): 24 new `pos_*` tables for Customers & CRM (customers, segments, loyalty settings and ledger, wallet ledger, feedback), Marketing (campaigns, offer rules, ad requests), Finance (money in/out entries, expense heads, settlements, business documents), Integrations (connection requests, webhook endpoints and deliveries, API keys, sync jobs), Task Manager (tasks, task events) and Settings (settings documents, devices, printers, plan requests). RLS on, no anon access, same shape as the other `pos_*` tables.

To regenerate it after a Drift schema change: `UPDATE_BACKEND_SCHEMA=1 flutter test test/backend_schema_contract_test.dart`, then `npm run db:generate`.

## Run

```bash
npm install
cp .env.example .env        # DATABASE_URL + JWT_SECRET (the same values as master-admin/backend/.env)
npm start                   # http://localhost:8787 against your database
npm run start:local         # local Postgres (PGlite) with the full schema + demo data; never contacts Supabase
npm test                    # integration tests (real SQL, two tenants, master-admin token interop)
npm run typecheck
```

`npm run start:local` seeds two accounts (local only):

| Account | Email | Password |
|---|---|---|
| Platform admin | `superadmin@onlatur.com` | `Proviyaa@2026` |
| Spicy Bistro owner (3 branches) | `admin@spicybistro.com` | `SpicyBistro@2026` |

It prints a `DATABASE_URL`. To run the whole platform locally, start master-admin's backend with that URL and the same `JWT_SECRET` (default `local-development-only-jwt-secret-not-for-production`). The repository README has the steps.

To run master-admin's own test suite against a fresh local database:

```bash
npx tsx scripts/with-local-db.ts -- npm --prefix ../master-admin/backend test
```

Point the app at the backend with `PROVIYAA_API_BASE_URL=http://localhost:8787` in `../.env.local`.

## API

All routes except `/health`, `/v1/auth/login` and `/v1/auth/refresh` need `Authorization: Bearer <token>`.

- `X-Location-Id: <org_locations.id>` picks the branch (optional).
- `X-Organization-Id` picks the restaurant (platform admins only).
- Responses are `{ "data": … }`. Errors are `{ "error": { code, message, details } }`.

| Service | Routes |
|---|---|
| Auth | `POST /v1/auth/login` · `POST /v1/auth/refresh` · `GET /v1/auth/me` (screens, `must_change_password`, and `organizations` for platform admins) · `POST /v1/auth/change-password` (returns `{ session }`) · `POST /v1/auth/logout` (revokes the token) |
| Franchise (organization-level roles only) | `GET/PATCH /organization` · `branches` (CRUD on `org_locations`) · `records`, `targets`, `exceptions` (CRUD) · `POST /exceptions/generate`, `/exceptions/resolve-all` · `GET /overview`, `/branch-performance`, `/inventory`, `/purchase-requirements`, `/materials/:id` · `POST /purchase-orders/:rowId/decision` · `POST /stock-transfers` |
| Master | `menu-categories`, `menu-items`, `menu-item-variants` (CRUD on OS tables) · `offers`, `media-assets`, `suppliers`, `supplier-prices`, `recipes`, `recipe-lines`, `raw-materials`, `purchase-orders`, `purchase-order-lines`, `goods-receipts`, `stock-movements` (`GET`, `GET /:rowId`, `PUT` by device key, `DELETE /:rowId`) |
| Operations | `dining-areas`, `dining-tables`, `kitchen-stations`, `service-requests`, `channels` (CRUD) · `GET/POST /orders`, `GET /orders/:id`, `POST /orders/:id/status`, `POST /orders/:id/payments` (`Idempotency-Key`), `POST /orders/:id/verify-payment` · `GET /kot-tickets`, `POST /kot-tickets/:id/advance` · `GET/POST /online-orders`, `POST /online-orders/:id/status`, `DELETE /online-orders/:id` (cancels) · `GET/PUT /bill-settings` · `GET /summary` · `shifts`, `deliveries`, `reservations`, `qr-codes`, `qr-sessions` |
| Staff | `GET /dashboard` · `employees` (CRUD; create with an app login) · `logins` (list, create, `PATCH` role / status / link / delivery / force-change / 2FA flag, `POST /:userId/reset-password`) · `GET /login-history` · `roles` (CRUD, `POST /roles/seed`, catalogue of screens and base roles) · `GET/PUT /attendance`, `POST /attendance/mark-all-present` · `shifts` (CRUD) · `GET/POST /roster`, `POST /roster/:id/clock-in`, `/clock-out` · `advances` · `GET /salaries`, `POST /salaries/generate`, `PATCH /salaries/:id`, `POST /salaries/:id/pay` · `approvals`, `POST /approvals/:id/decide` · `GET /me`, `POST /me/requests` (staff self-service) · `GET /audit-log` · `GET /reports`, `/reports/:kind` · `training` (CRUD), `POST /training/:id/attempts` |
| CRM (screen `customers`) | `GET /dashboard` · `customers` (list with orders / spend / points / wallet matched by phone, create, `GET/PATCH/DELETE /:id`, `POST /customers/import`) · `segments` (system counts + custom CRUD, `GET /segments/:key/customers`) · `GET/PUT /loyalty`, `GET /loyalty/ledger`, `POST /loyalty/entries` (points are credited automatically for paid bills of known customers, once per bill) · `GET /wallet`, `GET /wallet/ledger`, `POST /wallet/entries` · `feedback` (CRUD) · `GET /ideas` (computed from the restaurant's own sales) |
| Marketing (screen `marketing`) | `GET /dashboard` · `campaigns` (list, create with `action` draft / schedule / send, `PATCH`, `POST /:id/send`, `/:id/cancel`, `DELETE`) — sending queues the campaign with its audience and a note; nothing is delivered until a messaging provider is connected · `GET /audience` · `promotions` (offers in `pos_offers`, shared with Master → Offers and the devices, plus `pos_offer_rules`) · `ads` (requests, reviewed by the Proviyaa team) |
| Finance (screen `finance`) | `GET /dashboard` (balances per account = POS collections by method + entries + completed aggregator settlements) · `GET /payments` (POS payments + online orders, with `summary`) · `entries` (CRUD, `POST /:id/approve`, `/:id/reject`) · `expense-heads` (CRUD), `GET /expenses/summary` · `settlements` (CRUD, numbered STL-YYYYMMDD-NNN), `GET /settlements-summary` · `documents` (CRUD), `GET /documents-summary` |
| Integrations (screen `integrations`) | `GET /overview` · `GET /apps`, `POST /apps/:provider/connect` (records a pending request) and `/disconnect` · `webhooks` (CRUD, https public hosts only; the signing secret is shown once), `POST /webhooks/:id/test` (a real signed delivery), `GET /webhooks/deliveries` · `api-keys` (generate — shown once, stored as SHA-256 — `POST /:id/rotate`, `/:id/revoke`) · `sync-jobs` (queue, `POST /sync-jobs/run`: fails with the reason while no provider adapter exists) · `GET /logs` |
| Tasks (screen `task_manager`) | `tasks` (list by tab with `summary`, create / draft, `GET/PATCH/DELETE /:id`) · `POST /tasks/:id/start`, `/checklist`, `/submit` (evidence rules enforced), `/verify` (approve / fail with a reason), `/reassign` · `GET /assignees` · every step is written to the task's timeline |
| Settings (screen `settings`) | `GET /overview` (checklist, component health, alerts) · `GET /operations-centre` · `GET/PUT /outlet` (also renames the restaurant) · `GET/PUT /bill-format` (also writes `org_bill_settings`, which the POS prints) · `devices`, `printers` (CRUD; `POST /printers/:id/test` answers that nothing can be printed without the local print agent) · `GET/PUT /kds`, `/updates`, `/notifications` · `GET /version` · `GET /subscription`, `POST /subscription/requests` (no payment is taken), `POST /subscription/requests/:id/cancel` |
| Sync | `GET /contract` · `POST /push` · `POST /pull` |

All routes are prefixed with `/v1/<service>/`.

## Sync rules (PRD §6, §9, §10)

- The central id of a device record is derived from (organization, branch, entity, device key), so every push is an idempotent upsert.
- Each change carries a `change_id` and is applied in its own transaction. A retry returns `duplicate`; a reused id with a different payload is `rejected`.
- A stale `base_version` on orders is a `conflict`. Payments are immutable, so a changed payment is a conflict, and orders and payments are never deleted.
- Order numbers come from `next_org_seq()`, and totals and kitchen status are recomputed from the lines and KOTs.
- Pulls use keyset cursors and carry deletions as tombstones. Branch data stays in its branch; the chain catalogue (menu, offers, recipes, suppliers) is shared.
