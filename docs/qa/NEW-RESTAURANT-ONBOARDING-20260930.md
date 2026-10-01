# New restaurant, end to end — 30 Sep 2026 (evening)

A restaurant created in Proviyaa master, then run from the vendor panel by its owner and its staff. Everything was done through the two web apps in the browser, and each step was read back from the database through the POS API.

**Database:** the one local Postgres (PGlite) that both Proviyaa master (`master-admin-api`, :8000) and the POS backend (:8787) use — the same setup as every earlier QA run. The live Supabase project was not touched. Both services share the JWT secret from their `.env` files, so one login works in both.

Logins for this restaurant are in the git-ignored `backend/.data/laturspice-accounts.txt`.

## 1. Proviyaa master (http://localhost:5173, as the platform super admin)

| Step | Result |
|---|---|
| Organization 360 → Add Partner: **Latur Spice House**, Restaurant, Active | "Created organization" — partner card with 9/9 steps |
| Partner → Add New Location: **Ganj Golai Main Outlet**, Ganj Golai, Latur, code LSH-01, Restaurant, Asia/Kolkata, INR | Location listed (master formats the code as `LOC - LSH 001`) |
| Partner → Create POS Login: Anjali Kulkarni, `owner@laturspice.test`, Owner, All branches | "POS login created" — 1 account |
| Later, after the owner made staff in the vendor panel | Master lists **6 accounts** with role and home branch |

## 2. Owner signs in to the vendor panel (http://localhost:8642)

- The browser still held one unsent change for the previous test restaurant, and the app refused to switch until that restaurant was signed in and synced — the device-binding guard, working as designed. Signed in there, synced, signed out.
- Owner sign-in → sidebar **Latur Spice House**, dashboard **Ganj Golai Main Outlet**, all modules present.
- First sign-in forced **Set a new password** (the temporary password from master no longer works); changed it.
- Branch check: `/v1/auth/me` locations = `Ganj Golai Main Outlet [LOC - LSH 001]`; Branch Performance and Branch Detail show that one branch.

## 3. Master

| Action | UI | Database |
|---|---|---|
| Menu Items → Add Item → "+ Add Category" **Main Course**, **Paneer Tikka Masala** ₹320, Veg, exposed to Dine-In / POS / Takeaway | saved; the form refused to save until a dietary type was ticked | `menu_items`: Paneer Tikka Masala, 320, veg, category Main Course |
| Edit → price 340 | saved | price 340 |
| Second dish (Garlic Naan ₹60) through the API | appears in Products (Online) | — |
| Products (Online), Media, Offers, Inventory, Recipes, Suppliers, Purchase Orders | all open with the restaurant's own (empty) data | — |

## 4. Franchise / Chain

Command Center, Branch Performance, Branch Detail, Inventory & Supply, Exceptions, Targets & Benchmarking, Compliance & Audit all open for the one branch. After the day's orders the Command Center reads ₹903 sales, 2 orders, AOV ₹451.50 (`/v1/franchise/overview` agrees).

## 5. Operations

| Action | UI | Database |
|---|---|---|
| Dine In → + Add Table: **T1** (4 seats, Ground Floor, square) | floor "Ground Floor" appears with T1 at once | `dining_tables` T1, area Ground Floor, branch set |
| + Add Table: **T2** (6 seats, round) | T2 on the floor | T2, 6 seats |
| T1 → Edit Table → 2 seats | Capacity 2 Seats | seats 2 |
| T1 → Reserve Table: Sneha Patil, 98765 43210, 10:30 PM, 2 guests, "Window seat" | T1 **Reserved**, panel shows the guest | `reservations` RSV-101 |
| T1 → Start Ordering → Seat guests (server defaults to the signed-in owner) → Take Order: 1× Paneer Tikka Masala, 2× Garlic Naan → Send to Kitchen (KOT) | T1 **Occupied**, order ₹483 | order `ORD-90A66-9981` dine_in sent_to_kitchen; KOT #1 new; reservation seated |
| KOT / Kitchen: Start Cooking → Mark as Ready | KOT #1 New → Preparing → Ready | KOT status |
| POS Billing → Takeaway: Paneer Tikka Masala + Garlic Naan → Cash → Settle | **Bill #4801 settled · ₹420 · Cash** | `ORD-90A66-9982` pickup paid; payment ₹420 cash completed |
| POS Billing → Open bills → Table 1 → UPI (Google Pay) → Record Payment | **Bill #4802 · payment pending verification** | order awaiting_payment; payment upi pending_verification |
| Branch Manager → Live Operations → Update → Verify Payment (note "UTR 4521 seen in bank app") | order leaves the live list | order paid; payment completed |
| Cashier → Dine In → T1 "Mark Available" | T1 Available (it was Cleaning after the bill) | — |

## 6. Staff & Users (as the owner)

- Roles & permissions → **Seed default roles**: Restaurant Admin (46 screens), Branch Manager (25), Cashier (8), Captain (4), Kitchen (KOT) (1).
- Add New Staff (login form): **Rohan Deshpande** `admin@laturspice.test` Restaurant Admin (ask to change password at first login) and **Priya Sawant** `cashier@laturspice.test` Cashier — both made in the UI.
- Branch Manager (Vikram Jadhav), Captain (Sameer Shinde) and Kitchen (Ganesh Mane) were made through the same `POST /v1/staff/logins` the form calls, to save time.

## 7. Every login, signed in through the app

| Login | Role | What they see | Checked |
|---|---|---|---|
| owner@ | Owner | full vendor panel | everything above |
| admin@ | Restaurant Admin | forced password change, then the full panel; dashboard shows ₹420 sales and ₹483 pending verification | `/auth/me` 46 screens |
| manager@ | Branch Manager | Dashboard, Master, Operations, Customers & CRM, Finance, Staff & Users — no Franchise / Marketing / Integrations / Settings | verified the UPI payment (25 screens) |
| cashier@ | Cashier | POS shell: POS, Tables, All Orders, Dine In, Takeaway, Delivery, Online, Menu | marked T1 available (8 screens) |
| captain@ | Captain | POS shell: POS, Tables, All Orders, Dine In | 4 screens |
| kitchen@ | Kitchen (KOT) | Kitchen Display only, showing KOT #2 for the takeaway | 1 screen |

## 8. Found and fixed

1. **Menu Catalog did not refresh after Add / Edit** (web). The dish saved (database confirmed) but the list kept showing the old state until the page was reopened. Fix: the screen re-reads the dishes when the editor closes, and if its database stream ever fails it re-reads once and listens again (`master_menu_items_screen.dart`, `master_products_online_screen.dart`).
2. **"Load Spicy Bistro Catalog" was offered to a live restaurant.** The empty-catalog page showed the demo-catalog button even in backend mode. It is now local-demo only (`allowDemoSeed`).
3. **Chain pages showed sign-in-time figures.** The Command Center read ₹0 sales while the API already had ₹420: chain data was fetched at sign-in only. Opening any Franchise / Chain page (or the dashboard) now fetches it again (`main.dart`).

## 9. Not covered in this run

- Delivery, Online Orders and QR Ordering were not exercised for this restaurant (checked in earlier runs).
- Suppliers, purchase orders, recipes and offers were opened but no records were created for this restaurant.
- The vendor panel was used in the browser pane at 1440×900; Windows/Android builds remain blocked by the toolchain.
