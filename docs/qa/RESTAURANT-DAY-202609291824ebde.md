# Restaurant day — 2026-09-29T18:24:20.713Z

Backend: http://localhost:8787 · restaurant: Proviyaa QA Kitchen · branch: QA Branch 202609290732 · run 202609291824ebde · 22 steps · 22 passed · 0 failed

Each step is done by the role that does it in the restaurant; every write is read back through the API (the data stays in the database).

| Who | What | Saved | Checked | Result |
|---|---|---|---|---|
| Owner | menu: 5 dishes in "House Specials" | Veg Biryani ₹220, Paneer Butter Masala ₹260, Butter Naan ₹45, Masala Chai ₹30, Chicken Tikka ₹280 | read back from /master/menu-items with the same prices | PASS |
| Owner | stock: 3 raw materials (Paneer below reorder level) | Basmati Rice 25kg, Paneer 3kg, Milk 20L | read back from /master/raw-materials | PASS |
| Owner | supplier: Latur Fresh Dairy | day-sup-dairy | read back from /master/suppliers | PASS |
| Owner | floor: Main Hall with T1–T4 at QA Branch 202609290732 | 815be7ef, 1162c17e, 9954ab4f, c27e5590 | read back from /operations/dining-tables | PASS |
| Owner | reservation: Mehta family, 5 guests, tomorrow | day-res-202609291824ebde | read back from /operations/reservations | PASS |
| Captain | order at T1 (3 lines) | ORD-244 · ₹698.25 | stored with status sent_to_kitchen and 1 KOT | PASS |
| Captain | order at T2 (3 lines) | ORD-245 · ₹661.50 | stored with status sent_to_kitchen and 1 KOT | PASS |
| Captain | tries to take the cash for T1 | — | refused with 403 (the cashier collects money) | PASS |
| Chef | KOT for T1: start cooking → ready | 7a71f8fe | stored as ready | PASS |
| Chef | KOT for T2: start cooking → ready | 5c72f638 | stored as ready | PASS |
| Chef | tries to place an order | — | refused with 403 | PASS |
| Cashier | T1 paid in cash | ₹698.25 | order stored as paid | PASS |
| Cashier | the same payment sent twice (network retry) | — | answer 200; 1 payment stored | PASS |
| Cashier | T2 paid by UPI | ₹661.50 | order stored as awaiting_payment (pending verification) | PASS |
| Cashier | takeaway for Walk-in Ravi paid by card | ₹294.00 | stored as awaiting_payment | PASS |
| Cashier | cancels an order the guest walked out on | df845d42 | stored as cancelled | PASS |
| Cashier | tries to verify the UPI | — | refused with 403 | PASS |
| Branch Manager | verifies T2 UPI against the statement | 226bdc8b | stored as paid | PASS |
| Branch Manager | verifies the card payment | cc2ae16e | stored as paid | PASS |
| Branch Manager | the UPI order history | placed → kot → kot → payment_pending_verification → payment_verified | records pending verification and who verified | PASS |
| Branch Manager | attendance for 2026-09-29: mark all present | 102 of 102 present | read back from /staff/attendance | PASS |
| Owner | end-of-day summary | 220 orders · ₹18527.25 sales today | includes this run's ₹1653.75 | PASS |
