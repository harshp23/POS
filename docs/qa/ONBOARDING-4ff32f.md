# Onboarding flow - 2026-09-30T16:23:17.758Z

Run 4ff32f - local database, POS backend and master-admin on one shared JWT secret - 40 steps, 40 passed, 0 failed

| Who | What | Checked | Result |
|---|---|---|---|
| Platform admin | signs in to Proviyaa master | token issued | PASS |
| Platform admin | creates the restaurant | Saffron Table 4ff32f (a0d89f59) | PASS |
| Platform admin | adds its first branch | Saffron Indiranagar | PASS |
| Platform admin | invites the owner (temporary password) | owner+4ff32f@saffron.test as org_owner | PASS |
| Owner | wrong password is refused | status 401 | PASS |
| Owner | signs in with the invited password | Saffron Table 4ff32f, role org_owner | PASS |
| Owner | is told to choose their own password | must_change_password = true | PASS |
| Owner | sees the full screen catalogue | 46 screens | PASS |
| Owner | a weak new password is refused | status 400 | PASS |
| Owner | the invited password stops working | status 401 | PASS |
| Owner | signs in with the new password | must_change_password = false | PASS |
| Owner | lands in their own restaurant and branch | Saffron Table 4ff32f / Saffron Indiranagar | PASS |
| Owner | API refuses a request with no token | status 401 | PASS |
| Owner | gets the standard staff roles | Restaurant Admin, Branch Manager, Cashier, Captain, Kitchen (KOT) | PASS |
| Owner | creates a Restaurant Admin login | admin+4ff32f@saffron.test (status 201) | PASS |
| Owner | creates a Branch Manager login | manager+4ff32f@saffron.test (status 201) | PASS |
| Owner | creates a Cashier login | cashier+4ff32f@saffron.test (status 201) | PASS |
| Owner | creates a Captain login | captain+4ff32f@saffron.test (status 201) | PASS |
| Owner | creates a Kitchen login | kitchen+4ff32f@saffron.test (status 201) | PASS |
| Owner | sees the team in the staff directory | 6 logins | PASS |
| Restaurant Admin | signs in, is asked for a new password, then signs in again | Saffron Table 4ff32f, org_admin, 46 screens | PASS |
| Branch Manager | signs in, is asked for a new password, then signs in again | Saffron Table 4ff32f, location_manager, 25 screens | PASS |
| Cashier | signs in, is asked for a new password, then signs in again | Saffron Table 4ff32f, biller, 8 screens | PASS |
| Captain | signs in, is asked for a new password, then signs in again | Saffron Table 4ff32f, captain, 4 screens | PASS |
| Kitchen | signs in, is asked for a new password, then signs in again | Saffron Table 4ff32f, kitchen, 1 screens | PASS |
| Roles | kitchen sees fewer screens than the cashier, the cashier fewer than the owner | kitchen 1, cashier 8, owner 46 | PASS |
| Owner | builds the menu | Veg Biryani 220, Butter Naan 45, Masala Chai 30 | PASS |
| Owner | lays out the floor | Main Hall with T1 | PASS |
| Owner | stocks inventory | Basmati Rice 25 kg | PASS |
| Captain | takes a table order | 2 lines, status sent_to_kitchen | PASS |
| Captain | cannot take money | status 403 | PASS |
| Kitchen | sees the KOT and marks it ready | status ready | PASS |
| Kitchen | cannot place orders | status 403 | PASS |
| Cashier | collects the cash payment | order paid | PASS |
| Cashier | takes a takeaway paid by UPI | order awaiting_payment | PASS |
| Cashier | cannot verify UPI | status 403 | PASS |
| Branch Manager | verifies the UPI payment | order paid | PASS |
| Restaurant Admin | reads the day summary | 2 orders, 71400 minor units | PASS |
| Second restaurant | cannot see the first restaurant's menu or orders | 0 menu items; order lookup status 404 | PASS |
| Platform admin | suspends the cashier: they can no longer sign in | status 403 | PASS |
