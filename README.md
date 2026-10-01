# Proviyaa POS

Separate Restaurant POS product for the Proviyaa ecosystem. It consumes the OS-owned central Supabase PostgreSQL system and does not create a second cloud database.

Read `docs/PREFLIGHT.txt`, `docs/SOURCE-MANIFEST.txt`, `docs/PRD-DAY-03-RESTAURANT-POS.txt`, `docs/DECISIONS-AND-QUESTIONS.txt` and `docs/EXISTING-DATABASE-MAP.txt` first.

Architecture: Flutter presentation → commands/domain rules → device-local SQLite (Drift) → CloudSyncService → **Proviyaa backend (`backend/`)** → central PostgreSQL (Supabase).

The repository has three parts:

- `lib/`: the Flutter POS and restaurant vendor panel.
- `backend/`: the POS backend.
- `master-admin/`: the Proviyaa master panel, where platform admins onboard restaurants, branches and POS accounts.

They share one database and one set of accounts (master-admin's `users`). Both backends issue the same JWT, so one login works in the master panel and in the POS.

Restaurants manage their own people in **Staff & Users** (employees, app logins, roles, attendance, shifts, salary, approvals, training). Each login's role decides what the app opens. The owner and admins get the whole vendor panel, managers get operations, a cashier gets only POS billing, and the kitchen gets only the kitchen display. The backend enforces the same rules.

The app never calls Supabase. The backend is the only component with database access, and it enforces each restaurant's data boundary on every query.

See `backend/README.md` for the Franchise/Chain, Master, Operations and Sync services, and `docs/LOCAL-DEVELOPMENT.txt` to run the whole platform locally. One-time database setup: run `supabase/RUN-IN-SUPABASE.sql` in the Supabase SQL editor.

Local credentials: copy `.env.local.example` to `.env.local` and run `./tool/run_local.ps1` (or `.sh`). The launcher passes the allowlisted values as `--dart-define` flags. Never add a Supabase key, service-role key or database password to the app. Figma remains the UI authority.
