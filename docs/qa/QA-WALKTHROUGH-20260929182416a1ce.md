# QA walkthrough — 2026-09-29T18:24:19.305Z

Backend: http://localhost:8787 · run 20260929182416a1ce · 193 checks · 193 passed · 0 failed

| Section | Check | Expected | Actual | Result |
|---|---|---|---|---|
| Platform | backend health | ok | 200 | PASS |
| Owner | signs in with the master-admin account | role org_owner | org_owner | PASS |
| Owner | lands in the vendor panel | vendor | vendor | PASS |
| Owner | gets every vendor screen | all | all | PASS |
| Owner | has a branch (created in master-admin) | a branch | QA Branch 202609290732 | PASS |
| Staff setup | seed default staff roles | 2xx | 200 | PASS |
| Staff setup | add employee + login as Restaurant Admin (org_admin) | 2xx | 201 | PASS |
| Staff setup | add employee + login as Branch Manager (location_manager) | 2xx | 201 | PASS |
| Staff setup | add employee + login as Cashier (biller) | 2xx | 201 | PASS |
| Staff setup | add employee + login as Captain (captain) | 2xx | 201 | PASS |
| Staff setup | add employee + login as Kitchen (KOT) (kitchen) | 2xx | 201 | PASS |
| Setup | menu category for QA | 2xx | 201 | PASS |
| Setup | menu item for QA | 2xx | 201 | PASS |
| Setup | order for a verify-payment check | 2xx | 201 | PASS |
| Role org_admin | signs in and is resolved to its role | org_admin | org_admin | PASS |
| Role org_admin | opens the right app | vendor | vendor | PASS |
| Role org_admin | gets exactly its role screens | 37 screens | 37 screens | PASS |
| Role org_admin | branch scope | all branches | 7 branch(es) | PASS |
| Role org_admin | franchise overview | allowed | 200 | PASS |
| Role org_admin | read menu | allowed | 200 | PASS |
| Role org_admin | create menu category | allowed | 201 | PASS |
| Role org_admin | list orders | allowed | 200 | PASS |
| Role org_admin | take an order | allowed | 201 | PASS |
| Role org_admin | kitchen queue | allowed | 200 | PASS |
| Role org_admin | take a cash payment | allowed | 201 | PASS |
| Setup | order for a verify-payment check | 2xx | 201 | PASS |
| Role org_admin | verify a UPI payment | allowed | 200 | PASS |
| Role org_admin | staff directory | allowed | 200 | PASS |
| Role org_admin | salaries | allowed | 200 | PASS |
| Role org_admin | attendance | allowed | 200 | PASS |
| Role org_admin | staff roles | allowed | 200 | PASS |
| Role org_admin | login security | allowed | 200 | PASS |
| Role org_admin | audit log | allowed | 200 | PASS |
| Role org_admin | sync pull (menu + orders) | allowed | 200 | PASS |
| Role org_admin | cannot open another restaurant | 403 | 403 | PASS |
| Role org_admin | signed-out token is refused | 401 | 401 | PASS |
| Role location_manager | signs in and is resolved to its role | location_manager | location_manager | PASS |
| Role location_manager | opens the right app | vendor | vendor | PASS |
| Role location_manager | gets exactly its role screens | 22 screens | 22 screens | PASS |
| Role location_manager | branch scope | own branch only | 1 branch(es) | PASS |
| Role location_manager | franchise overview | refused (403) | 403 forbidden | PASS |
| Role location_manager | read menu | allowed | 200 | PASS |
| Role location_manager | create menu category | allowed | 201 | PASS |
| Role location_manager | list orders | allowed | 200 | PASS |
| Role location_manager | take an order | allowed | 201 | PASS |
| Role location_manager | kitchen queue | allowed | 200 | PASS |
| Role location_manager | take a cash payment | allowed | 201 | PASS |
| Setup | order for a verify-payment check | 2xx | 201 | PASS |
| Role location_manager | verify a UPI payment | allowed | 200 | PASS |
| Role location_manager | staff directory | allowed | 200 | PASS |
| Role location_manager | salaries | refused (403) | 403 forbidden | PASS |
| Role location_manager | attendance | allowed | 200 | PASS |
| Role location_manager | staff roles | allowed | 200 | PASS |
| Role location_manager | login security | allowed | 200 | PASS |
| Role location_manager | audit log | refused (403) | 403 forbidden | PASS |
| Role location_manager | sync pull (menu + orders) | allowed | 200 | PASS |
| Role location_manager | cannot open another restaurant | 403 | 403 | PASS |
| Role location_manager | signed-out token is refused | 401 | 401 | PASS |
| Role biller | signs in and is resolved to its role | biller | biller | PASS |
| Role biller | opens the right app | pos | pos | PASS |
| Role biller | gets exactly its role screens | 8 screens | 8 screens | PASS |
| Role biller | branch scope | own branch only | 1 branch(es) | PASS |
| Role biller | franchise overview | refused (403) | 403 forbidden | PASS |
| Role biller | read menu | allowed | 200 | PASS |
| Role biller | create menu category | refused (403) | 403 forbidden | PASS |
| Role biller | list orders | allowed | 200 | PASS |
| Role biller | take an order | allowed | 201 | PASS |
| Role biller | kitchen queue | allowed | 200 | PASS |
| Role biller | take a cash payment | allowed | 201 | PASS |
| Role biller | verify a UPI payment | refused (403) | 403 forbidden | PASS |
| Role biller | staff directory | refused (403) | 403 forbidden | PASS |
| Role biller | salaries | refused (403) | 403 forbidden | PASS |
| Role biller | attendance | refused (403) | 403 forbidden | PASS |
| Role biller | staff roles | refused (403) | 403 forbidden | PASS |
| Role biller | login security | refused (403) | 403 forbidden | PASS |
| Role biller | audit log | refused (403) | 403 forbidden | PASS |
| Role biller | sync pull (menu + orders) | allowed | 200 | PASS |
| Role biller | cannot open another restaurant | 403 | 403 | PASS |
| Role biller | signed-out token is refused | 401 | 401 | PASS |
| Role captain | signs in and is resolved to its role | captain | captain | PASS |
| Role captain | opens the right app | pos | pos | PASS |
| Role captain | gets exactly its role screens | 4 screens | 4 screens | PASS |
| Role captain | branch scope | own branch only | 1 branch(es) | PASS |
| Role captain | franchise overview | refused (403) | 403 forbidden | PASS |
| Role captain | read menu | allowed | 200 | PASS |
| Role captain | create menu category | refused (403) | 403 forbidden | PASS |
| Role captain | list orders | allowed | 200 | PASS |
| Role captain | take an order | allowed | 201 | PASS |
| Role captain | kitchen queue | allowed | 200 | PASS |
| Role captain | take a cash payment | refused (403) | 403 forbidden | PASS |
| Role captain | verify a UPI payment | refused (403) | 403 forbidden | PASS |
| Role captain | staff directory | refused (403) | 403 forbidden | PASS |
| Role captain | salaries | refused (403) | 403 forbidden | PASS |
| Role captain | attendance | refused (403) | 403 forbidden | PASS |
| Role captain | staff roles | refused (403) | 403 forbidden | PASS |
| Role captain | login security | refused (403) | 403 forbidden | PASS |
| Role captain | audit log | refused (403) | 403 forbidden | PASS |
| Role captain | sync pull (menu + orders) | allowed | 200 | PASS |
| Role captain | cannot open another restaurant | 403 | 403 | PASS |
| Role captain | signed-out token is refused | 401 | 401 | PASS |
| Role kitchen | signs in and is resolved to its role | kitchen | kitchen | PASS |
| Role kitchen | opens the right app | pos | pos | PASS |
| Role kitchen | gets exactly its role screens | 1 screens | 1 screens | PASS |
| Role kitchen | branch scope | own branch only | 1 branch(es) | PASS |
| Role kitchen | franchise overview | refused (403) | 403 forbidden | PASS |
| Role kitchen | read menu | allowed | 200 | PASS |
| Role kitchen | create menu category | refused (403) | 403 forbidden | PASS |
| Role kitchen | list orders | allowed | 200 | PASS |
| Role kitchen | take an order | refused (403) | 403 forbidden | PASS |
| Role kitchen | kitchen queue | allowed | 200 | PASS |
| Role kitchen | take a cash payment | refused (403) | 403 forbidden | PASS |
| Role kitchen | verify a UPI payment | refused (403) | 403 forbidden | PASS |
| Role kitchen | staff directory | refused (403) | 403 forbidden | PASS |
| Role kitchen | salaries | refused (403) | 403 forbidden | PASS |
| Role kitchen | attendance | refused (403) | 403 forbidden | PASS |
| Role kitchen | staff roles | refused (403) | 403 forbidden | PASS |
| Role kitchen | login security | refused (403) | 403 forbidden | PASS |
| Role kitchen | audit log | refused (403) | 403 forbidden | PASS |
| Role kitchen | sync pull (menu + orders) | allowed | 200 | PASS |
| Role kitchen | cannot open another restaurant | 403 | 403 | PASS |
| Role kitchen | signed-out token is refused | 401 | 401 | PASS |
| Branches | owner opens a second branch | 2xx | 201 | PASS |
| Branches | cashier cannot read the other branch's orders | 403 | 403 | PASS |
| Branches | cashier cannot list the other branch's orders by filter | 403 | 403 | PASS |
| Branches | owner can open the second branch | ok | 200 | PASS |
| CRUD Master | create menu item | 2xx | 201 | PASS |
| CRUD Master | update menu item price | 2xx | 200 | PASS |
| CRUD Master | price saved | 340 | 340 | PASS |
| CRUD Master | read menu item | 2xx | 200 | PASS |
| CRUD Master | delete menu item | 204 | 204 | PASS |
| CRUD Master | create raw material | 2xx | 200 | PASS |
| CRUD Master | list raw materials | 2xx | 200 | PASS |
| CRUD Master | raw material listed | present | present | PASS |
| CRUD Master | update stock (upsert same key) | 2xx | 200 | PASS |
| CRUD Master | create supplier | 2xx | 200 | PASS |
| CRUD Master | delete raw material | 204 | 204 | PASS |
| CRUD Operations | create dining area | 2xx | 201 | PASS |
| CRUD Operations | create table | 2xx | 201 | PASS |
| CRUD Operations | update table seats | 2xx | 200 | PASS |
| CRUD Operations | place a dine-in order | 2xx | 201 | PASS |
| CRUD Operations | menu price used (client cannot set it) | ₹300 subtotal | ₹300 | PASS |
| CRUD Operations | kitchen queue shows the KOT | 2xx | 200 | PASS |
| CRUD Operations | KOT created with the order | present | new | PASS |
| CRUD Operations | advance KOT | 2xx | 200 | PASS |
| CRUD Operations | KOT moved forward | preparing | preparing | PASS |
| CRUD Operations | "paid" cannot be set by a status change | 409 | 409 | PASS |
| CRUD Operations | overpayment refused | 422 | 422 | PASS |
| CRUD Operations | cash payment settles | 2xx | 201 | PASS |
| CRUD Operations | order paid by cash | paid | paid | PASS |
| Setup | order for a verify-payment check | 2xx | 201 | PASS |
| CRUD Operations | UPI order detail | 2xx | 200 | PASS |
| CRUD Operations | UPI waits for verification | awaiting_payment | awaiting_payment | PASS |
| CRUD Operations | owner verifies UPI | 2xx | 200 | PASS |
| CRUD Operations | verified order is paid | paid | paid | PASS |
| CRUD Operations | cashier device uploads a UPI order | 2xx | 200 | PASS |
| CRUD Operations | device upload accepted | accepted,accepted,accepted | accepted,accepted,accepted | PASS |
| CRUD Operations | branch manager verifies it by its POS id | 2xx | 200 | PASS |
| CRUD Operations | device order paid on the server | paid | paid | PASS |
| CRUD Operations | cashier's device sees it settled | settled | settled | PASS |
| CRUD Operations | order to cancel | 2xx | 201 | PASS |
| CRUD Operations | cancel an order | 2xx | 200 | PASS |
| CRUD Operations | order cancelled | cancelled | cancelled | PASS |
| CRUD Operations | day summary | 2xx | 200 | PASS |
| CRUD Operations | summary counts orders | > 0 | 217 | PASS |
| CRUD Operations | create reservation | 2xx | 200 | PASS |
| CRUD Franchise | overview | 2xx | 200 | PASS |
| CRUD Franchise | branch performance | 2xx | 200 | PASS |
| CRUD Franchise | both branches listed | ≥ 2 | 8 | PASS |
| CRUD Franchise | inventory across branches | 2xx | 200 | PASS |
| CRUD Franchise | log an audit record | 2xx | 201 | PASS |
| CRUD Franchise | list records | 2xx | 200 | PASS |
| CRUD Franchise | record listed | present | present | PASS |
| CRUD Franchise | set a branch target | 2xx | 201 | PASS |
| CRUD Franchise | generate exceptions | 2xx | 201 | PASS |
| CRUD Staff | staff directory | 2xx | 200 | PASS |
| CRUD Staff | every QA login is an employee | 5+ | 132 | PASS |
| CRUD Staff | staff dashboard | 2xx | 200 | PASS |
| CRUD Staff | mark all present | 2xx | 200 | PASS |
| CRUD Staff | record salary advance | 2xx | 201 | PASS |
| CRUD Staff | generate salaries | 2xx | 200 | PASS |
| CRUD Staff | create shift | 2xx | 201 | PASS |
| CRUD Staff | assign shift | 2xx | 201 | PASS |
| CRUD Staff | clock in | 2xx | 200 | PASS |
| CRUD Staff | leave request | 2xx | 201 | PASS |
| CRUD Staff | approve leave | 2xx | 200 | PASS |
| CRUD Staff | create training module | 2xx | 201 | PASS |
| CRUD Staff | take the test | 2xx | 201 | PASS |
| CRUD Staff | test passed | passed | passed | PASS |
| CRUD Staff | reports | 2xx | 200 | PASS |
| CRUD Staff | audit log | 2xx | 200 | PASS |
| CRUD Staff | audit log records actions | > 0 | 300 | PASS |
| Session | owner signs out | 204 | 204 | PASS |
| Session | signed-out token is refused | 401 | 401 | PASS |
