# Dev database sync (QuickBill)

Production is the **source of truth**. Use these scripts to refresh a **local or dedicated dev** Postgres database, then normalize financial fields so History / dashboards match reality.

**Never** point `DEV_DATABASE_URL` at production. Restore refuses to run if dev and prod resolve to the same host + port + database name.

---

## Requirements

- **PostgreSQL client tools** on `PATH`: `pg_dump`, `psql`
- **Node.js** (same as the server project)
- **Environment variables** (shell, `.env.local`, or CI secrets — do not commit secrets)

| Variable | Used by |
|----------|---------|
| `PROD_DATABASE_URL` | `dump`, `restore` (safety compare), `sync` |
| `DEV_DATABASE_URL` | `restore`, `normalize`, `sync` |

Connection strings: `postgresql://user:password@host:port/dbname` (or `postgres://`).

Optional: place `PROD_DATABASE_URL` / `DEV_DATABASE_URL` in `quickbill-server/.env.local`; `db-cli.mjs` loads **`quickbill-server`** via `dotenv-flow` (same as the app).

---

## Commands (from `quickbill-server/`)

```bash
npm run db:dump:prod
npm run db:restore:dev
npm run db:normalize:dev
npm run db:sync:dev
```

`db:sync:dev` runs, in order:

1. `[1/3]` Dump production → `scripts/db/backups/prod_dump_YYYYMMDD_HHMMSS.sql`
2. `[2/3]` Restore **latest** dump into dev (`DROP SCHEMA public CASCADE` + `CREATE SCHEMA public` on **dev only**, then load SQL)
3. `[3/3]` Run `normalize-dev.sql` on dev

---

## Shell / PowerShell (optional)

From repository root, after `cd quickbill-server`:

**Bash (macOS / Linux / Git Bash)**

```bash
bash scripts/db/dump-prod.sh
bash scripts/db/restore-dev.sh
bash scripts/db/normalize-dev.sh
bash scripts/db/sync-dev.sh
```

**PowerShell (Windows)**

```powershell
.\scripts\db\dump-prod.ps1
.\scripts\db\restore-dev.ps1
.\scripts\db\normalize-dev.ps1
.\scripts\db\sync-dev.ps1
```

---

## Expected flow after a sync

1. Run `npm run db:sync:dev` (with env vars set).
2. Start backend (`npm run dev` in `quickbill-server`).
3. Start frontend.
4. Verify **History** (paid / outstanding), **dashboard** totals, and **payment_status** on documents (green / orange in UI).

---

## Safety warnings

- **Restore wipes `public` on the database behind `DEV_DATABASE_URL`.** All data in that schema is replaced.
- If **`DEV_DATABASE_URL` equals `PROD_DATABASE_URL`**, or matches the same **host + port + database name** as prod, the script **exits with an error** and does nothing.
- Dumps under `scripts/db/backups/` may contain **PII**; they are gitignored — do not commit them.

---

## Troubleshooting

### Restore safety check failed

- You may have copied prod URL into dev by mistake. Use a **different** database name or host for dev (e.g. local Postgres, Supabase branch, Railway dev instance).
- Ensure `PROD_DATABASE_URL` is set during **restore** so the tool can compare targets.

### After sync, everything looks **unpaid**

- `normalize-dev.sql` sets `payment_status` from **`paid_amount`**: if prod rows have `paid_amount = 0` but were marked paid only in legacy fields, run a manual SQL fix or align `paid_amount` in prod before dump.
- Confirm migration / constraints did not block updates (see server logs / `psql` errors).

### History vs dashboard mismatch

- Hard refresh the app; confirm the API points at the **dev** server that uses **`DEV_DATABASE_URL`**.
- Re-run `npm run db:normalize:dev` if you restored without step 3.

### `pg_dump` / `psql` not found

- Install [PostgreSQL client tools](https://www.postgresql.org/download/) and ensure they are on `PATH`, or use the full path in a wrapper script (local only).

---

## Implementation note

Core logic lives in **`db-cli.mjs`** (cross-platform). The `.sh` / `.ps1` files are thin wrappers that `cd` to `quickbill-server` and invoke the same CLI.
