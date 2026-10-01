# Proviyaa POS — Development Journal

## 2026-10-01 — Proviyaa POS: a narrated client demo video of the vendor panel

**A 2 min 51 s, 1080p walkthrough of how a restaurant runs on the vendor panel, built with HyperFrames from real screenshots of the local platform: `demo-video/vendor-panel-demo/renders/vendor-panel-demo.mp4` (83 MB; `-small.mp4` is the share-friendly copy).**

- **Thirteen steps**, each narrated and captioned: onboard in Proviyaa master (partners, partner detail, branches + POS logins) → owner signs in → menu with photos → stock, recipes, suppliers → floor plan and reservations → KOT → billing → live orders, delivery, online → works offline (a bill settled with the API blocked, then synced) → chain view → staff and roles → each role's own panel (branch manager, cashier POS, kitchen display) → CRM, finance, tasks, integrations. Intro and outro cards.
- **How it is made** (`demo-video/README.md`): `capture.cjs` drives the running apps headlessly (Puppeteer; master-admin at :5173, the Flutter web build at :8642) and takes 34 screenshots as the Latur Spice House owner, a branch manager, a cashier and a kitchen login; `tts.ps1` speaks `narration.json` with the Windows voice; `build.cjs` times the scenes from the WAV lengths and writes the HyperFrames composition (dark-green brand frame, slow pan down each screenshot, crossfades, progress bar); `hyperframes render` makes the MP4. Everything is local; no live data.
- **Found on the way:** the master-admin headless sign-in silently stayed on the login page when the submit button was clicked; typing and pressing Enter, then waiting for the URL to leave `/login`, works. The first cut cropped the 16:10 screenshots to the top two thirds; the pan now reveals the whole screen.
- **Not in the video:** nothing was changed in the product for it. Re-record after UI changes by re-running the pipeline.

## 2026-09-30 (night, later) — Proviyaa POS: offline proven, a second branch, and the whole restaurant filled and exercised

**Latur Spice House got a second branch from Proviyaa master, a full menu with generated photos, recipes, suppliers, stock, purchase orders, offers, orders in every channel at both branches, chain targets and transfers, staff with logins in each branch, tasks, integrations and finance — through the platform's own APIs with every write read back (167 / 167), then walked through in the app as the owner and as the Ausa Road branch manager. The POS took a bill with the server stopped and synced it when the server came back.**

- **Offline:** POS Billing kept working with the backend process stopped ("Offline · 5 waiting"); the ₹126 cash bill reached the database on Sync. The same path against the live Supabase project is untested: `backend/.env` has no `DATABASE_URL`, and nothing is written to the live project without the owner's go-ahead.
- **Second branch:** added in master; the owner's next sign-in saw it. Two fixes on the way: sign-in now clears the backend's 30 s branch cache, and an account without a home branch acts for the oldest branch (not the first by name) while a device keeps the branch it was set up for whenever the account may act for it (`context.ts`, `routes/auth.ts`, `main.dart`, `VendorAccount.actingFor`).
- **Branch admin:** signed in as each branch manager (API) and as Ausa Road's manager (app): one branch, only their staff, orders and tables; the other branch's orders and the chain screens refused. Fixed: the Staff dashboard counted the whole restaurant for a branch manager; it now counts the branch (`staff.ts`, test added).
- **Tooling:** `backend/scripts/latur-full.ts` (the fill-and-check pass, idempotent), `scripts/gen-dish-images.ps1` (placeholder photos via System.Drawing), `scripts/serve-media.cjs` + the `qa-media` preview (:8643, CORS) so the web build can draw them. Report: `docs/qa/LATUR-SPICE-HOUSE-FULL-RUN-20260930.md`.
- **Verified:** backend 113 tests; Flutter analyze clean; web rebuilt; `business-day.ts` 21 / 21 for this restaurant.
- **Left undone:** `restaurant-day.ts` assumes a fresh restaurant and stopped at its captain step; the offline → live-Supabase run needs the connection string.

## 2026-09-30 (late) — Proviyaa POS: a new restaurant from Proviyaa master to every role, in the browser

**Latur Spice House was created in Proviyaa master (restaurant, branch, owner login), then run from the vendor panel by its owner and five staff logins, all through the two web apps. Every step was read back from the shared local database.**

- **Setup:** Proviyaa master (`:5173`/`:8000`) and the POS backend (`:8787`) share the one local Postgres (PGlite) and the JWT secret in their `.env` files; the live Supabase project was not touched. Logins are in the git-ignored `backend/.data/laturspice-accounts.txt`. Report: `docs/qa/NEW-RESTAURANT-ONBOARDING-20260930.md`.
- **What was exercised:** master Add Partner → Add Location → Create POS Login; owner sign-in with forced password change; Master (category + dish add/edit, every master page); all seven Franchise / Chain pages; Dine In (two tables, edit seats, reserve, seat, order, KOT, cooking → ready); POS Billing (takeaway cash bill; table bill by UPI → pending verification → verified by the Branch Manager); Staff & Users (seed roles, create logins); sign-in as Restaurant Admin, Branch Manager, Cashier, Captain and Kitchen, each landing on the right panel with the right screens.
- **Guards seen working:** the device refused to switch restaurants while it held an unsent change; a UPI bill stays "pending verification" until a manager verifies it; a new login must set its own password.
- **Fixed on the way:**
  - The Menu Catalog list did not refresh after Add / Edit on web (the save was in the database). The screen now re-reads when the editor closes and recovers if its stream fails.
  - The demo "Load Spicy Bistro Catalog" button showed for a live restaurant; it is local-demo only now.
  - Chain pages showed the figures fetched at sign-in; opening a chain page fetches them again.
- **Left undone:** Delivery / Online / QR flows, suppliers, purchase orders, recipes and offers were not given records for this restaurant.

## 2026-09-30 (night) — Proviyaa POS: real data and pickers across the vendor panel

**The owner asked that every screen show real data, with dropdowns wherever a value already exists in the system. An audit of all screens found ids, internal codes, placeholder names and free-text references. They are fixed across Operations/POS, Master, Staff & Franchise, the six business sections and the backend.**

- **What people saw before:**
  - Record keys in titles and tables: delivery ids, `ol:<uuid>` online orders, supplier ids, `OFF-…` campaign ids, GRN timestamps.
  - Raw codes: `wrong_password`, `half_day`, `upi`, `2026-09`, `order.created`.
  - Placeholder people and places: "Rahul Sharma" on every order and PO, "Central Kitchen (Basement 1)", "Burger Express" in the sidebar.
  - Raw exception text in error messages.
- **Structural decisions:**
  - Keys stay keys. Screens look up the name or number: an order's number, a KOT's number, a supplier's name (archived ones read "Name (archived)"), a branch's name.
  - A reference is picked, never typed:
    - a delivery's order (open orders by number · customer · total)
    - riders (staff with delivery enabled), captains and servers
    - merchant and platform; kitchen station; floor; GST slab; unit (locked to the material's unit)
    - material and supplier categories; payment terms; expense head; customer and bill in feedback; tags; linked menu items
    - branch in staff, logins, customers, tasks, finance, devices and printers
    - task roles from the restaurant's own roles
  - Free text stays where it is really free: names, notes, addresses. Other values are always available, as "Other…" or "+ Add new…".
  - Backend messages name things ("This customer was not found", "An order that is in the kitchen cannot be marked paid") and never carry an id or a status code.
- **Backend:**
  - Staff and login lists carry `location_name`.
  - Campaigns and offers carry their segment's name ("Deleted segment" when gone).
  - Online payments show `OL-XXXXXXXX` and the customer's name.
  - Import errors name the field; ideas name the channel ("Dine-in").
  - Incidents name the app; audit rows name the staff member they are about.
- **App:**
  - Orders and stock records are credited to the signed-in person: a server sign-in no longer overwrites the actor with the demo name, and POs record who created them.
  - A shared test check, `test/support/visible_text.dart`, fails a page that shows a database id, a raw code or a stored timestamp. The end-to-end tour runs it on every page, now with more server-made records: a UPI salary advance, an expense, and a campaign whose customer group was deleted.
- **Verified:**
  - Backend: 113 tests tests, including branch names on staff and logins, segment names, online payment numbers, and not-found messages without ids.
  - Flutter: analyze is clean; the whole suite passes (337 tests), including the real-data tour.
  - Live business-sections check: 21 / 21 (`docs/qa/BUSINESS-DAY-2026093013073426.md`).
- **Left undone:**
  - Rider, captain and server names are still stored as text on the order or delivery; the picker only fills them.
  - Menu channel names are not rewritten in stored items, because per-channel prices are keyed by the old names.
  - GRN numbers are per device, like PO numbers.
  - The backend sends no unit for franchise purchase requirements yet, so those quantities show without one.

## 2026-09-30 (evening) — Proviyaa POS: real KOT and order numbers on every screen

**The owner saw database ids ("252cdf22-2192-…", "Order #5e2f888f-…") on the KOT screen. Kitchen, KDS, live operations, billing, dine-in, delivery and all-orders screens now show the numbers people use: "KOT #246 · ORD-249".**

- **Cause:** orders and KOTs created on the server (online orders, back-office REST calls, the QA scripts) have no device key, so the sync used their database id as the key, and the screens printed the key.
- **Decision:** keep the key and add display fields, instead of replacing the key with a readable one. The sync resolves a device key to the server row directly: a UUID key is the row id; any other key is hashed. A readable key would therefore have created duplicate orders on the next edit.
  - Device schema v7 adds `orders.display_no` and `kitchen_tickets.kot_no`. The server fills them on pull and ignores them on push.
  - `OpsOrder.number` and `OpsKot.label` are used in 41 places. A database id is never printed; it falls back to "Order 5E2F88" until the number arrives.
  - The v7 upgrade clears the orders and KOT sync cursors, so the next sync re-pulls open orders and the last 36 hours with their numbers. The cursor reset is guarded for databases older than the settings table.
- **Verified:**
  - Backend: 112 tests, including a new one that a server-made order and KOT pull with their numbers.
  - Flutter: analyze is clean, and the whole suite passes (336 tests), including a new test for the labels and the kitchen card; the flow tests were updated to the new labels.
  - In the browser: the tickets from the owner's screenshot show "KOT #246 · ORD-249". "Start Cooking" moved that same ticket to preparing on the server, with no duplicate KOT.

## 2026-09-30 (later) — Proviyaa POS: Customers & CRM, Marketing, Finance, Integrations, Task Manager and Settings

**The six sections the owner sent designs for (38 screens in `v1/`) are built end to end: 24 new tables, 6 API services and their Flutter screens. Every screen reads and writes the database, and nothing pretends to reach a service that isn't connected.**

- **Structural decisions:**
  - One additive migration (`supabase/migrations/20260930_pos_vendor_business.sql`, part 3 of `RUN-IN-SUPABASE.sql`). It is RLS-on like every `pos_*` table; the local database applies it at startup.
  - New permission modules: crm and finance for owners and branch managers (a branch manager sees their branch); marketing, integrations, tasks and settings for owners only.
  - Each section is one screen id, and its sidebar entries are pages within it, as in the design.
  - Customers are linked to their orders by phone (last 10 digits), so one profile covers POS, QR and online. Loyalty points are credited once per paid bill (a unique index guards it).
  - Promotions are Master → Offers' own table (`pos_offers`), so the offer reaches the devices through sync; marketing-only rules sit beside it (`pos_offer_rules`).
  - **Honesty where there is no service behind a design:**
    - Campaigns queue with their audience and say nothing was delivered.
    - Connecting an app records a pending request.
    - Sync jobs fail with "not connected".
    - Test prints say nothing printed.
    - Plan choices are requests, and no payment is taken.
    - There is no fake update, rollback or uptime data.
  - Webhooks accept public https hosts only, and deliveries are signed. API keys are shown once and stored as SHA-256.
- **Built in parallel:** three agents wrote the Flutter screens (2 sections each) against the tested API. The main session wired the shell, the routing and access, reviewed the code, fixed a reload bug their tests exposed, and ran all checks.
- **Verified:**
  - Backend: 111 tests, 24 of them new ones that write and read back every section and check the role fences.
  - Flutter: analyze is clean. The whole suite passes (334 / 334), including a new end-to-end test in which the owner uses every section through the real login page and a branch manager sees only theirs.
  - Live check on the running server (`scripts/business-day.ts`): 21 of 21 steps.
  - Checked in the browser as the owner.
- **Not built** (no backend or would need fake numbers): the payout wallet screen, AI copy / banner generation, file uploads, chart types beyond bars, and the design's uptime / memory / changelog figures. They are listed in `VENDOR-PANEL-REPORT.md` §12 (L18–L26).

## 2026-09-30 — Proviyaa POS: the design's full sidebar, with "Soon" sections

**The vendor panel's sidebar now has every section in the Figma design. The nine that aren't built yet (Task Manager, Reports, Page Builder, Customers & CRM, Marketing, Finance, Integrations, Support, Settings) are tagged "Soon" and open a page that says so.**

- **Why:** The owner asked where the design's other sidebar options were. They had been taken out earlier because they opened nothing. The owner chose to show all nine now as placeholders and will provide their screens later.
- **Structural decisions:**
  - The nine are real screens in the role contract (group "Coming soon", in both `backend/src/access.ts` and `lib/domain/access.dart`), so the server decides who sees them.
  - The Owner and Restaurant Admin see all nine. The Branch Manager sees Reports, Customers & CRM and Finance for their branch. The rest cover the whole restaurant, so they are for the owners only, like the chain views. Cashier, Captain and Kitchen see none.
  - The placeholder page (`lib/presentation/coming_soon_screen.dart`) shows no figures and saves nothing. Page Builder lists the sub-pages the design names (App Overview … Subscription).
  - **Existing roles get new screens:** a staff role's screen list is stored when it's saved. Screens now record when they were added, and a role last saved before then gets them from its base role's defaults until an admin edits the role. Without this, every existing Branch Manager and Restaurant Admin login would have missed the new sections.
  - A backend sync test used fixed dates, and the server hands devices only the last 36 hours of orders, so it began failing once the calendar moved on. Its times are now relative to the moment the test runs.
- **Verified:**
  - Backend: 87 tests.
  - Flutter: the whole suite passes (332 tests), including the new sidebar and placeholder tests and both end-to-end files. The Branch Manager test now expects the three branch sections and not Settings.
  - On the running server: the Owner and Restaurant Admin get 46 screens, the Branch Manager 25, and the Cashier, Captain and Kitchen are unchanged at 8, 4 and 1.
  - Checked in the browser as the owner.
- **Next:** replace each placeholder when its screens arrive in the `v1/` folder.

## 2026-09-29 (night) — Proviyaa POS: six restaurant roles instead of nineteen

**The vendor panel now has the roles a restaurant actually has: Owner, Restaurant Admin, Branch Manager (one branch), and the branch's Cashier, Captain and Kitchen (KOT). The nineteen generic roles are gone from the vendor panel; special jobs are custom roles.**

- **Why:** The owner found nineteen roles confusing. They came from the generic Proviyaa OS roles table and an earlier brief to validate every one of them, not from how a restaurant works. The Figma design (Roles & permissions seeds Administrator, Biller, Captain, Chef, Waiter) and the product documents (Owner, Manager, Cashier, Restaurant Manager, Kitchen staff) agree with the owner's model.
- **Structural decisions:**
  - Six roles, one contract (`backend/src/permissions.ts`, `backend/src/access.ts`, `lib/domain/access.dart`).
  - Only the owner, the restaurant admin and the branch manager verify UPI/card. The cashier takes money; the captain and the kitchen don't.
  - A Branch Manager can create the cashier, captain and kitchen logins for their branch, but not an admin.
  - master-admin is not changed, at the owner's instruction; the vendor panel maps the older role values that the database and master-admin still accept:
    - manager → Branch Manager;
    - waiter → Captain;
    - any other old value has no access until an admin assigns one of the six.
  - Restaurants seeded with the earlier default roles have them renamed on the next seed (Administrator → Restaurant Admin, Manager → Branch Manager, Biller → Cashier, Chef → Kitchen (KOT)).
  - The finance-only "verify on the server" path in the app was removed; no role needs it now.
- **Verified:**
  - POS backend: 85 tests.
  - Flutter: analyze is clean. The full suite passes, including the staff and operations tests and both end-to-end files (owner, cashier, a captain taking an order, kitchen, branch manager, master-admin onboarding, offline till).
  - Live walkthrough of the six roles: 193 of 193 checks. Restaurant day: 22 of 22 steps.
  - master-admin untouched: 49 tests.
- **Open question for the founder:** should branch managers be able to edit the shared menu (it applies to every branch), or only mark items unavailable for their branch?

## 2026-09-29 (later) — Proviyaa POS: vendor panel hardened, real data everywhere, every role checked

**The restaurant vendor panel was audited end to end and completed: sessions end for real, a branch login sees only its branch, card/UPI money waits for verification, only cashiers and managers take money, the dashboard and chain screens show only real data, and the POS order flow (hold, resume, follow-up KOT, cancel with a reason, takeaway, delivery) works on real orders. Every one of the 19 roles was signed in and checked against a running backend.**

- **Why:** The owner's brief asked for a complete, production-safe vendor panel with no fake data, every role validated, and offline work that cannot leak between restaurants. Scope is product 2 only (vendor panel + its backend); the customer ordering app is out of scope by the owner's instruction.
- **Structural decisions:**
  - **Card / UPI / wallet / due are "pending verification"** until a verifier confirms the money arrived (`POST /orders/:id/verify-payment`, audited). No payment provider is configured, so verification is manual for now. Cash settles at once.
  - **Who handles money:** the cashier and managers take payments. Finance and accountants verify (reconciliation) but do not bill. Captains, waiters, kitchen and support staff never see a payment button, and the server refuses them too, including through sync.
  - **Branch roles are fenced to their branch** when the login has a home branch: lists, records by id, sync and chain views.
  - **Sessions:** logout revokes the token, a password change or reset ends every other session, sign-ins cannot be refreshed past 30 days, and sign-in is rate limited without revealing which emails exist.
  - **A device holds one restaurant branch's data.** Signing in to another wipes it first, and that is refused while unsent changes remain. A saved sign-in works offline for 24 hours after the last server contact.
  - **Order corrections are audited in the order's notes** as structured lines (who, when, what, why). They sync with the order; there is no separate device events table.
  - The duplicate `/v1/franchise/staff` API was removed; logins are managed only through Staff & Users.
- **What works now:**
  - Dashboard computed from the device's real orders, payments, KOTs and stock (sales count only paid orders; pending verification shown apart), with "—" where there is not enough data.
  - Chain screens (command center, performance, branch detail, inventory, exceptions, targets, compliance) with no reference-data fallback; actions report success only after the server accepts them.
  - POS: new order, follow-up KOT for added items, Save & Hold and resume, cancel/void/quantity cut/discount with a reason, takeaway and delivery queues on real orders, a read-only All Orders view with CSV export, a live kitchen display that flags cancelled orders, and an on-screen bill with reprint audit.
  - Sync: an edit back to an earlier value is no longer dropped, deletes leave tombstones, and the offline banner shows the real number of unsent changes.
  - master-admin: the super admin is no longer locked out, and it offers all 19 POS roles.
- **Verified:** full commands in `docs/VENDOR-PANEL-REPORT.md` §8.
  - POS backend: 84 tests, typecheck clean. New security tests cover sessions, branch isolation, money rules and escalation.
  - master-admin backend: 49 tests.
  - App: `flutter analyze` clean; 332 tests pass. That includes the end-to-end test through the real login page, where the owner verifies a UPI payment and a waiter is refused payments.
  - Live walkthrough against a running backend: 484 of 484 checks. It covers all 19 roles (login, app, exact screens, branch scope, 15 data calls each), restaurant isolation, sign-out, and owner CRUD in every module.
  - Web build succeeds.
- **Found while preparing the manual test pass:**
  - Finance and accountant accounts saw "Verify Payment", but the app saved the verification on the device, and those roles cannot upload operations changes. Their verification now goes straight to the server (by the order id the POS shows), and the settled order comes back with the next sync.
  - A payment verified on the server stayed "billed" on the devices, because sync resent the device's last status. Paid and cancelled decided on the server now win in sync, and a device that has not synced yet cannot undo them.
  - `backend/scripts/manual-test-accounts.ts` makes one login per role for testing by hand (passwords only in a git-ignored file); `docs/MANUAL-TEST-GUIDE.md` lists what each should see.
- **Found by driving the web app by hand as the super admin, and fixed:**
  - First sign-in on the web failed ("no such table: deliveries_table"): only the first browser tab upgrades the shared database, and an old tab had opened it. The app now upgrades its own schema at start.
  - Two devices of one branch numbered orders the same way (ORD-9981 on both), so the server could merge two different orders. Ids now carry the device's tag.
  - Sync refused tables made in the back office (duplicate dining area).
  - The login page blamed the password for every failure, and Enter did not sign in.
- **New end-to-end proof:** a cashier's till billing offline and catching up; the captain taking a table order through the real POS screens; and `backend/scripts/restaurant-day.ts` (22 steps), where every role does its part and every write is read back through the API.
- **Not verified yet:**
  - The live Supabase project: `supabase/RUN-IN-SUPABASE.sql` must be run again for the new session tables and columns.
  - Windows and Android builds: this machine lacks Developer Mode + the VS C++ workload, and the Android SDK.
- **Open questions for the founder:**
  - Which payment provider (Razorpay, Paytm, PhonePe…) should verify card/UPI automatically? Until then verifiers confirm payments by hand.
  - Should delivery staff be allowed to collect cash on delivery? Today only cashiers and managers take money.
  - One primary POS device per branch is still the V1 rule. Is multi-terminal needed for launch?

## 2026-09-29 — Proviyaa POS: Staff & Users, and every role gets its own screens

**The vendor panel now has Staff & Users, built from the 21 designs in `v1/staff managment/`. Every login's role decides exactly which screens the app opens: owners get the whole panel, managers get operations without payroll, a cashier gets POS billing, and the kitchen gets only the kitchen display. The server enforces the same rules.**

- **Why:** Restaurants must create their own staff logins and control what each person can do. The product documents define the actors (Owner = full control, Manager = operations, Cashier = POS only, Inventory/Purchase/Pricing managers = their areas, Kitchen = KOT). Until now every login saw every screen.
- **Structural decisions:**
  - **One screen catalogue** (`backend/src/access.ts` ⇄ `lib/domain/access.dart`; the end-to-end test checks they match).
    - Each of the 19 built-in roles has default screens.
    - `/v1/auth/me` returns the account's screens. The app hides everything else; the server checks again.
  - **Staff roles** are the restaurant's own roles (Roles & permissions):
    - "Seed default roles" gives Administrator, Manager, Biller, Captain, Chef, Waiter, Delivery Boy and Order Acceptance App.
    - Custom roles are a built-in base role plus a subset of the screens that base may have. The base role is what the server enforces for data.
    - Nobody can grant a role with more rights or screens than they hold; only the owner can create owners.
  - **Staff records vs logins.** Employees (HR profile, bank details, pay terms) are `pos_staff` rows; app logins stay master-admin `users`, linked by `pos_staff.user_id`. So master-admin lists every login a restaurant creates.
  - **13 new tables** (RLS on, no anon access), in the same one-time SQL file: staff, roles, attendance, shifts, roster, advances, salaries, approvals, training modules/attempts, login security, login events, audit log.
- **What works now:**
  - **Staff Management**, with all 12 tabs:
    - dashboard, directory (add/edit with an optional app login), attendance (mark all present)
    - salary (generated from attendance, overtime, incentives and advances; pay and partial pay), advances
    - roles & permissions (staff access list and role catalogue), shifts & roster (clock in/out, late/overtime flags)
    - login security (failed attempts, reset, forced change, login history), approvals (leave and advance requests; approving leave marks attendance, approving an advance records it)
    - audit log (every panel change in every module), reports (CSV export)
    - training (modules, MCQ tests, progress)
  - **Sign-in security:** 5 wrong passwords lock a login for 15 minutes. A reset or new login makes the person pick their own password at first sign-in.
  - **Role-shaped app:**
    - vendor sidebar filtered by screen; POS sidebar filtered by module; a kitchen-only view for chefs
    - a lock screen for anything outside the role
    - the restaurant's real name in the sidebar
- **Bugs found and fixed on the way:**
  - "Today" in summaries, chain analytics and targets mixed the UTC date with server-local midnight, so orders between 00:00 and 05:30 IST dropped out of the day. Restaurant days now follow the branch's time zone.
  - The device re-synced every 3 seconds while idle: it reacted to its own bookkeeping writes.
  - Node closed idle connections after 5 s while the app reused them for 15 s, so a request could fail with "cannot reach server". Keep-alive is now 65 s, and reads retry once on a dropped connection.
  - End-to-end tests left backend processes running on Windows (the wrapper was killed before its process tree).
- **Verified:**
  - POS backend: 69 tests, including 14 staff tests (escalation attempts, cross-tenant access, salary maths, lockout).
  - master-admin: 48 backend + 36 frontend tests, and the build.
  - App: `flutter analyze` clean and the whole suite passing, including the Staff Management widget tests and a new end-to-end test through the real login page:
    1. master-admin creates a test restaurant, two branches and an owner;
    2. the owner signs in, checks every module, and adds a cashier, a captain, a chef and a manager in the Staff screen;
    3. each of them signs in, sets their own password, and gets exactly their screens;
    4. master-admin lists all of them.
- **Not verified yet:** against the live Supabase project. `supabase/RUN-IN-SUPABASE.sql` must be run again for the 13 new tables; it is safe to re-run.
- **Open questions for the founder:**
  - Should POS staff also get quick PIN sign-in on a shared terminal (the "User code / PIN" column in the designs)? Today every login uses email and password.
  - Training videos: which player or hosting? The app shows the chapters and links but has no video player.
  - The `ol_orders` status values are still unconfirmed.

## 2026-09-28 (later) — Proviyaa POS: master-admin merged in, one login for the whole platform

**master-admin (github.com/proviaa-master/master-admin) now lives in `master-admin/`. Its accounts are the POS's accounts: a restaurant a platform admin onboards there signs in to the POS with the same email and password. There is one database and one JWT.**

- **Why:** The first backend signed people in with Supabase Auth and the OS's `org_users`. master-admin already owns identity (`users`, bcrypt, its own JWT), so the platform would have ended up with two logins and two account lists.
- **Structural decisions:**
  - The POS backend verifies and issues master-admin's JWT `{userId, email}` with the shared `JWT_SECRET`, so tokens from either backend work in both.
  - Restaurant accounts are `users` rows with `organization_id`, an optional home branch `location_id`, and a `pos_role` (master-admin migration 008).
  - Platform admins (`security_roles.key = 'super_admin'`) open any restaurant with `X-Organization-Id`, as its owner.
  - The backend now connects with `DATABASE_URL` (master-admin's connection), which bypasses RLS. Tenancy is therefore enforced in code:
    - every query is scoped to the caller's organization;
    - client-supplied references are ownership-checked;
    - upserts refuse cross-tenant rows.
  - Attack tests with a second tenant prove all of this. `pos_*` tables keep RLS on with no anon access.
  - `supabase/RUN-IN-SUPABASE.sql` is the single file to run: master-admin 006–008 (recorded in `_migrations`), then the POS tables.
- **What works now:**
  - master-admin has **Partners → restaurant → Restaurant POS accounts**. You can create an owner/manager/cashier with a branch and role, suspend, reset a password, or delete. It is gated by a new `feat_partner_accounts` permission.
  - In the app, a platform admin gets a restaurant picker. An account with no restaurant is told to ask the admin.
  - The login is kept in the OS keystore (`flutter_secure_storage`), so the app reopens signed in. Offline it opens from the last known account. If the token was revoked or the account suspended, it goes back to sign-in.
  - Inventory & Supply, Targets & Benchmarking, and Compliance & Audit now work on live data:
    - the stock matrix has one column per real branch;
    - approving a transfer moves stock;
    - approving or rejecting a purchase order is saved;
    - par levels, shortage escalations, target amendments, audits and FSSAI renewals are saved as chain records and read back.
  - `npm run start:local` gives the whole platform a local Postgres (PGlite over the wire protocol): master-admin's migrations, the live-schema snapshot and the POS migration.
- **Verified:**
  - POS backend: 55/55 tests and typecheck clean.
  - master-admin backend: 48/48 tests on a fresh local DB, typecheck, lint and prettier clean.
  - master-admin frontend: 36/36 tests, typecheck, lint and build clean.
  - App: `flutter analyze` clean and 221/221 tests. They include new sign-in widget tests (picker, saved login, offline, revoked). They also include an end-to-end test that runs **both** backends on one temporary database:
    1. master-admin creates a restaurant, a branch and a manager;
    2. the POS signs in with that manager and syncs, and can't see or switch into Spicy Bistro;
    3. the platform admin opens any restaurant;
    4. suspending the manager in master-admin locks the POS out.
- **Not verified yet:** against the live Supabase project. That needs `RUN-IN-SUPABASE.sql` run, plus `DATABASE_URL` and `JWT_SECRET` in `backend/.env`.
- **Open questions for the founder:**
  - The allowed `ol_orders` status values are still unconfirmed (`accepted` / `preparing` / `ready` / `out_for_delivery` / `delivered` / `cancelled`).
  - master-admin's migration 007 drops `users.role` and `users.panel` if they exist. That is master-admin's own intended schema, but check nothing live still reads them.
  - The live platform admin's password (master-admin seed 002) isn't known here. The local seed uses its own.

## 2026-09-28 — Proviyaa POS: vendor-panel backend on the existing Supabase tables

**The app now has a real backend (`backend/`, Node + TypeScript). The app no longer calls Supabase at all: sign-in, Franchise/Chain, Master, Operations and device sync all go through the backend. The backend uses your existing Proviyaa OS tables wherever one exists.**

- **Existing tables first:**
  - The live database was mapped read-only with the publishable key, and no rows were read (`docs/EXISTING-DATABASE-MAP.txt`).
  - It is the shared OS database, but it isn't identical to the OS repo. `organizations` has `business_name`, and branches live in `org_locations`.
  - Menu, tables, orders, order lines, KOTs, payments and kitchen stations map onto `menu_items`, `dining_tables`, `orders`, `order_items`, `kot_tickets`, `payments` and `kitchen_stations`. Order and KOT numbers come from `next_org_seq()`. Online orders come from One Latur's `ol_orders`.
- **New tables only where none existed:**
  - Inventory, suppliers, purchasing, recipes, offers, media, reservations, deliveries, shifts, QR, and franchise records/targets/exceptions.
  - They are in `supabase/migrations/20260928_pos_vendor_backend.sql`. It is additive, safe to re-run, and has RLS on everything. **The owner runs it in the Supabase SQL editor; nothing in this repo applies it.**
- **Security:**
  - No secret key anywhere. The backend queries as the signed-in user, so the OS's RLS applies to every query, with role checks on top.
  - The online-orders screen's "Copy SQL" button, which created an anon-writable table, was removed.
  - Rejecting an online order now cancels it; shared orders are never deleted.
- **App:**
  - `supabase_flutter` removed.
  - With `PROVIYAA_API_BASE_URL` set, sign-in is real and the role opens the vendor panel or the POS.
  - `CloudSyncService` (Drift schema v6 adds `sync_row_states`) syncs every 30 s, 3 s after edits, and from the Sync button.
  - The Command Center, Branch Performance and Exceptions screens show live figures when a backend is configured. KPIs the data can't support show "—".
  - Without a backend the app runs fully local as before.
- **Verified:**
  - Backend: typecheck clean and 48/48 integration tests on a Postgres copy of the live schema, with real RLS and two tenants.
  - App: `flutter analyze` clean, and the full Flutter suite passes, including a new end-to-end test. That test starts the real backend, and two devices sync the whole seeded restaurant through it: 0 rejections, a settled order lands in `orders`/`payments`, and an edit on one device reaches the other.
- **Not verified yet:** against the live Supabase project. That needs the migration run and a real vendor account to sign in with.
- **Open questions for the founder:**
  - The allowed status values of `ol_orders` aren't visible with a publishable key. The backend writes `accepted` / `preparing` / `ready` / `out_for_delivery` / `delivered` / `cancelled`. Confirm these match One Latur.
  - Refresh tokens are kept in memory only, so the app asks for sign-in again after a restart. Encrypted on-device storage is still a release requirement (PRD §11).

## 2026-09-27 (evening) — Proviyaa POS: Operations module (restaurant admin)

**The Operations group in the admin sidebar now has all 9 pages from the Figma "opration" section: Live Operations, Captain Orders, KOT / Kitchen (KOT cards + Kitchen Display, with the Kitchen Stations and Sound & Alerts dialogs), Dine In (including the available-table panel), Reservations, POS Billing, Delivery, Online Orders (the existing screen), and QR Ordering.**

- **Design source:** Figma blocks this account (View seat), so the screens were built from PNG exports in `v1/operations/`.
- **One set of records:** Operations reuses the POS's own tables, orders, order lines, KOTs, payments and All Orders rows. An order taken in Captain Orders is the same row the kitchen advances, POS Billing settles, and the POS's All Orders lists. New tables exist only for deliveries, reservations and QR codes/sessions.
- **Schema:** v4 adds the Operations tables and columns; v5 adds the order customer name and the table's last-cleaned time. Upgrades now add a column only when it's missing, so they can't fail on an unusual device database.
- **Store rules:**
  - Stored in the database: Kitchen Stations (name, target minutes, colour, active) and Sound & Alerts. Each station's target time decides when a ticket shows as Delayed.
  - Enforced: Seat Now checks table capacity, and a table can't be transferred to an occupied one.
- **Verified:** analyze is clean and all 197 tests pass. The Operations tests render every screen at 1200px and 900px with seeded data, sign in and open every Operations page, and check the data layer.
- **Open questions for the founder:**
  - The Figma bill charges GST before the discount (₹93 on ₹1,860). The app charges it after the discount (₹84), which is the normal GST rule. Keep this?
  - Printing (bills, KOTs, QR images) needs printer hardware or a QR library. Those buttons say so.

## 2026-09-27 (later) — Proviyaa POS: Master module connected to the database

**Every Master button now reads from and writes to the local database: add, edit, delete, bulk actions, CSV import/export, media upload, PO → approve → receive stock, price approval, and recipe approval/activation. Master menu items are the same rows the POS sells.**

- **Structure:**
  - Schema v3 adds 11 tables (`lib/data/master_tables.dart`) plus Master columns on `menu_items_table`. It upgrades a v2 device in place, and a test confirms menu rows survive.
  - All inventory goes through one common engine, `DriftInventoryStore`. Stock only changes through GRN receipts or logged adjustments; each change is a stock movement.
  - Approving a supplier price makes it the costing price, so recipe costs follow. Activating a recipe pushes its price and cost to the POS menu item.
  - The first launch seeds the database from the reference data once (`MasterSeeder`). After that the database is the only source.
- **Verified:** analyze is clean and 148 tests pass. That includes 20 end-to-end UI flow tests that click the real buttons and check the database, a full-app sign-in → Master navigation test, and a v2 → v3 upgrade test.
- **Still not persisted:** modifier groups, quality audits, and per-staff training records (no tables yet). AI image generation, Sync and Print need a server or printer; those buttons say so.

## 2026-09-27 — Proviyaa POS: Master module completed against the Figma "finance" section

**Every screen in the Figma section (file YKRdukYpjPUuMz5W1tKlqT, node 423:55270, 25 screens) is now reachable from the Master menu of the admin vendor panel. Before this pass only Menu Items, Products (Online), the Add Item popup and the Media library existed; Offers, Inventory, Recipes, Suppliers and Purchase Orders were one-table placeholders.**

- **What was built:**
  - Offers: Campaigns & Offers Hub and Offer Detail.
  - Media: Asset Detail, opened by clicking an asset.
  - Inventory: Raw Material Master with its linkage panel, and Raw Material Detail with 6 tabs.
  - Recipes: the 10-tab recipe lifecycle, from Overview through Recipe Draft, Ingredients, Cost Calculation, Supplier Prices, Trials & Training, Staff Training, Feedback & Approval, Menu Activation to Cost Impact.
  - Suppliers: Supplier Price Integration and Supplier Price Detail.
  - Purchase Orders: list, PO Detail, and Receiving (GRN).
- **Structural decisions:**
  - All inventory data (raw materials, suppliers, supplier prices, purchase orders) comes from one shared model, `lib/domain/inventory.dart` + `lib/data/inventory_catalog.dart`. There is no restaurant-specific inventory engine (PRD R09 / S1 Phase 5).
  - Shared Master UI pieces live in `lib/presentation/master/master_ui.dart`. Every Master screen uses them, so cards, tables, status labels and buttons can't drift apart.
  - The dashboard date/region filter bar no longer shows on Master pages. None of the Master Figma screens have it.
- **Honest limits:**
  - Save, Approve, Create PO, Post GRN and similar buttons show a "not connected yet" message. Nothing is written to a database yet.
  - The Figma account has only a View seat on this file, so the Figma MCP allowed just a few calls. The screens were rebuilt from the file's layer data (every text label and position) plus 4 screenshots, not from pixel-level design exports. Button labels that aren't in the layer data were inferred.
  - Costs are calculated from the inventory prices, so some numbers differ from the static Figma mock-ups. For example, Paneer Butter Masala works out to ₹89.56 food cost, not the ₹118 shown in Figma.
- **Verified:** `flutter analyze` is clean. All 117 tests pass, including a new layout test that renders every Master screen at 1200px and 900px and fails on any overflow. Inventory and Recipes were also checked by eye in a web build.
- **Open questions for the founder:**
  - Should the Figma mock-up numbers be copied exactly, or keep the calculated figures?
  - The demo sign-in accepts any non-empty password for admin-like emails. That needs to change before anything is shared publicly.

## 2026-09-16 — Proviyaa POS: The app got its real navigation, five more screens, and now runs in a browser and on Windows

**The product stopped being four disconnected screens and became one application: a permanent left-hand menu with every module reachable from it, five more screens built from the approved designs, and the whole thing now runs in a web browser and can be built for Windows — with the code published to GitHub.**

- **Why:** Until now the app opened straight into one screen with no way to reach anything else, and it opened dark when the approved design is light. That made it impossible to show anyone the product as a product. The founder also asked how to share it — which turned "make it navigable" into "make it something you can send someone a link to."

- **Structural decisions:**
  - The navigation is built **once** and wraps every screen, rather than each screen drawing its own copy. Adding a future screen now means writing only that screen. The alternative — letting each page own its own menu — was rejected because it guarantees the menu drifts out of sync between pages over time.
  - The approved designs disagree with each other: different screens were captured with three different navigation styles (a left menu, a dark top tab bar, a collapsed icon strip). Rather than reproduce all three, the founder's explicitly nominated screen was treated as the single source of truth for the shell, and every other screen contributes only its own content. Noted here because it's a real inconsistency in the source material, not an oversight.
  - The app is now pinned to the light design instead of following the computer's dark-mode setting. The "why is it black?" problem was never a design choice — it was the app quietly inheriting the operating system's preference.
  - Screens with no real data behind them yet (delivery tracking, online order acceptance, menu editing) show the real layout with genuine reference data, but their buttons deliberately do nothing rather than pretending to work. Same standing rule as before: never make the app look more finished than it is.
  - **"Add Item" and similar buttons being inert is intentional, not broken** — flagged because the founder reasonably read it as a bug. There is no menu-editing capability in this product yet.

- **What works now:**
  - Every module in the menu is reachable and shows a real screen: the POS order pad, Tables, All Orders, Dine In, Takeaway, Delivery, Online Orders, and Menu Management.
  - **The app runs in a web browser** — verified properly, not assumed: an order was placed in Chrome and a real database was genuinely written inside the browser's storage. Getting there required tracking down why saving silently failed, which turned out to be a browser security requirement the hosting setup now satisfies.
  - **The app can be built for Windows.** Every push now automatically produces a real Windows program as a downloadable file. This can't be checked from the founder's Mac — Apple machines can't build Windows software — so it's checked automatically on a Windows machine instead.
  - The code is published at github.com/loki1514/Proviyaa-Pos- and is ready to be connected to a hosting provider for a live link.

- **Bugs found by actually using it, not by reading it:** cards whose buttons overflowed their edges, a table whose text broke mid-word on smaller windows, and — the important one — **a save that could hang forever with a spinner and no explanation**. That last one is now capped with a clear, retryable error message. It would have looked like a frozen till to a cashier.

- **Left undone, deliberately:**
  - The order pad opens as a full-screen step rather than sitting inside the menu frame. Reworking that working, tested screen wasn't worth the risk in this pass.
  - Screens exist for Delivery, Online Orders and Menu Management, but nothing behind them is real yet — no rider tracking, no accepting a Zomato order, no editing the menu.
  - The Windows program has never been run by a human on an actual Windows machine; it is only known to build.
  - Still no sign-in screen anywhere in the product — see the open question below.

- **Open questions for the founder:**
  - **There is no login screen in any of the 36 approved designs.** Either this product is meant to sit behind a sign-in that another Proviyaa system already owns, or one was never designed. This needs a decision — the offline staff sign-in logic already exists underneath, with nothing in front of it.
  - The code repository is currently **public** — anyone can read it. It contains no passwords or keys, but it should be a deliberate choice rather than a default.
  - Connecting the live hosting still needs the founder's authorization on their own account before it can be set up.

## 2026-09-15 — Proviyaa POS: Backend pushed from auth through sync — payments, offline sign-in, and the PowerSync spike

**Closed a real gap under the already-built Payment screen (it wasn't actually saving anything), built the local-first staff sign-in and 24-hour offline authorization the source material specifically calls for, built the retry/idempotency logic a background sync will eventually run on, and did the real client-side half of the PowerSync compatibility spike — checking current documentation rather than assuming, since this ecosystem moves fast.**

- **Why:** The last entry left off with four screens working visually and functionally in isolation. What was still missing was the plumbing the source material treats as non-negotiable: payments are their own record, not a status flag; a cashier who signs in once should keep working for a day without the network; and nothing about "sync" existed yet beyond a table that filled up and never drained. All of this is backend work, not more screens, so it went first.

- **Structural decisions:**
  - Payment is its own database table, separate from order status — the source is explicit that order, kitchen, payment, and settlement must never be collapsed into one status field.
  - The sync worker is built against an interface (`CommandTransport`), not a real server, because no real authorized-command API exists yet — the source material itself calls those "proposals, not existing endpoints," and this project doesn't get to invent that API unilaterally; Proviyaa OS owns it.
  - The PowerSync spike produced a real, load-bearing finding: adopting PowerSync would **replace** the sync worker just built, not run alongside it — running both would be exactly the "second competing sync engine" the decisions record already rules out. That's now written down before anyone builds both and has to unwind it later.
  - The real Supabase sign-in code was written against the current SDK (checked directly, not assumed) and compiles, but was **not** tested against the live project — there's no way to inspect what staff/auth schema actually exists there, and no test account was created, because creating accounts or handling credentials isn't something this session does on the founder's behalf.

- **What works now, verified for real, not assumed:**
  - Completing a cash payment now genuinely writes a row to its own `payments` table — confirmed by reading the actual database file after clicking through the app, the same way every other piece of this rebuild has been checked.
  - A cashier who signs in gets a 24-hour offline grant cached on the device; a second startup can read that grant with zero network calls. An expired grant is kept, not deleted — matching the source's explicit "preserve data, deny new privileged work" rule for that case.
  - The sync worker correctly treats "accepted" and "duplicate" as the same success, treats "rejected" and "conflict" as needing review without blocking the rest of the queue, and treats a plain network failure as "retry later," not a business rejection — all backed by tests, not just written and hoped for.
  - The PowerSync client packages were actually added to the project and confirmed to compile cleanly alongside everything already built, and real current pricing was checked (free tier exists but deactivates after a week idle, unsuited to a start-and-stop evaluation).

- **Left undone, deliberately:**
  - No real backend exists for the sync worker to talk to yet — it has nothing to synchronize with until Phase B's actual API or a PowerSync instance exists.
  - The real Supabase sign-in path is unverified against the live project. Someone with an actual staff login needs to try it.
  - PowerSync itself is not connected to anything — that needs the founder to create a PowerSync account and run a couple of SQL statements in the Supabase project, neither of which this session can do.
  - No new screens were built this pass, on purpose — the Takeaway screen, the Dine-In board, and the persistent navigation chrome are all still exactly where the last entry left them.

- **Open questions for the founder:**
  - PowerSync go/no-go: given it would replace the sync worker just built (not add to it), does the founder want to proceed with a real PowerSync account/instance, or keep the hand-built sync worker and wait for Phase B's real API instead?
  - Someone needs to actually sign in through the real Supabase Auth code with a genuine staff account to confirm it works end to end — this session could write and compile it, but not test it live.

## 2026-09-15 — Proviyaa POS: Four real screens rebuilt and click-tested end to end

**Continued the screen-by-screen rebuild from the real reference: order-capture, Payment, and Kitchen Display are now done, on top of Tables from earlier today — each one actually clicked through in the running app, not just visually compared. Found and fixed five real bugs by doing that, one of which would have crashed the app on next launch.**

- **Why:** "Looks right in a screenshot" and "works when you actually use it" are different claims. Given how much this project has already suffered from work that looked plausible but wasn't grounded in the real thing, every screen in this pass was driven end to end in the actual running app — adding items, sending a KOT, paying, advancing a kitchen ticket — before being called done.

- **Structural decisions:**
  - Corrected the kitchen ticket's state names to match the architecture source's own vocabulary (`New → Preparing → Ready → Completed`) instead of the informal names used when the domain was first sketched.
  - Payment only lets **Cash** actually complete a transaction. Card, UPI and Split Pay are shown (matching the real screens) but refuse with an explanation, because the source material is explicit that an unverified tap must never be treated as a confirmed digital payment.
  - Where the real screens show figures this app has no real logic for yet — service charge, a discount coupon, a tip, a live kitchen checklist with a progress bar — those are left out rather than filled in with invented numbers. Same principle both times: don't fake data to make a screen look more finished than the app actually is.

- **What works now, verified by actually doing it in the app:**
  - Order capture: pick a table, add items, watch the cart total compute correctly, and save the order.
  - Payment: the bill recap and total carry over correctly, Amount Received defaults to the exact total, quick-amount chips work, change due computes correctly, and completing a cash payment works.
  - Kitchen Display: a sent order shows up as a ticket in the right column immediately, and clicking through New → Preparing → Ready → Served moves it column to column and finally off the board — all backed by the real local database, the same one a device restart wouldn't lose data from.

- **Five real bugs found and fixed by running the app, not by reading the code:**
  1. Every "open this table" tap silently did nothing — the code was asking the wrong part of the screen for permission to navigate.
  2. The payment screen's own layout didn't fit in the space given to it.
  3. A visual warning buried in the log about how a list item was painted, which the framework itself flags as a real defect, not cosmetic.
  4. The most consequential one: the cash amount box defaulted to a bill nearly **100 times too large** (₹52,500 instead of ₹525) — a classic "counted the wrong unit" mistake that a quick glance at the running screen caught immediately and code review alone likely would not have.
  5. The app **crashed on launch** the next time it was tested, because a ticket saved earlier today under the old status names couldn't be read back under the corrected ones. Fixed for now by clearing that local test data; the underlying lesson — that renaming something already written to the database needs an explicit migration, not just a code change — is exactly what D10's "explicit numbered migrations" rule is there to prevent, once this reaches real devices with real data on them.

- **Left undone:** Takeaway orders and the Dine-In status board — two more real screens — are not rebuilt yet. Neither is the persistent top navigation (logo, tab bar, search, notifications) that every real screen actually has; right now, moving between screens uses a stand-in floating button and back arrows instead. Hold Orders, All Orders, and everything beyond V1 Phase C (Delivery, Online aggregator inbox, Store Control) remain untouched.

- **Open questions for the founder:** None new — Q02 and D07 corrections from earlier today stand; this entry is progress against them, not a new decision point.

## 2026-09-15 — Proviyaa POS: Rebuilding the real screens 1:1, first one done and verified

**Threw out the placeholder screens built earlier today, read the real 36-screen design reference the owner supplied, re-read all three ecosystem source documents in full to ground the rebuild, and delivered the first screen (Tables) rebuilt exactly against the real design — visually checked against the reference, not just assumed correct.**

- **Why:** Earlier today, UI was built from the PRD alone using generic placeholder styling, since no confirmed screens existed yet. The owner then pointed out — correctly — that this wasn't acceptable: they need the real product screens, exactly, with no invented layout. They supplied 36 exported screens (light and dark pairs of 17 real VINII POS screens) as the authoritative reference.

- **Structural corrections, sourced from re-reading the three ecosystem documents in full:**
  - Product naming was wrong. The correct names, confirmed directly from the source text, are **Proviyaa / Proviyaa Global** (not "Proviyaa OS"), **VINII POS** with Restaurant/Store/Service as its three verticals (not "VINII Restaurant POS" as one name), **One Latur** as the actual deployed customer marketplace (**OneCity** is the generic pattern name, not a different product), and **OnLatur** as the single delivery product (not two separate "Fulfilment" and "Rider" products). The decision record has been corrected with the old names struck through, not silently replaced.
  - The kitchen ticket lifecycle was under-specified. The architecture source names it explicitly: **New → Accepted → Preparing → Ready → Picked Up → Completed** — more precise than the four-state version built earlier today, which will be corrected in the next pass.
  - Typography was quietly wrong in a way that would have broken at the worst time: the first fix used a Google-hosted font that tries to download itself at startup — which fails silently on a sandboxed, offline-first POS (confirmed by actually testing it: it errored trying to reach fonts.gstatic.com and fell back to the wrong font). The real fix uses the exact font files already sitting in the project's assets folder, bundled into the app itself, so typography works with the network fully off — consistent with the PRD's own requirement that this app must survive "internet disabled and restart tested."

- **What works now:** The exact brand green (`#76EC00`) was confirmed by sampling actual pixels from the reference images, not eyeballed — the same color the very first (mistaken) Figma pull had already recorded, so it's now doubly confirmed. The Tables screen is rebuilt to match the real design: the same stats line, the same zone filters, the same per-status card styling (occupied/available/reserved/cleaning, each with the right color and the right action button). It was screenshotted running in the real app and checked side-by-side against the reference image, not just assumed to match from reading the code.

- **Left undone:** Five more screens from the real reference — order-capture (POS), Payment, Kitchen Display (KOT), Takeaway, and the Dine-In status board — are not rebuilt yet. Neither is the app's top navigation chrome (logo, tab bar, search, notifications). There is still no reference screen for shift open/close (opening float, counted cash, variance); the owner has confirmed it should be built to match the same visual language as a best-effort, not claimed as a 1:1 match since nothing to match against exists.

- **Open questions for the founder:** None new this entry — Q02 (screen reference) and D07 (naming) are both corrected and recorded; work continues screen-by-screen from here.

## 2026-09-15 — Proviyaa POS: Local database is real now, and a Figma mix-up was caught before it cost build time

**Implemented the approved local database technology end-to-end, confirmed the Supabase staging project, and caught — before writing any UI — that the only Figma link on file points to a back-office admin screen, not a restaurant order-taking screen.**

- **Why:** The morning's V1 decisions said the local database must be Drift/SQLite with automatic first-launch creation and versioned migrations (D10) — that existed only as a schema sketch until now. Separately, the owner asked for UI work to proceed strictly from a specific Figma link "going forward, no going away from that." Before committing to that, the actual content behind that link needed checking — the earlier session's own notes had already hedged that the node was "provisional App Builder" material, which turned out to matter.

- **Structural decisions:** None reversed. This session executed decisions already on record (D10) rather than making new ones — Drift on SQLite via `drift_flutter`, the current official Flutter-native way to open a Drift database (replacing the now-defunct `sqlite3_flutter_libs` package, which was checked live on pub.dev and confirmed end-of-life before it went into the dependency list).

- **What works now:**
  - The local database is real: `lib/data/app_database.dart` defines the `orders`, `order_lines`, and `pending_upload_intents` tables in Drift, auto-creates `proviyaa_pos.sqlite` on first launch, and carries an explicit migration strategy that never drops data on upgrade.
  - `lib/data/drift_local_store.dart` is a working, disk-backed implementation of the same `PosLocalStore` interface the order service already used — a cash order saved twice (a retried/replayed submission) still produces exactly one order and one pending-upload intent.
  - Four new automated tests prove this rather than just claim it: the database file appears only after first open, a saved order survives being closed and reopened (simulating the app restarting mid-shift), and a replayed save doesn't duplicate anything. All 7 tests in the project (up from 3) pass, and `flutter analyze` is still clean.
  - The Supabase project already sitting in the local, git-ignored `.env.local` file is now confirmed as the approved staging project (closing part of Q04) — though who can access it, its backup policy, and its region label are still unconfirmed.
  - The Figma link the owner sent (node `275:304`) turned out to be a vendor back-office "App Builder" screen — categories, a theme-color picker, Publish/Draft buttons — not a cashier order-taking screen. This was checked twice: once against the previously captured design data, and once against an actual cached screenshot of the screen, which was sent to the owner directly so they could see exactly what's there.

- **Left undone:** No order-capture UI was written. Building screens against a design reference that turned out to be the wrong screen would have meant redoing that work, so it stopped at the verification step and came back to the owner instead. Wiring `DriftLocalStore` into a real running app (today it's proven by tests, not yet used by `main.dart`) is also still pending, since there's no UI yet for it to serve.

- **Open questions for the founder:**
  - Which Figma screens actually cover the restaurant order-taking flow (tables, menu, order lines, kitchen ticket, cash/shift close)? Node `275:304` is not that.
  - If no such Figma screens exist yet, should UI work proceed from the written PRD instead (using this app-builder screen only for shared visual tokens — colors, type, spacing), and get reconciled against real screens once they exist?
  - Should the vendor "App Builder" panel itself eventually be built as a feature of this same POS app, or does it belong to a different Proviyaa product entirely? (Its own captured content suggests it's OS/vendor-configuration territory, not restaurant-counter territory — matching the boundary this project already committed to.)

## 2026-09-15 — Proviyaa POS: Local foundation validated, source-grounded, and V1 scope locked

**Got the local app actually running and verified, read the full ecosystem documentation to ground the POS's scope, and locked ten V1 product decisions so feature work can resume on solid ground.**

- **Why:** Before this session there was no working development environment, no confirmed understanding of how the Restaurant POS fits into the wider Proviyaa OS / Commerce / OneCity / Fulfilment / Rider / Finance system, and no locked decisions on device, payments, offline behavior, sync approach, or database technology. Any feature work started before this risked being built on wrong assumptions or duplicating systems the wider OS already owns.

- **Structural decisions:**
  - Local database will be **Drift on top of SQLite** (not a raw sqlite3 binding, not MySQL), with explicit numbered migrations created automatically on first launch, and no automatic deletion of unsynced records. MySQL was explicitly considered and ruled out.
  - Sync direction is **PowerSync**, pending a Flutter compatibility/cost spike — not a hand-built custom sync engine, so the POS doesn't end up maintaining a second sync system alongside whatever the wider OS uses.
  - The Restaurant POS's boundary was written down explicitly: it does **not** own identity, entitlements, configuration, the shared customer/order/payment/settlement records, or inventory — it reads those from the OS/Commerce/Inventory systems and only owns the local operator experience (tables, order capture, kitchen tickets, cash evidence, shift and sync status). This is now on record in `docs/SOURCE-UNDERSTANDING.txt` so future features don't accidentally rebuild OS-owned systems.
  - First device target is **Windows**, one primary POS per location for V1 (multi-terminal/offline coordination deferred), a **cash-first pilot** with digital payments held as "pending verification" rather than confirmed-paid, and a Figma screen (App Builder, node `275:304`) was pulled in read-only as provisional visual reference only — explicitly not final design approval.

- **What works now:** The app builds, analyzes clean, and its test suite passes — order save with pending status and totals, idempotent replay of a save, and the local-demo shell rendering — on a real Flutter 3.47.4 / Dart 3.13.3 toolchain (re-verified independently this session, not just taken on faith). A developer can run `./tool/run_local.sh` in local-demo mode with no cloud credentials required. Ten V1 decisions (device, offline topology, payment posture, timing limits, sync direction, Supabase environment ownership, product naming, Figma status, finance posture, and database technology) are written down as the standing baseline in `docs/DECISIONS-AND-QUESTIONS.txt`, each paired with the follow-up question (Q01–Q05) that spells out exactly what evidence would close it.

- **Left undone:** Feature/UI work was deliberately paused this session to do source-reading and decision-locking first, at the owner's explicit request. Drift/SQLite is still only a table definition — no package, first-launch opener, or migration runner yet. No Supabase project is wired up for real sync or schema inspection. Finance/tax rules, the final approved Figma file/node set, exact hardware models, the Supabase staging project, and the PowerSync spike are all still open (Q01–Q05 in `docs/DECISIONS-AND-QUESTIONS.txt`). The project also still has no git repository, so none of this history is committed anywhere yet.

- **Open questions for the founder:**
  - `.env.local` on this machine already has a live-looking Supabase project URL and publishable key filled in, but the decision record still lists the Supabase staging project as unconfirmed (Q04). Is this the approved staging project? If yes, Q04 should be marked resolved; if not, it should be cleared out before anyone builds against it.
  - The preflight note claiming the three ecosystem source documents were fully re-read reports line counts that don't match the files actually on disk (one file off by roughly 2×), even though the files themselves are byte-identical to the originally checksummed copies. Worth a spot check of `docs/SOURCE-UNDERSTANDING.txt`'s citations before leaning on them as fully verified.
  - Q01–Q05 (finance/tax rules, final Figma file/node set, exact hardware, Supabase staging project details, PowerSync spike acceptance criteria) still need sign-off before those parts of the build can move forward.
  - No git repository exists yet for this project — worth setting up before more work accumulates uncommitted.
