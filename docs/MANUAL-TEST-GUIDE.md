# Vendor Panel: Manual Test Guide

Date: 2026-09-29. This guide covers the restaurant roles, the accounts to use, and what to check for each role by hand.

**Passwords are not in this file.** They are in git-ignored files on this machine (local test accounts, local database only):

- `backend/.data/LOGINS.txt`: every login below, from the top role down.
- `backend/.data/manual-test-accounts.txt` and `backend/.data/qa-accounts.txt`: the same values, per script.

## 1. The restaurant roles

A restaurant has **six roles**: the Owner, and the five the restaurant hands out.

| # | Role | Sees | Does |
|---|---|---|---|
| 1 | **Owner** | every branch | Everything. Created in master-admin. |
| 2 | **Restaurant Admin** | every branch | Everything, except changing the owner. |
| 3 | **Branch Manager** | **one branch** | Runs that branch: Dashboard, Master (menu, stock, recipes, suppliers, purchase orders), all of Operations, Staff (staff, attendance, shifts, logins, approvals, training), and the branch's Customers & CRM and Finance. Verifies UPI/card. No chain views, no payroll, no marketing, integrations, tasks or settings. |
| 4 | **Cashier** | one branch | POS: New Order, Tables, All Orders, Dine In, Takeaway, Delivery, Online, Menu. Takes payment. |
| 5 | **Captain** | one branch | POS: New Order, Tables, Dine In, All Orders. Takes orders and sends KOTs; cannot take money. |
| 6 | **Kitchen (KOT)** | one branch | The kitchen display only. |

- **Business sections:** Task Manager, Customers & CRM, Marketing, Finance, Integrations and Settings are built from the designs (§4b). The Owner and Restaurant Admin see all six; the Branch Manager sees Customers & CRM and Finance. Reports, Page Builder and Support have no designs yet: they are tagged **Soon** and open a "not built yet" page.
- A special job (store keeper, accountant, waiter, delivery boy) is a **custom role**. Go to Staff & Users → Roles & permissions → Create Custom Role, pick one of these as the base, and tick only the screens that person needs.
- The Owner and Restaurant Admin create Branch Managers. A Branch Manager creates the Cashier, Captain and Kitchen logins for their own branch.
- Older logins that master-admin gave a generic role keep working as the nearest role: "Manager" works as Branch Manager, and "Waiter" as Captain. The other old roles have no access until an admin gives the login one of these six.

**Evidence** (all on 2026-09-29, against running servers):

| Level | What was run | Result |
|---|---|---|
| Real app UI and backend (Flutter end-to-end, real login screen) | Owner, Cashier, Captain (takes a table order to the kitchen), Kitchen, Branch Manager, master-admin onboarding | pass |
| Offline POS, real backend | A cashier's till bills with the network cut, then uploads everything when it returns | pass |
| Server, every role (`backend/scripts/qa-walkthrough.ts`) | Login, app, exact screens, branch scope and 15 data calls per role (allowed or refused) | 193/193 checks |
| A restaurant day (`backend/scripts/restaurant-day.ts`) | Owner, Captain, Kitchen, Cashier and Branch Manager each do their part; every write read back through the API | 22/22 steps |

## 2. Start the apps

These are running now. To start them again, run from `D:\Projects\Proviyaa-pos`:

| App | URL | Start command |
|---|---|---|
| Vendor panel / POS (Flutter web) | http://localhost:8642 | `python -m http.server 8642 --directory Proviyaa-Pos-/build/web` |
| Vendor panel backend + local database | http://localhost:8787/health | `npm --prefix Proviyaa-Pos-/backend run start:local` |
| master-admin (web) | http://localhost:5173 | `npm --prefix Proviyaa-Pos-/master-admin/frontend run dev` |
| master-admin (API) | http://localhost:8000 | `npm --prefix Proviyaa-Pos-/master-admin/backend run dev` |

Press **Ctrl+F5** once in the vendor panel after a rebuild.

## 3. Accounts

A second local restaurant, **Latur Spice House**, was created in Proviyaa master and staffed from the vendor panel on 30 Sep 2026 (owner, restaurant admin, branch manager, cashier, captain, kitchen). Its logins are in the git-ignored `backend/.data/laturspice-accounts.txt`; the run is written up in `docs/qa/NEW-RESTAURANT-ONBOARDING-20260930.md`.

**Restaurant:** Proviyaa QA Kitchen.

- Branch roles have the home branch **QA Branch 202609290732**, which is also the owner's default branch.
- The other branches were created by automated test runs.

| Role | Email | Opens |
|---|---|---|
| Platform super admin | `superadmin@onlatur.com` | master-admin; in the vendor panel it picks a restaurant and acts as its owner |
| 1 · Owner | `owner@qakitchen.test` | Vendor panel, 46 screens, every branch |
| 2 · Restaurant Admin | `test.org-admin@qakitchen.test` | Vendor panel, 46 screens, every branch |
| 3 · Branch Manager | `test.location-manager@qakitchen.test` | Vendor panel, 25 screens, one branch |
| 4 · Cashier | `test.biller@qakitchen.test` | POS, 8 screens |
| 5 · Captain | `test.captain@qakitchen.test` | POS, 4 screens |
| 6 · Kitchen (KOT) | `test.kitchen@qakitchen.test` | Kitchen display |
| Cashier, first sign-in | `test.first-login@qakitchen.test` | must set a new password first |
| Second restaurant's owner | `admin@spicybistro.com` | Spicy Bistro; use a private window |

**Data already in the restaurant** (from the restaurant-day runs):

- **Master → Menu Items:** "House Specials" (Veg Biryani ₹220, Paneer Butter Masala ₹260, Butter Naan ₹45, Masala Chai ₹30, Chicken Tikka ₹280), and Masala Dosa ₹120 in "South Indian".
- **Master → Inventory:** Basmati Rice, Paneer (low stock), Milk, Dosa Batter (low stock).
- **Operations → Dine In:** Main Hall with T1–T4.
- **Orders:** paid cash, UPI verified by the Branch Manager, a card payment verified, one cancelled.

## 4. What to check, role by role

Sign in at http://localhost:8642, and use Sign Out to switch roles.

### 1 · Owner and 2 · Restaurant Admin
1. The vendor panel opens on the **Dashboard**.
   - The sidebar follows the design: Franchise / Chain, Master, Operations, Task Manager, Reports (Soon), Page Builder (Soon), Customers & CRM, Marketing, Finance, Staff & Users, Integrations, Support (Soon), Settings.
   - Figures are real: sales count only paid orders, and UPI waiting for verification is shown apart.
2. **Master → Menu Items:** add a category and a dish, edit it, mark it unavailable, delete it.
3. **Operations → POS Billing:** settle a bill in cash; pay another by UPI, then **Verify Payment**.
4. **Staff & Users → Roles & permissions:** exactly five roles (Restaurant Admin, Branch Manager, Cashier, Captain, Kitchen). **Create Custom Role**, for example "Store Keeper" on Branch Manager with only Inventory.
5. **Staff & Users → Staff:** add an employee with a login and choose a role.
6. As the Restaurant Admin, the owner's login cannot be reset or suspended.

### 3 · Branch Manager
1. The vendor panel shows **one branch** and **no Franchise / Chain** group. Of the business sections it shows Customers & CRM and Finance (and Reports, tagged Soon); Task Manager, Marketing, Integrations and Settings are not there.
2. Master (menu, inventory, recipes, suppliers, purchase orders) and all of Operations work for that branch.
3. **Staff & Users:** Staff, Attendance, Shifts & Roster, Login Security, Approvals and Training are there. Salary, Advances, Roles & permissions, Audit Log and Reports are not.
4. Add a Cashier, Captain or Kitchen login for the branch; that works. Giving someone Restaurant Admin is refused.
5. Operations → POS Billing: **Verify Payment** on a UPI bill works.

### 4 · Cashier
1. The POS opens with **New Order, Tables, All Orders, Dine In, Takeaway, Delivery, Online, Menu**.
2. New order → **Send KOT**. Save & Hold, then resume it.
3. **Proceed to Pay → Cash:** the order is paid and the table goes to Cleaning → **Mark Available**.
4. Pay by UPI: it shows "pending verification", and the cashier cannot verify it.

### 5 · Captain
1. The POS opens with **New Order, Tables, Dine In, All Orders** only.
2. **Dine In → a free table → Start Order**, add dishes, then **Send KOT**. The table turns "Waiting KOT".
3. The pay button reads **"Payment is taken by the cashier"** and is disabled.
4. Open the same table again and add an item: it goes to the kitchen as a follow-up KOT.

### 6 · Kitchen (KOT)
1. Only the **Kitchen Display** opens, with Sign Out.
2. New tickets appear live: **Start Cooking → Mark Ready → Serve**.
3. A cancelled order shows "Order cancelled — stop preparing".

## 4b. The business sections (Owner or Restaurant Admin)

Everything below is saved in the database. Reload the page, or sign in on another browser, and it is still there.

### Customers & CRM
1. **Customers → Add customer:** first name, phone, email, tags, WhatsApp / SMS preferences → **Save Customer**. Using the same phone twice is refused.
2. Take a POS order with that phone number and pay it. The customer then shows **1 order**, the spend, and loyalty points (5 points per ₹100 by default, credited once per bill).
3. **Customer Groups:** the system segments count real customers. Create a custom segment (e.g. tag VIP) and open its members.
4. **Loyalty:** change the rules and tiers → **Save loyalty rules**. Add a manual redemption; the ledger shows it.
5. The **Wallet** tab: top up ₹500, then redeem more than the balance; the redemption is refused.
6. **Feedback:** add, acknowledge and resolve. **Ideas:** suggestions and top items come from your own bills.

### Marketing
1. **Promotions → Create Offer** (e.g. MONSOON50, 50%, max ₹150). It also appears in **Master → Offers**, and devices get it on their next sync.
2. **Campaigns → Create Campaign → Send now.** The campaign is **Queued** with its audience count, and the note says nothing was delivered because no WhatsApp / SMS provider is connected.
3. **Notifications (Ads):** request an ad. It stays **pending** until the Proviyaa team reviews it. You can withdraw it while it is pending.

### Finance
1. **Transactions:** the balances come from POS bills by payment method plus your entries. **Record transaction** (e.g. an ₹750 packaging expense), then turn on **Needs approval** for a top-up and approve it under Approvals.
2. **Payments:** POS bills and online orders in one list; UPI that isn't verified shows as pending.
3. **Expenses:** add expense heads with budgets and see spend against them.
4. **Settlements:** record a Zomato settlement; it gets a number STL-YYYYMMDD-NNN. **Documents:** add a licence that expires in 30 days; it shows **Expiring soon**.

### Task Manager
1. **Create Task:** add a title, pick a staff member, tick **Checklist required** and **Manager approval**, add checklist items → **Assign & Notify Staff**.
2. Open the task: **Start**, tick the items, **Submit** (with a photo link if "Live photo required"), then **Fail** with a reason → **Reassign** → submit again → **Approve**. The lifecycle timeline shows every step.

### Integrations
1. **Other Integrations → Connected apps → Connect** (e.g. Tally Prime) with an account ID. The status is **pending**: the Proviyaa team links it.
2. **Sync engine:** queue a sync, then **Run queue**. It fails with "not connected", which is the honest result until the app is linked.
3. **API keys → Generate key:** the full key is shown **once**. The list shows only its prefix. Try Rotate and Revoke.
4. **Webhooks:** only public **https** URLs are accepted. **Send test** really sends a signed request and logs the result under Deliveries and Logs.

### Settings
1. **Restaurant Settings:** the outlet name, phone, address and category. Saving the name renames the restaurant in the panel.
2. **POS Settings:** devices, printers, and **Bill Format** with a live preview. The bill header is what the POS prints. **Test Print** says plainly that nothing was printed, because no print agent is installed.
3. **Order Settings:** add and edit dine-in tables; order takers are the Captain logins.
4. **Notification Settings**, **Account Settings** (subscription: choose a plan → request recorded, no payment), and **System Updates** (system overview, KDS preferences, operations centre, and the server version).

To create a full set of sample records through the API and check each one is stored, run `npx tsx scripts/business-day.ts` from `backend/` with QA_OWNER_EMAIL and QA_OWNER_PASSWORD set. It writes a report to `docs/qa/`.

## 5. Checks across roles

| Check | How | Expected |
|---|---|---|
| First sign-in password change | Sign in as `test.first-login@…` | A "set a new password" dialog appears first. |
| Lockout | 5 wrong passwords on `test.captain@…` | Locked for 15 minutes; a password reset by the owner, admin or branch manager unlocks it. |
| Sign-out | Sign out, then reload | Back at the login screen. |
| UPI end to end | Cashier pays by UPI; Branch Manager verifies | Dashboard sales rise only after verification. |
| Branch isolation | Branch Manager or Cashier vs the Owner | The branch roles see only their branch's orders. |
| Restaurant isolation | `admin@spicybistro.com` in a **private window** | None of QA Kitchen's menu, orders or staff appear. |
| Two branches | Sign in as `owner@laturspice.test` (Ganj Golai + Ausa Road) and as `manager2@laturspice.test` | The owner's Command Center lists both branches; the manager sees only Ausa Road — its dashboard, staff, tables and orders. |
| Whole restaurant, every module | `cd backend && QA_OWNER_EMAIL=owner@laturspice.test QA_OWNER_PASSWORD=… QA_ADMIN_EMAIL=superadmin@onlatur.com QA_ADMIN_PASSWORD=… MASTER_BASE=http://localhost:8000/api MEDIA_BASE=http://localhost:8643 npx tsx scripts/latur-full.ts` (start the `qa-media` preview first) | 167 checks pass; report in `docs/qa/LATUR-FULL-<run>.md`. |
| **Offline POS** | Cashier signed in → F12 → Network → **Offline** → take a cash order and a UPI order | The POS keeps working and shows changes waiting. |
| Back online | Network back on → **Sync** | "Synced"; the Owner sees both orders (cash paid, UPI pending). |
| Data really saved | Run the command in §6 | Lists the orders stored on the server. |
| Real data only | Open every page as the Owner | Names, numbers and words only: no long ids like `5e2f888f-…`, no codes like `half_day` / `order.created`, no raw timestamps. Orders read "ORD-248", KOTs "KOT #37", online orders "OL-…". |
| Pickers, not typing | New delivery, assign rider, seat a table, add staff, record an expense, add a device | The order, rider / server, branch, expense head and station are picked from lists (with "Other…" / "+ Add new…"). |

## 6. See the stored data yourself (API)

As the owner, run this from `backend/` to list the last 10 orders stored on the server:

```
node -e "const b='http://localhost:8787';const [e,p]=process.argv.slice(1);fetch(b+'/v1/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:e,password:p})}).then(r=>r.json()).then(j=>fetch(b+'/v1/operations/orders?limit=10',{headers:{Authorization:'Bearer '+j.data.session.access_token}})).then(r=>r.json()).then(j=>console.table(j.data.map(o=>({no:o.display_no||o.order_no,channel:o.channel,status:o.status,total:o.total,customer:o.customer_name}))))" owner@qakitchen.test <owner password>
```

## 7. Things that behave on purpose

- **One browser = one restaurant branch.** Signing in to another restaurant or branch in the same browser clears that browser's local data first. It refuses while changes are unsent: sign back in, Sync, then switch. Use a private window for the second restaurant.
- **Card / UPI are never "paid" until a manager verifies them.** No payment provider is connected yet.
- There is no receipt printer; bills show on screen.
- master-admin is unchanged. It still offers its older, longer role list when creating accounts; the vendor panel maps those roles as described in §1.
- The full list of limitations is in `docs/VENDOR-PANEL-REPORT.md` §12.

If something doesn't match this guide, note the account, the screen and what you pressed, and I'll trace it.
