# Latur Spice House — offline, second branch, full data and every module (30 Sep 2026, night)

Follows `NEW-RESTAURANT-ONBOARDING-20260930.md`. Same local platform: Proviyaa master (:5173/:8000), POS backend (:8787) and the vendor panel (:8642) on the one local Postgres (PGlite). The live Supabase project was not touched.

## 1. Offline, then sync

| Step | Seen |
|---|---|
| Owner on POS Billing; the POS backend process stopped | Top bar turned **Offline**; the menu, tables and open bills stayed usable |
| Takeaway bill: Mango Lassi + Masala Chai, cash | **Bill #4803 settled · ORD-90A66-9983 · ₹126 · Cash**; top bar **Offline · 5 waiting** (the order, its lines, KOT and payment queued on the device) |
| Backend started again; Sync pressed | **Synced**; the server has `ORD-90A66-9983` pickup **paid**, payment ₹126 cash **completed** |

So the POS keeps working without the server, and the queued changes reach the database when the connection returns. The 24-hour offline sign-in grant and the device's own database are what make this work.

**The live Supabase project:** the sync goes wherever the POS backend's `DATABASE_URL` points. Locally that is the PGlite database; `backend/.env` still has `DATABASE_URL` empty, so nothing has been written to the live project and the same offline → online path has **not** been run against it. To run it there, put the live connection string (and the JWT secret the deployed master uses) in `backend/.env`, start the backend with `npm run start` and repeat the steps above — it will create test orders in the live database.

## 2. Second branch (Proviyaa master)

- Added **Ausa Road Outlet** (LSH-02) to Latur Spice House in master. The owner's next sign-in listed both branches.
- Found and fixed while doing it: the POS backend caches a login's branches for 30 s, so a branch added in master a moment earlier was missing until the cache expired. Signing in now clears that cache (`routes/auth.ts`).
- Found and fixed: with no home branch, the owner's acting branch was "the first branch by name", so adding **A**usa Road silently made it the owner's default and the device would have re-bound to it on the next sign-in. Branches are now ordered by creation (`context.ts`), and the app keeps the device's bound branch whenever the account may act for it (`main.dart`, `VendorAccount.actingFor`). Verified: owner signed out and in again, still on Ganj Golai Main Outlet, nothing wiped.

## 3. Everything filled and exercised — `backend/scripts/latur-full.ts`

167 checks, 0 failed (`LATUR-FULL-202609301801e6ef.md`). Every write is read back through the API; the branch-manager section signs in as each manager.

| Area | What was created / done |
|---|---|
| Menu | 6 sections, 22 dishes across starters, mains, breads, rice & biryani, desserts, beverages; veg / non-veg / egg; kitchen stations; **every dish has a generated photo** (`scripts/gen-dish-images.ps1` → `.data/qa-media`, served by the `qa-media` preview on :8643). Edit and delete round-trips. |
| Media | 18 photos filed in the Media Hub under "Dishes" |
| Inventory | 3 suppliers, 8 raw materials stocked per branch (Onion below reorder), 4 supplier quotes |
| Recipes | 3 recipes linked to dishes with 9 ingredient lines (food cost shows in the app) |
| Purchase orders | PO with 2 lines → approved from the chain screen → goods receipt + stock movement |
| Offers | 3 live offers (percent, flat, free item) |
| Operations, both branches | floors + tables (add, edit seats, delete), reservation, dine-in order → KOT cooked → ready → card payment → verified; takeaway paid cash; delivery order → UPI verified → rider assigned → delivered; an order cancelled with a reason; Swiggy online order accepted → ready; QR code + QR session; branch summary; bill settings (GST 2.5 + 2.5, FSSAI) |
| Franchise / Chain | monthly targets per branch; system low-stock exceptions (Paneer, Onion) + a manual one, resolved; 5 kg paneer transferred Ganj Golai → Ausa Road (stock read back); audit report, compliance task and incident records; PO approval; overview counts 2 branches |
| Staff | employee records for the Ganj Golai logins (linked); 4 Ausa Road employees each with a login (manager, cashier, captain, kitchen); attendance, evening shift + roster, salary advance, leave approved, salaries generated (≥ 6 rows), training module |
| Task Manager | a daily task per branch: start → checklist → submit → verified → completed |
| Integrations | Zomato and Razorpay connection requests, webhook (test delivery, paused), API key (rotated), sync job queued and run (fails honestly: not connected) |
| Finance / CRM | an expense per branch, a Swiggy settlement, customers with their branch |
| Branch managers (Ganj Golai and Ausa Road) | sees exactly one branch; staff, orders and tables are only theirs; the other branch's orders and order pages are refused; chain targets refused (403); can add staff to their branch, cannot add to the other |

The earlier scripts also ran for this restaurant: `business-day.ts` 21 / 21 (`BUSINESS-DAY-2026093017422c5d.md`). `restaurant-day.ts` stopped at its captain step ("That table is not part of your floor plan") because it assumes a fresh restaurant with no tables of its own — its earlier steps (menu, floor, reservation) passed.

## 4. Seen in the app (owner, then Ausa Road manager)

- Menu Catalog grid with the dish photos; Media Hub "Dishes" folder; Raw Materials, Recipes (food cost per dish), Supplier quotes, Purchase Orders (3 open, ₹1,512), Offers (4 live); Task Manager (5 tasks, real assignee names); Compliance & Audit (score 92, open tasks); Exceptions.
- Ausa Road manager sign-in: see §5.

## 5. Ausa Road branch manager in the app

Signed in as `manager2@laturspice.test` (Meera Kale, Branch Manager, home branch Ausa Road):

- Dashboard reads **Ausa Road Outlet** — ₹6,384 sales, 12 settled orders, card / UPI / cash split — only that branch's figures. Sidebar: Master, Operations, Reports, Customers & CRM, Finance, Staff & Users (no chain, marketing, integrations or settings).
- Staff Directory: **7 of 7 staff**, every row's Branch column "Ausa Road Outlet" (Akash Patil, Meera Kale, Rohit Gaikwad, Suresh Pawar and the trainees); Staff & Users has no Roles & Permissions tab for her.
- Dine In: Ausa Road's own floors (Ground Floor, Family Section) and tables T1, T2.
- Signing in as a branch-bound login moves the device to that branch (its synced local data is cleared first, as designed); the owner signing in afterwards keeps the device on Ausa Road, because the account may act for it.

**Found and fixed:** the Staff Management *dashboard* counted the whole restaurant for her (15 employees, ₹2,02,733 payable) while the directory showed 7. Every dashboard figure (staff, online, on shift, attendance, approvals, payroll) now respects the login's branch (`services/staff.ts`, test in `staff.test.ts`).

## 6. Tests

- Backend: 113 / 113 (`staff.test.ts` now checks a branch manager's dashboard counts their branch).
- Flutter end-to-end tests: accounts made in master or in the Staff screen must set their own password on first sign-in (the onboarding change), which covered the shell with the "Set a new password" dialog in the three end-to-end tests. Their sign-in helpers now complete that dialog and reuse the new password afterwards; the two-device test expects the owner to act for the restaurant's oldest branch.

## 7. Left open

- `restaurant-day.ts` needs a fresh restaurant; it was not adapted.
- Compliance & Audit shows "—" for a record's branch until the account's branch list is refreshed by signing in again (the app reads the branch list at sign-in).
- Recipes, suppliers, stock, POs and offers were created through the API (the same calls the screens make), then viewed in the app; the forms themselves were exercised for the menu, tables, reservations, bills and staff logins.
