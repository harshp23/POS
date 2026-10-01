# Proviyaa Restaurant Vendor Panel: Completion Report

Date: 2026-09-29. Scope: **product 2**, the Flutter restaurant vendor panel / POS, plus the backend and database it needs.

- Master Admin (React) stays separate. It was changed only where the integration needed it (§7).
- The customer ordering app/website is out of scope by the owner's instruction.
- Live status of every feature: `docs/VENDOR-PANEL-TRACKER.md`.

## 1. Completion summary

The vendor panel is complete for the V1 scope and verified against running servers. What remains is blocked on decisions or on this machine (§10).

- **Sessions and sign-in**
  - Sign-out revokes the token.
  - A password change or an admin reset ends every other session.
  - Sign-ins cannot be renewed past 30 days.
  - Sign-in is rate limited, and it does not reveal which emails exist or which accounts are locked.
  - Offline, a saved sign-in works for 24 hours after the last server contact.
- **Tenancy**
  - A device keeps one restaurant branch's data. Switching restaurants wipes it, and is refused while changes are unsent.
  - Branch logins see only their branch, over REST and through sync.
  - Chain views need an organization-level role.
- **Roles**
  - Six roles: Owner, Restaurant Admin, Branch Manager (one branch), Cashier, Captain and Kitchen (KOT), plus restaurant-defined custom roles for special jobs.
  - Each role opens exactly its screens, and the server enforces the same rules.
  - Every role was signed in and checked on a running backend: 193 of 193 checks.
- **Money**
  - Cash settles the bill.
  - Card, UPI, wallet and due wait until the owner, restaurant admin or branch manager verifies them (audited).
  - Payments are idempotent, overpayment is refused, and menu prices come from the menu.
  - Captains and the kitchen never see a settle button, and the server refuses them too.
- **No fake data in live mode**
  - The dashboard is computed from real orders, payments, KOTs and stock.
  - The chain screens show server data or an honest empty state.
  - Demo seeders run only in local-demo mode.
- **Real data on every screen (2026-09-30)**
  - Screens show names, numbers and words, never a database id, a record key, a raw code or a stored timestamp. Examples: "ORD-248", "KOT #37", "OL-1A2B3C4D", "ABC Foods (archived)", "Bank transfer", "September 2026".
  - Backend messages name the thing ("This customer was not found") and never carry an id.
  - What is recorded is credited to the signed-in person, not a demo name.
  - Anything that already exists is picked from a list: a delivery's order, riders, captains and servers from the staff list, branches, kitchen stations, floors, GST slabs, units, categories, expense heads, customers and bills, tags, menu items and task roles. "Other…" or "+ Add new…" covers the rest.
  - The end-to-end tour checks every page for ids, codes and timestamps (`test/support/visible_text.dart`).
- **POS workflows**
  - New order, follow-up KOT, Save & Hold and resume.
  - Cancel, void, quantity cut and discount, each with a reason and an audit line.
  - Takeaway and delivery queues on real orders.
  - All Orders (read-only, CSV).
  - A live kitchen display that flags cancelled orders.
  - On-screen bill with reprint audit.
- **Staff & Users:** 12 tabs plus training, on 13 new tables. Nobody can grant or manage above their own rights.
- **Business sections (2026-09-30):**
  - Built from the designs in `v1/`: Customers & CRM (`v1/customer`), Marketing (`v1/marketting`), Finance (`v1/fianance`), Integrations (`v1/Integration`), Task Manager (`v1/Task Manager`) and Settings (`v1/settings`).
  - They add 24 new tables and 6 API services. Every screen reads and writes the database through the backend, and every section is fenced by role and by restaurant.
  - Where a design needs an outside service that isn't connected (WhatsApp / SMS sending, Zomato / Swiggy / payment adapters, a local print or KDS agent, an update server, online subscription payment), the screen saves the setup and says plainly that nothing was sent or connected (§12).
  - Reports, Page Builder and Support have no designs yet; each opens a "not built yet" page.
- **Sync:** A → B → A edits are no longer dropped, deletes leave tombstones, the device no longer re-syncs itself every 3 s, and offline shows the real unsent count.

## 2. Role-by-role report

There is one contract: `backend/src/permissions.ts` + `backend/src/access.ts` on the server, mirrored in `lib/domain/access.dart`.

- `test/staff_roles_end_to_end_test.dart` checks that the app's copy matches the server's, screen by screen and role by role.
- The tables below are generated from the server contract (`npx tsx scripts/role-matrix.ts` in `backend/`).
- R/W/D = read / write / delete in each data module. "Branch-bound" = with a home branch set, the account sees only that branch.
- "Screens" is the number of default screens. A restaurant can narrow any role with a custom staff role (base role + subset of screens).

| Role | Key | App | Screens | Franchise | Master | Operations | Staff | CRM | Marketing | Finance | Integrations | Tasks | Settings | Branch-bound | Orders | Take pay | Verify |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Owner | `org_owner` | vendor | 46 | RWD | RWD | RWD | RWD | RWD | RWD | RWD | RWD | RWD | RWD | – | ✓ | ✓ | ✓ |
| Restaurant Admin | `org_admin` | vendor | 46 | RWD | RWD | RWD | RWD | RWD | RWD | RWD | RWD | RWD | RWD | – | ✓ | ✓ | ✓ |
| Branch Manager | `location_manager` | vendor | 25 | – | RWD | RWD | RWD | RWD | – | RW | – | – | – | ✓ | ✓ | ✓ | ✓ |
| Cashier | `biller` | pos | 8 | – | R | RW | – | – | – | – | – | – | – | ✓ | ✓ | ✓ | – |
| Captain | `captain` | pos | 4 | – | R | RW | – | – | – | – | – | – | – | ✓ | ✓ | – | – |
| Kitchen (KOT) | `kitchen` | pos | 1 | – | R | RW | – | – | – | – | – | – | – | ✓ | – | – | – |

**Evidence per role.** The QA walkthrough (`docs/qa/QA-WALKTHROUGH-*.md`) creates one login per role through the Staff API, signs each in, and checks:

- that it resolves to the role;
- that it opens the right app;
- that it gets exactly its role's screens;
- its branch scope;
- 15 data calls, each allowed or refused (403) exactly as the contract says: franchise overview, menu read/write, orders list/create, kitchen queue, cash payment, UPI verification, staff directory, salaries, attendance, roles, login security, audit log, sync pull.

The Flutter end-to-end test signs in through the real login screen as owner, cashier, captain, kitchen and branch manager, and checks the screens each one sees; the captain also takes a table order through the real POS screens.

## 3. Screen-by-screen report

Default screens per role (● = opens by default). The app hides every screen not in `/v1/auth/me.screens`; the staff service checks the screen again on every call, and the data modules check the role's module rights.

| Screen | Id | `org_owner` | `org_admin` | `location_manager` | `biller` | `captain` | `kitchen` |
|---|---|:-:|:-:|:-:|:-:|:-:|:-:|
| Overview · Dashboard | `dashboard` | ● | ● | ● |  |  |  |
| Franchise · Command Center | `franchise.command_center` | ● | ● |  |  |  |  |
| Franchise · Branch Performance | `franchise.branch_performance` | ● | ● |  |  |  |  |
| Franchise · Branch Detail | `franchise.branch_detail` | ● | ● |  |  |  |  |
| Franchise · Inventory & Supply | `franchise.inventory` | ● | ● |  |  |  |  |
| Franchise · Exceptions / Action Centre | `franchise.exceptions` | ● | ● |  |  |  |  |
| Franchise · Targets & Benchmarking | `franchise.targets` | ● | ● |  |  |  |  |
| Franchise · Compliance & Audit | `franchise.compliance` | ● | ● |  |  |  |  |
| Master · Menu Items | `master.menu_items` | ● | ● | ● |  |  |  |
| Master · Products (Online) | `master.products_online` | ● | ● |  |  |  |  |
| Master · Media | `master.media` | ● | ● |  |  |  |  |
| Master · Offers | `master.offers` | ● | ● |  |  |  |  |
| Master · Inventory | `master.inventory` | ● | ● | ● |  |  |  |
| Master · Recipes | `master.recipes` | ● | ● | ● |  |  |  |
| Master · Suppliers | `master.suppliers` | ● | ● | ● |  |  |  |
| Master · Purchase Orders | `master.purchase_orders` | ● | ● | ● |  |  |  |
| Operations · Live Operations | `ops.live` | ● | ● | ● |  |  |  |
| Operations · Captain Orders | `ops.captain_orders` | ● | ● | ● |  |  |  |
| Operations · KOT / Kitchen | `ops.kitchen` | ● | ● | ● |  |  |  |
| Operations · Dine In | `ops.dine_in` | ● | ● | ● |  |  |  |
| Operations · Reservations | `ops.reservations` | ● | ● | ● |  |  |  |
| Operations · POS Billing | `ops.billing` | ● | ● | ● |  |  |  |
| Operations · Delivery | `ops.delivery` | ● | ● | ● |  |  |  |
| Operations · Online Orders | `ops.online_orders` | ● | ● | ● |  |  |  |
| Operations · QR Ordering | `ops.qr_ordering` | ● | ● | ● |  |  |  |
| Staff · Staff Dashboard | `staff.dashboard` | ● | ● | ● |  |  |  |
| Staff · Staff Directory | `staff.directory` | ● | ● | ● |  |  |  |
| Staff · Attendance | `staff.attendance` | ● | ● | ● |  |  |  |
| Staff · Salary | `staff.salary` | ● | ● |  |  |  |  |
| Staff · Advances | `staff.advances` | ● | ● |  |  |  |  |
| Staff · Roles & Permissions | `staff.roles` | ● | ● |  |  |  |  |
| Staff · Shifts & Roster | `staff.shifts` | ● | ● | ● |  |  |  |
| Staff · Login Security | `staff.login_security` | ● | ● | ● |  |  |  |
| Staff · Approvals | `staff.approvals` | ● | ● | ● |  |  |  |
| Staff · Audit Log | `staff.audit_log` | ● | ● |  |  |  |  |
| Staff · Staff Reports | `staff.reports` | ● | ● |  |  |  |  |
| Staff · Training | `staff.training` | ● | ● | ● |  |  |  |
| Business · Task Manager | `task_manager` | ● | ● |  |  |  |  |
| Business · Customers & CRM | `customers` | ● | ● | ● |  |  |  |
| Business · Marketing | `marketing` | ● | ● |  |  |  |  |
| Business · Finance | `finance` | ● | ● | ● |  |  |  |
| Business · Integrations | `integrations` | ● | ● |  |  |  |  |
| Business · Settings | `settings` | ● | ● |  |  |  |  |
| Coming soon · Reports | `reports` | ● | ● | ● |  |  |  |
| Coming soon · Page Builder | `page_builder` | ● | ● |  |  |  |  |
| Coming soon · Support | `support` | ● | ● |  |  |  |  |
| POS · New Order / Billing | `pos.billing` |  |  |  | ● | ● |  |
| POS · Dine In | `pos.dine_in` |  |  |  | ● | ● |  |
| POS · Tables | `pos.tables` |  |  |  | ● | ● |  |
| POS · Takeaway | `pos.takeaway` |  |  |  | ● |  |  |
| POS · Delivery | `pos.delivery` |  |  |  | ● |  |  |
| POS · Online Orders | `pos.online` |  |  |  | ● |  |  |
| POS · All Orders | `pos.all_orders` |  |  |  | ● | ● |  |
| POS · Menu | `pos.menu` |  |  |  | ● |  |  |
| POS · Kitchen Display | `pos.kitchen` |  |  |  |  |  | ● |

**What each screen group does now** (live mode, i.e. signed in to the backend):

| Group | Screens | Data source | Actions | Notes |
|---|---|---|---|---|
| Overview | Dashboard | device DB (orders, payments, KOTs, stock) + staff dashboard API + franchise snapshot | open Action Centre | sales = paid orders only; pending verification shown apart; "—" when no data; branch table only with 2+ branches |
| Franchise | Command Center, Branch Performance, Branch Detail, Inventory & Supply, Exceptions, Targets, Compliance | `/v1/franchise/*` | transfer stock, purchase decisions, raise/resolve exceptions, set targets, raise tasks / log audits, move task status | empty state when not connected; buttons disabled without a repository; success only after the server accepts |
| Master | Menu Items, Products (Online), Media, Offers, Inventory, Recipes, Suppliers, Purchase Orders | device DB ⇄ sync ⇄ OS / `pos_*` tables | full CRUD | demo auto-seed only in local-demo mode |
| Operations | Live Ops, Captain Orders, KOT/Kitchen, Dine In, Reservations, POS Billing, Delivery, Online Orders, QR Ordering | device DB ⇄ sync; online orders via API | orders, KOT, bills, verify payment (verifiers), cancel with reason | settle hidden for roles that may not take money |
| Staff & Users | Dashboard, Directory, Attendance, Salary, Advances, Roles, Shifts & Roster, Login Security, Approvals, Audit Log, Reports, Training | `/v1/staff/*` | per tab | each tab checked by screen on the server |
| POS | New Order, Dine In, Tables, Takeaway, Delivery, Online, All Orders, Menu, Kitchen Display | device DB ⇄ sync | order, KOT, hold/resume, pay (cashier/managers), bill preview | kitchen-only view for chefs; "Payment is taken by the cashier" for captains |

Removed because they were fake or had no backing:
- dashboard multipliers, fake outlets, charts, reviews and campaign buttons;
- the shell's search box, help button and placeholder menu entries (Reports, CRM, Settings…). The nine sections the design's sidebar names (Task Manager, Reports, Page Builder, Customers & CRM, Marketing, Finance, Integrations, Support, Settings) came back on 2026-09-30, by owner decision. Six of them are now built (Task Manager, Customers & CRM, Marketing, Finance, Integrations, Settings); Reports, Page Builder and Support stay tagged "Soon" and open a page saying the section is not built yet;
- the POS top bar's fixed "3" notification badge and dead icons;
- the static takeaway and delivery catalogues;
- the franchise "reference data" fallback.

## 4. Backend endpoints

Base: `/v1/<service>/`. Every route except `/health`, `/v1/auth/login` and `/v1/auth/refresh` needs a bearer token. Full list: `backend/README.md` → API.

| Area | New or changed in this pass |
|---|---|
| Auth | `POST /auth/logout` now revokes the token. `POST /auth/change-password` ends every other session and returns `{ session }`. Refresh stops 30 days after sign-in. Sign-in is rate limited, lockout answers don't reveal it, and unknown emails pay the bcrypt cost. |
| Staff (`/v1/staff`, new, 47 routes) | dashboard, employees, logins (create / role / status / reset / force change), login history, roles (+ seed, catalogue), attendance, shifts, roster + clock in/out, advances, salaries (generate / pay), approvals (decide), self-service `me`, audit log, reports, training. Screen check on every route; nobody can grant or manage above their own rights. Branch-bound managers see their branch's staff only. |
| Operations | `:id` in the order routes also accepts the id a POS device shows (its order key, looked up in the caller's branch). `POST /orders/:id/payments`: locked transaction, `Idempotency-Key`, overpay 422. Cash settles. Card/UPI/wallet/due/other leave the order `awaiting_payment` (pending verification). New `POST /orders/:id/verify-payment` (verifier roles, audited in `order_events`). `POST /orders/:id/status` refuses `paid`. Menu items bill at the menu price. Kitchen cannot place orders; only the cashier and managers take money. |
| Branch fencing | Orders, KOT, summary, generic CRUD and mirrored tables use `listBranch` / `assertBranchAccess`. Sync refuses another branch's orders. Franchise (chain) routes need an organization-level role. |
| Franchise | The duplicate `/franchise/staff` API was removed (it let an admin take over the owner); logins are managed in `/v1/staff/logins`. Periods and targets use the branch's time zone. |
| Audit | Every write to franchise / master / operations is recorded in `pos_audit_log`, and so is every staff action. |
| CRM (`/v1/crm`, new) | Customers linked to their orders by phone (last 10 digits), with spend, points and wallet. Import, segments (12 system + custom rules), loyalty rules and ledger (points credited once per paid bill), wallet ledger (never below zero), feedback, and ideas computed from the restaurant's own sales. |
| Marketing (`/v1/marketing`, new) | Campaigns: draft / schedule / send. A send queues the campaign with its opted-in audience and a note that nothing was delivered. Promotions are the same offers as Master → Offers (`pos_offers`) plus their rules. Ad requests wait for the Proviyaa team. |
| Finance (`/v1/finance`, new) | Dashboard and balances per account, the payments list (POS + online), money in / out entries with approvals, expense heads, settlements (auto-numbered) and business documents with expiry. |
| Integrations (`/v1/integrations`, new) | App connection requests, outgoing webhooks (public HTTPS only, signed test deliveries), API keys (shown once, stored hashed, rotate / revoke), sync-job queue and logs. |
| Tasks (`/v1/tasks`, new) | Tasks with checklist and evidence rules: assign → start → submit → approve or fail → reassign, each step on the task's timeline. |
| Settings (`/v1/settings`, new) | Outlet profile (renames the restaurant), bill format (also the POS bill header), devices, printers, KDS / update / notification preferences, subscription plan requests, system overview and operations centre from live data. |

## 5. Database

One Postgres (Supabase), shared with master-admin. The account table is master-admin's `users`.

**To run by the owner:** `supabase/RUN-IN-SUPABASE.sql`. It is idempotent (`create table if not exists`, `add column if not exists`) and must be re-run because this pass added tables and columns. Nothing was written to the live database by this work.

| Change | Why |
|---|---|
| 13 staff tables: `pos_staff`, `pos_staff_roles`, `pos_staff_attendance`, `pos_staff_shifts`, `pos_staff_roster`, `pos_staff_advances`, `pos_staff_salaries`, `pos_staff_approvals`, `pos_training_modules`, `pos_training_attempts`, `pos_login_security`, `pos_login_events`, `pos_audit_log` | Staff & Users |
| `pos_login_security.staff_role_id` | custom staff role of a login |
| `pos_login_security.sessions_valid_after` | password change / reset ends older sessions |
| `pos_token_revocations` | sign-out revokes the token |
| 24 business tables (`supabase/migrations/20260930_pos_vendor_business.sql`): `pos_customers`, `pos_customer_segments`, `pos_loyalty_settings`, `pos_loyalty_ledger`, `pos_wallet_ledger`, `pos_customer_feedback`, `pos_campaigns`, `pos_offer_rules`, `pos_ad_requests`, `pos_finance_entries`, `pos_expense_heads`, `pos_settlements`, `pos_business_documents`, `pos_integrations`, `pos_webhook_endpoints`, `pos_webhook_deliveries`, `pos_api_keys`, `pos_sync_jobs`, `pos_tasks`, `pos_task_events`, `pos_settings`, `pos_devices`, `pos_printers`, `pos_plan_requests` | Customers & CRM, Marketing, Finance, Integrations, Task Manager, Settings (part 3 of `RUN-IN-SUPABASE.sql`) |

- Every `pos_*` table has RLS enabled with no policies, so the public (anon) key reads nothing.
- The backend connects as the database owner, so tenancy is enforced in code and tested by `backend/test/auth-and-tenancy.test.ts` with a second tenant.

## 6. Sync and offline

- **Engine:** the custom `CloudSyncService`. It diffs row hashes against `sync_row_states` and pushes/pulls `/v1/sync`. PowerSync is not used (dormant spike only).
- **Change ids** include a per-row generation. An edit back to an earlier value (A → B → A) is still sent, and a retry after a network failure keeps its id, so the server de-duplicates it. Accepted deletes leave a tombstone.
- **Final states come from the server:** paid and cancelled decided on the server (a verification, a back-office cancel) are sent to devices as settled / cancelled, and a device that has not synced yet cannot undo them.
- **Device-tagged ids:** orders, KOTs and deliveries made on a device carry its tag (`ORD-E76EE-9981`), so two devices of one branch never create the same id, even offline. Each order records who took it (the signed-in person).
- **Numbers people see (device schema v7):** the server sends each order's number (`display_no`, e.g. `ORD-248`) and each KOT's number (`kot_no`) with the rows it pulls. Every screen shows "KOT #37 · ORD-248", never a database id. The key the sync uses is unchanged, so edits made on a device still reach the same order and ticket. This matters for orders made on the server (online orders, the back office), whose key is a database id. Updating to v7 re-pulls open orders and KOTs once, so rows synced earlier get their numbers.
- **Schema self-repair:** at start the app brings its local database up to date even if an older app tab opened it first (web).
- **Offline status** shows the real number of unsent changes. The sync no longer re-triggers itself on its own bookkeeping writes (previously every 3 s while idle).
- **Device binding:** a device holds one restaurant branch's data.
  - Signing in to another restaurant or branch wipes the local data first.
  - This is refused while the device still has unsent changes of the previous one, so nothing is lost or uploaded into the wrong tenant.
  - Demo seeders run only in local-demo mode, never against a live backend.
- **Offline sign-in:** a saved sign-in keeps working offline for **24 hours after the last server contact**. After that the app locks with an "offline too long" screen until the server can be reached. A token the server revoked sends the user back to sign-in.

## 7. Master-admin integration

- Master-admin creates the restaurant (organization), its branches and the owner login (Partners → restaurant → Restaurant POS accounts). The owner then signs in to the vendor panel with that account; there is one account table and one JWT secret.
- **Fixed:** the super admin was locked out ("Access Restricted") because migration 008 seeded `super_admin` with empty permissions. `super_admin` now always gets full access (`master-admin/backend/src/services/permission.service.ts`, test in `permission.test.ts`).
- master-admin is not changed for roles. It still offers its older, generic role list when creating accounts; the vendor panel maps those values (a "manager" works as Branch Manager, a "waiter" as Captain, and the rest have no access until an admin assigns one of the six).
- Logins created in the vendor panel's Staff screen show up in master-admin's account list (checked by the Flutter end-to-end test).
- Out of scope, not changed: master-admin's partner detail page shows placeholder figures of its own.

## 8. Test report

All runs were on this machine, against the final code (the business-section rows on 2026-09-30).

| Suite | Command | Result |
|---|---|---|
| POS backend typecheck | `cd backend && npx tsc --noEmit` | clean |
| POS backend tests | `cd backend && npx vitest run --maxWorkers=1` | **113 / 113 passed** (7 files: business sections 24, sync 20, auth-and-tenancy 17, staff 17, security 14, operations 12, franchise 9) |
| master-admin backend tests | `cd master-admin/backend && npx vitest run` | **49 / 49 passed** |
| Flutter static analysis | `flutter analyze` | **No issues found** |
| Flutter tests (whole suite) | `flutter test --concurrency=1` | **337 / 337 passed**, 0 skipped (incl. the every-page real-data tour) |
| Live role walkthrough | `cd backend && QA_BASE=http://localhost:8787 QA_OWNER_EMAIL=… QA_OWNER_PASSWORD=… npx tsx scripts/qa-walkthrough.ts` | **193 / 193 checks passed** (six roles): `docs/qa/QA-WALKTHROUGH-20260929182416a1ce.md` |
| Restaurant day (every role does its part; every write read back) | `cd backend && QA_BASE=… QA_OWNER_EMAIL=… QA_OWNER_PASSWORD=… npx tsx scripts/restaurant-day.ts` | **22 / 22 steps passed**: `docs/qa/RESTAURANT-DAY-202609291824ebde.md` |
| Business sections live check (every section's writes read back) | `cd backend && QA_BASE=… QA_OWNER_EMAIL=… QA_OWNER_PASSWORD=… npx tsx scripts/business-day.ts` | **21 / 21 steps passed**: `docs/qa/BUSINESS-DAY-2026093013073426.md` |
| Manual test logins | `npx tsx scripts/manual-test-accounts.ts` | one login per role (5 + a first-login cashier), each signed in and checked (right role, app and screens) |
| Web build | `flutter build web --no-wasm-dry-run --dart-define=PROVIYAA_API_BASE_URL=http://localhost:8787` | built `build/web` |

**The Flutter suite includes two end-to-end tests** that start a real POS backend and master-admin on a local Postgres (PGlite):

- `test/staff_roles_end_to_end_test.dart` (7 tests):
  1. master-admin creates a restaurant, two branches and the owner.
  2. The owner signs in through the real login screen and checks every module. It creates a menu, places an order, pays by UPI (the order is pending verification and not yet counted in sales), verifies the payment, and sees it in sales.
  3. The owner creates a cashier, captain, kitchen and branch manager in the Staff screen.
  4. Each of them signs in, sets their own password on first sign-in, and gets exactly their screens. The branch manager sees no chain views and no payroll.
  5. **The captain takes an order through the real POS screens:** Tables → Start Order at T1 → Paneer Tikka → Send KOT. The pay button reads "Payment is taken by the cashier", and the order with its KOT reaches the server.
  6. master-admin lists every login.
- `test/business_sections_end_to_end_test.dart` (2 tests):
  - The owner signs in on the real login page and, through the UI, adds a customer, creates an offer (also in Master → Offers), records a money entry, assigns a task to a staff member, generates an API key (shown once, stored hashed) and saves the outlet profile. Each write is read back from the server.
  - A branch manager sees Customers & CRM and Finance only, and the server refuses them Marketing.
- `test/backend_end_to_end_test.dart` (4 tests):
  - a restaurant onboarded in master-admin signs in to the POS;
  - two devices of one restaurant stay in step through the backend;
  - **offline POS:** a cashier's till loses the network, takes a cash order and a UPI order, shows them waiting, uploads both when the network returns (cash paid, UPI pending), and shows the UPI settled after the owner verifies it by the POS order id;
  - a back-office table goes occupied → cleaning → available on the device and on the server.

**Areas covered by the Flutter suite:**
- role access contract and screen gating, including the payment buttons per role;
- order lifecycle (20 tests): hold, resume, follow-up KOT, cancel / void / discount with reasons, pending verification, verify;
- POS views: takeaway, delivery, All Orders, dine-in, kitchen display, home panel;
- operations screens and flows;
- dashboard maths (16) and dashboard screen;
- franchise chain screens (23);
- master data screens and flows;
- Staff Management (14);
- sync change ids, device binding and the offline grant;
- sign-in flow, including offline for more than 24 hours and a revoked login;
- multi-tenant isolation.

**Backend security tests** (`backend/test/security.test.ts`, `staff.test.ts`, `auth-and-tenancy.test.ts`):
- sign-out, password change, reset and the 30-day limit;
- rate limit and lockout without enumeration;
- branch isolation: lists, by id, sync takeover, chain views;
- kitchen / captain / cashier / branch manager money rules, menu-price billing, and old role values without access;
- HR and admin escalation attempts;
- cross-tenant reads and writes with a second restaurant.

**Manual pass in the browser (super admin, 2026-09-29).** The built web app was driven by hand as the super admin in Proviyaa QA Kitchen:
- Dashboard, all 8 Franchise / Chain screens (a target set, a compliance task raised and closed), and all 8 Master screens (a dish, a category and a raw material created).
- Operations: Live Orders → New Order; Captain Orders → KOT sent; KOT / Kitchen; POS Billing → cash settle with change; bill preview.

Bugs found by that pass and fixed (each has a test now):

| Bug | Fix |
|---|---|
| First sign-in failed with "no such table: deliveries_table". On the web an older app tab had opened the shared database, and only the first tab runs upgrades. | The app brings its schema up to date at start (`AppDatabase.ensureSchema`); wiping skips missing tables. |
| The login page said "Incorrect password, N attempts remaining" for any failure, and Enter did not submit. | The server's own message is shown (it does the lockout); Enter signs in. |
| A table from the back office was refused by sync: "duplicate key … dining_areas_org_location_name_unique". | Sync reuses the branch's area of that name. |
| Two devices of one branch numbered orders, KOTs and deliveries the same (ORD-9981 on both), so one could overwrite the other on the server. | Ids carry the device's tag (`ORD-3F9A1-9981`); each device counts only its own. |

The browser pane here stalls while the Claude window is hidden, so the rest runs through the widget and end-to-end tests above, which drive the real screens.
- Nothing ran against the live Supabase project (see B4).

## 9. Build report

| Target | Result | Detail |
|---|---|---|
| Web | **Built** | `flutter build web --dart-define=PROVIYAA_API_BASE_URL=…` → `build/web` (75 s). The warning about Cupertino icon fonts comes from the Flutter framework; the app uses no Cupertino icons. |
| Windows | **Blocked (B2)** | `flutter doctor`: Visual Studio 2022 is missing the "Desktop development with C++" workload (MSVC build tools, C++ CMake tools, Windows 10 SDK). Windows Developer Mode is off, and plugins need it for symlinks. |
| Android | **Blocked (B3)** | `flutter doctor`: "Unable to locate Android SDK". |
| POS backend | Runs | `npm run start:local` (local Postgres) or `npm start` with `DATABASE_URL` + `JWT_SECRET`; typecheck clean. |
| master-admin | Runs | API on :8000 and web on :5173, sharing the POS backend's database and `JWT_SECRET`. |

## 10. Blockers (need the owner)

| # | Blocker | What is needed |
|---|---|---|
| B1 | **Card/UPI provider verification.** No payment provider is configured, so card/UPI/wallet payments are verified manually by a verifier role. | Choose a provider (e.g. Razorpay / Paytm / PhonePe) and supply sandbox keys. The verify step is already in place for the webhook to call. |
| B2 | **Windows release build.** | Turn on Windows Developer Mode (plugins need symlinks) and install Visual Studio's "Desktop development with C++" workload. |
| B3 | **Android build.** | Install the Android SDK / Android Studio, then `flutter doctor --android-licenses`. |
| B4 | **Live database schema.** | Run `supabase/RUN-IN-SUPABASE.sql` in the Supabase SQL editor (new staff/session tables and columns). |
| B5 | **Production secrets.** | A strong `JWT_SECRET` shared by both backends, and `DATABASE_URL` set only on the servers. The app never gets them. |

## 11. Release checklist

- [ ] B4: run `supabase/RUN-IN-SUPABASE.sql` on the live project. Then confirm with `node scripts/inspect-db.mjs` in `backend/`: it probes with the public key and should report every `pos_*` table as existing but closed to the public key.
- [ ] Deploy `backend/` with `DATABASE_URL`, `JWT_SECRET` (same as master-admin), `CORS_ORIGINS`; behind HTTPS; one process per host (the rate limiter is in memory).
- [ ] Deploy master-admin with the same `JWT_SECRET`.
- [ ] Build the app with `--dart-define=PROVIYAA_API_BASE_URL=https://<backend>` (web: `flutter build web`; Windows/Android after B2/B3).
- [ ] In master-admin: create the restaurant, its branches and the owner login; sign in to the vendor panel as the owner; seed default staff roles; create staff logins with home branches.
- [ ] Walk each role once on the real backend: `QA_BASE=… QA_OWNER_EMAIL=… QA_OWNER_PASSWORD=… npx tsx scripts/qa-walkthrough.ts` (creates QA logins in that restaurant; use a test restaurant).
- [ ] Decide B1 (payment provider). Until then train verifiers to confirm UPI/card against the statement in POS Billing / Live Operations.
- [ ] One primary POS device per branch (see limitations).

## 12. Known limitations

| # | Limitation | Impact / workaround |
|---|---|---|
| L1 | No payment provider: card / UPI / wallet are verified by hand | verifiers confirm against the bank / UPI statement (B1) |
| L2 | One primary POS device per branch recommended (V1 decision D02) | devices never create clashing ids (device-tagged ids), but two devices editing the same order at once get a conflict for review |
| L3 | `SyncWorker` / `pending_upload_intents` are dormant; `CloudSyncService` is the only sync path | none; kept for its tests |
| L4 | Goods receipts do not post stock on the server; sales do not consume stock | stock is adjusted in Master → Inventory |
| L5 | PowerSync is not used (spike only) | the custom engine is proven by the 2-device end-to-end test |
| L6 | Custom staff roles narrow the screens; data access follows the base role's module rights (except Staff & Users, checked per screen) | give custom roles a base role no stronger than intended |
| L7 | No "reset device" action for admins | a device with unsent changes must sign in to its own restaurant and sync before switching |
| L8 | master-admin's own login does not apply the POS lockout / rate limit | master-admin is an internal tool; protect it at the network level |
| L9 | `ol_orders` status values unconfirmed (customer app is out of scope) | Online Orders inbox unchanged |
| L10 | Rate limiter is in memory per process | run one backend process per host, or add a shared store before scaling out |
| L11 | Order corrections are audit lines in the order's notes (no device events table) | they sync with the order and show in order details |
| L12 | Kitchen tickets show all lines of an order; a follow-up KOT's new items are named in its note | chefs read the note on follow-up tickets |
| L13 | All Orders "Synced" can be stale until the next upload | refused rows show "Needs review" |
| L14 | Wastage %, kitchen prep time and customer rating have no data source | shown as "—" |
| L15 | No receipt printer integration | on-screen bill with copy-text; reprints are audited |
| L16 | Delivery rider is a free-text name; no rider app | – |
| L17 | Staff PIN sign-in, training video player and file export are not built | email + password sign-in; training links; CSV export only |
| L18 | No WhatsApp / SMS / email / push provider is connected | a campaign "sent" is queued with its audience and a note; nothing is delivered |
| L19 | No Zomato / Swiggy / payment / Tally adapter exists | "Connect" records a pending request; sync jobs fail with "not connected"; settlements are recorded by hand |
| L20 | Webhooks: only "Send test" delivers; order / KOT / stock events are not dispatched yet. Inbound webhooks and the partner API that API keys would unlock are not live | keys and endpoints can be prepared now |
| L21 | No local print agent or KDS broadcast engine | printers and KDS settings are saved; "Test print" says nothing was printed |
| L22 | No update server or rollback | Settings → System Update shows the running server version; the web panel updates when reloaded |
| L23 | Subscription plans are requested, not paid | the Proviyaa team activates a plan; no payment is taken |
| L24 | Loyalty points expiry and "max % of bill" are stored, and offer rules (segment, per-customer limit, auto-apply) are saved, but POS billing does not apply them yet | points are earned automatically per paid bill; redemptions are entered in CRM → Loyalty |
| L25 | Refunds are not recorded; the payout wallet screen (`finance-wallet.png`) has no backend | Finance shows ₹0 refunds with a note; the wallet screen was not built |
| L26 | Evidence photos and documents are links (no file upload) | paste a photo / file URL |
