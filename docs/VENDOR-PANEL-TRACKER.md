# Proviyaa Restaurant Vendor Panel: Audit and Implementation Tracker

Scope: **product 2 only**, the Flutter restaurant vendor panel / POS, plus the backend and database it needs.

- Master Admin (React) stays a separate app. It was changed only where the integration required it; see §7.
- The customer ordering app/website is **out of scope** by the owner's instruction (2026-09-29).
- The vendor panel's existing Online Orders inbox is kept as-is.

**Status values:**

| Status | Meaning |
|---|---|
| NOT STARTED | Not started |
| IN PROGRESS | Being worked on |
| BLOCKED | Waiting on something outside this repo (see Blockers) |
| IMPLEMENTED | Code done |
| TESTED | Automated tests pass |
| VERIFIED | Tests pass and the real workflow ran against running servers (`backend/scripts/qa-walkthrough.ts`, the Flutter end-to-end tests) |

Last updated: 2026-09-29.

## 1. Architecture (as built)

```
Flutter vendor panel / POS (lib/)
  presentation → application services → repositories/stores
     ├─ Drift/SQLite (local-first POS data)
     │    └─ CloudSyncService: row-hash diff + sync_row_states, push/pull /v1/sync
     └─ ProviyaaApiClient ─────────────► POS backend (backend/, Node + Hono)
                                            │  auth · roles/screens · tenancy · audit
                                            ▼
                      one Postgres (Supabase), shared with master-admin
Master Admin (master-admin/, React + Express): onboarding, orgs, branches, POS logins
```

**Sync engine decision:** the custom engine is **retained**. PowerSync is not used at runtime; `lib/data/powersync_connector_spike.dart` is a dormant spike.

- The custom engine is proven by `test/backend_end_to_end_test.dart` (two devices through a real backend), `test/sync_and_device_test.dart`, `backend/test/sync.test.ts` and the QA walkthrough's sync pulls.
- There is no competing worker. `SyncWorker` and `pending_upload_intents` are unused in production; see Known limitations.

## 2. Roles and permissions (one contract)

The contract lives in `backend/src/permissions.ts` + `backend/src/access.ts`, mirrored in `lib/domain/access.dart`. The end-to-end test compares the app's copy with the server's, role by role.

A restaurant has **six roles** (owner decision, 2026-09-29): the Owner and the five the restaurant hands out. Special jobs (store keeper, accountant, waiter) are **custom staff roles**: one of these as the base, with fewer screens.

| Role | Key | App | Screens | Franchise | Master | Operations | Staff | CRM | Marketing | Finance | Integrations | Tasks | Settings | Branch-bound | Orders | Take pay | Verify |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Owner | `org_owner` | vendor | 46 | RWD | RWD | RWD | RWD | RWD | RWD | RWD | RWD | RWD | RWD | – | ✓ | ✓ | ✓ |
| Restaurant Admin | `org_admin` | vendor | 46 | RWD | RWD | RWD | RWD | RWD | RWD | RWD | RWD | RWD | RWD | – | ✓ | ✓ | ✓ |
| Branch Manager | `location_manager` | vendor | 25 | – | RWD | RWD | RWD | RWD | – | RW | – | – | – | ✓ | ✓ | ✓ | ✓ |
| Cashier | `biller` | pos | 8 | – | R | RW | – | – | – | – | – | – | – | ✓ | ✓ | ✓ | – |
| Captain | `captain` | pos | 4 | – | R | RW | – | – | – | – | – | – | – | ✓ | ✓ | – | – |
| Kitchen (KOT) | `kitchen` | pos | 1 | – | R | RW | – | – | – | – | – | – | – | ✓ | – | – | – |

- **Branch-bound** means that, with a home branch set (`users.location_id`), the account sees only that branch: lists, records by id, sync and chain views are all fenced.
- **Business sections** (owner decision, 2026-09-30):
  - Task Manager, Customers & CRM, Marketing, Finance, Integrations and Settings are built from the designs in `v1/` (`lib/presentation/business/`, `backend/src/services/{crm,marketing,finance,integrations,tasks,settings}.ts`).
  - Each section is one screen id; its sidebar entries open its pages.
  - The Owner and Restaurant Admin open all six. The Branch Manager opens Customers & CRM and Finance for their branch.
  - Reports, Page Builder and Support have no designs yet: tagged "Soon", they open a "not built yet" page (`lib/presentation/coming_soon_screen.dart`).
- A staff role saved before a screen existed gets that screen from its base role's defaults until an admin edits the role (`screensFor` in `backend/src/access.ts`), so new sections reach existing logins.
- The database and master-admin still accept the older, generic role values. The vendor panel maps them: `manager`, `business_manager` and `operations_manager` work as Branch Manager, and `staff_user` as Captain. Any other old value has no access until an admin assigns one of the six. master-admin is unchanged.

Evidence:
- `docs/qa/QA-WALKTHROUGH-*.md` covers 193 checks. For every role: login, app, exact screens, branch scope and 15 data calls (allowed / 403). It also checks restaurant isolation and sign-out.
- `backend/test/security.test.ts` and `backend/test/staff.test.ts` cover these rules: a Branch Manager creates branch staff but not admins, old roles without access, and cashier vs manager payment verification.
- `test/staff_roles_end_to_end_test.dart` covers the UI for Owner, Cashier, Captain (including taking an order), Kitchen and Branch Manager.

## 3. Feature tracker

| Module / feature | Screen(s) | Roles | Frontend | Backend | DB | Security | Auto tests | Manual/E2E | Blockers / notes |
|---|---|---|---|---|---|---|---|---|---|
| Login, role resolution, landing | login_screen, main | all | TESTED | TESTED | ✓ | server claims only | ✓ | VERIFIED | – |
| Session restore / secure storage | main, session_vault | all | TESTED | – | – | keystore | ✓ | – | – |
| Token refresh / logout revocation | api_client | all | TESTED | TESTED | pos_token_revocations | ✓ | ✓ | VERIFIED (walkthrough) | – |
| Password change / forced change | change_password_dialog | all | TESTED | TESTED | pos_login_security | old sessions ended | ✓ | VERIFIED | – |
| Login lockout / rate limit / enumeration | – | – | – | TESTED | ✓ | ✓ | ✓ | – | limiter is per process |
| Offline session grant (24 h) | main | all | TESTED | – | – | ✓ | ✓ | – | – |
| Device ↔ restaurant binding | main, device_binding | all | TESTED | – | – | prevents cross-tenant leak | ✓ | – | no admin "reset device" UI yet |
| Branch isolation | all | branch-bound | – | TESTED | – | ✓ | ✓ | VERIFIED | – |
| Restaurant (tenant) isolation | all | all | – | TESTED | RLS on pos_* | ✓ | ✓ | VERIFIED | backend connects as owner; isolation enforced in code |
| Staff & Users (12 tabs + training) | presentation/staff | per screen | TESTED | TESTED | 13 tables | screen checks, no escalation | ✓ | VERIFIED | PIN login, video player, file export: see limitations |
| Master: menu, categories | master screens | managers, marketing | TESTED | TESTED | OS tables | ✓ | ✓ | VERIFIED (API CRUD) | demo auto-seed now local-only |
| Master: inventory, suppliers, POs, GRN, recipes | master screens | inventory/procurement | IMPLEMENTED | IMPLEMENTED (mirrored) | pos_* | module-level | partial | VERIFIED (API CRUD) | GRN has no server-side stock posting; sales do not consume stock |
| Operations: orders, KOT, tables | ops screens / POS | floor + managers | TESTED | TESTED | OS tables | branch-fenced | ✓ | VERIFIED (API) | a table with an open order cannot be freed, renamed or deleted |
| POS order flow: new order, add items, follow-up KOT, hold / resume | pos_order_screen, POS home | biller, captain, waiter | TESTED | ✓ (sync) | orders, KOT | kitchen cannot order | ✓ | – | – |
| Cancel / void / quantity cut / discount (with reason, audited) | POS + ops dialogs | managers, biller | TESTED | ✓ | orders.notes audit lines → order notes | reason required in UI | ✓ | – | audit lines live in order notes (no device events table) |
| Payments: cash | POS / ops | biller + managers | TESTED | TESTED | payments | who-may-pay enforced in UI and server | ✓ | VERIFIED | – |
| Payments: card / UPI | POS / ops | recorded by biller + managers; verified by managers, finance, accountant | TESTED | TESTED (pending verification + manual verify) | order_events audit | ✓ | ✓ | VERIFIED (API) | **BLOCKED** for provider verification: no payment provider configured; manual verification only (owner decision needed) |
| Payment buttons by role | POS, ops billing, live ops | captain / waiter / finance see no settle | TESTED | ✓ | – | ✓ | ✓ | – | – |
| Bill preview / reprint | POS + ops | all billing roles | IMPLEMENTED | – | reprint audited | – | ✓ | – | no receipt printer integration; on-screen bill + copy text |
| Takeaway / Delivery (POS) | takeaway/delivery | biller | TESTED | ✓ | deliveries | ✓ | ✓ | – | rider picked from delivery-enabled staff (or typed); no rider app integration |
| All Orders (POS) | all_orders_screen | biller, captain, support | TESTED | – | – | read-only | ✓ | – | "Synced" can be stale until the next upload |
| Online orders inbox | online_orders_screen | biller, support | IMPLEMENTED (unchanged) | IMPLEMENTED | ol_orders | ✓ | ✓ | – | customer ordering app out of scope; status values unconfirmed |
| Dashboard (real KPIs) | restaurant_dashboard_screen | vendor roles | TESTED | ✓ | – | – | ✓ | – | computed on device from real orders, payments, KOTs, stock; wastage / prep time / rating have no data source ("—") |
| Franchise screens (no fake data) | franchise/* | org-wide managers | TESTED | TESTED | pos_franchise_* | org-wide only | ✓ | VERIFIED (API) | reference-data fallback removed; empty states when not connected |
| Reservations / QR (vendor side) | ops screens | managers | IMPLEMENTED | IMPLEMENTED | pos_* | ✓ | partial | VERIFIED (reservation API) | guest QR ordering is customer-side (out of scope) |
| Audit log | staff audit tab | owners, HR | TESTED | TESTED | pos_audit_log | append-only | ✓ | VERIFIED | – |
| Offline POS + sync | CloudSyncService | all | TESTED | TESTED | receipts, stable ids | ✓ | ✓ | VERIFIED (2-device E2E + offline till E2E) | single primary device per branch recommended (V1, D02) |
| Windows build | – | – | – | – | – | – | – | **BLOCKED** | Developer Mode off; VS "Desktop C++" workload missing |
| Android build | – | – | – | – | – | – | – | **BLOCKED** | no Android SDK on this machine |


## 4. Security findings and fixes (this pass)

| Finding | Fix | Test |
|---|---|---|
| Logout did nothing; password change/reset kept old sessions | token revocation list; `sessions_valid_after`; change-password issues a new token | security.test, staff.test, walkthrough |
| Sessions renewable forever | 30-day absolute sign-in lifetime (`auth_time`) | security.test |
| No login rate limit; user enumeration via 423/timing | per-IP / per-email limiter; generic 401 unless the password is right; dummy bcrypt for unknown emails | security.test, staff.test |
| Branch-A user could read/write branch B (header, `?location_id`, by id, via sync) | `branch_scope` in membership; `listBranch`/`assertBranchAccess` on CRUD, mirrored, orders, KOT, summary; sync refuses cross-branch orders | security.test, walkthrough |
| Order takeover across branches through sync (UUID keys) | OrdersAdapter / ownOrder check the branch | security.test |
| HR could reset or suspend admins; admin could take over owner (old `/v1/franchise/staff`) | `assertCanManage`; duplicate staff API removed | security.test, franchise.test |
| Card/UPI/credit counted as paid; paid without payment; overpay; no idempotency; races | pending verification + verify-payment (roles, audited); `paid` only via payments; locked transaction; overpay 422; `Idempotency-Key` | operations.test, walkthrough |
| Client could set prices for menu items | menu items bill at menu price | security.test, walkthrough |
| Kitchen could bill; captains could take money | `canPlaceOrders` / `canTakePayments` over REST and sync | security.test, walkthrough |
| Salary pay / approval decide races | `FOR UPDATE` inside the transaction | staff.test |
| Deletes of shifts/roster/training needed only write | need delete | – |
| Days mixed UTC date with server midnight | branch time zone everywhere | operations/franchise tests |
| Demo seeders ran in live mode and synced into the real tenant; menu auto-seed | seeders local-demo only; auto-seed flag | – |
| Shared device leaked the previous tenant's local data | device binding + wipe / refuse with unsent changes | sync_and_device_test |
| Content-derived change ids dropped A→B→A edits | generation in change id + delete tombstones | sync_and_device_test |
| Idle device re-synced every 3 s | ignore own bookkeeping writes | – |
| Finance "Verify Payment" could never reach the server (no operations upload right) | verification sent to the server by POS order id | operations_flows_test, walkthrough |
| A server-side verification stayed "billed" on devices; a stale device could undo it | paid / cancelled on the server win in sync pull and push | sync.test, walkthrough |
| Web: an older app tab left the shared database on an old schema ("no such table") | schema brought up to date at app start | sync_and_device_test |
| Two devices of one branch could create the same order / KOT / delivery id | device-tagged ids | sync_and_device_test |
| Back-office tables refused by sync (duplicate dining area) | area looked up by name in the branch | sync.test, backend_end_to_end_test |
| Login page blamed the password for any failure; Enter did not submit | server message shown; Enter signs in | – |
| Node keep-alive shorter than client reuse | keepAlive 65 s + GET retry | – |
| master-admin super admin locked out (migration 008 seeded an empty role) | super_admin always gets full permissions | master-admin permission.test |

## 5. Test and build status

See `docs/VENDOR-PANEL-REPORT.md` for exact commands and results.

| Suite | Result (2026-09-29) |
|---|---|
| POS backend (`npx vitest run --maxWorkers=1`) | 113 / 113 (2026-09-30 night: branch-scoped staff dashboard, sign-in cache) |
| master-admin backend (`npx vitest run`) | 49 / 49 |
| `flutter analyze` | no issues |
| `flutter test --concurrency=1` | 337 / 337 (2026-10-01; incl. the end-to-end tests: six roles with first-login password change, captain order, offline till, business sections, every-page real-data tour) |
| Live role walkthrough (six roles) | 193 / 193 checks |
| Restaurant day (all roles, data read back) | 22 / 22 steps |
| Business sections live check (data read back) | 21 / 21 steps |
| Web build | built |
| Windows / Android build | BLOCKED (toolchain missing on this machine) |
