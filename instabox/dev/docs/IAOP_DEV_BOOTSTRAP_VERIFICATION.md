# PostgreSQL Bootstrap Verification — IAOP DEV

**Date:** 2026-11-14  
**Branch:** `feature/instabox-dev-deployment` (iaop-infrastructure)  
**Environment:** InstaBox machine `iaop-keycloak-dev`

---

## Problem (Pre-fix)

`instabox/dev/initdb/01-databases.sql` used psql variable syntax:

```sql
CREATE USER agent_svc WITH PASSWORD :'agent_pw';
```

Docker's `POSTGRES_INITDB_SCRIPTS` mechanism executes `.sql` files using plain `psql` with no `--variable` flags. The `:agent_pw` syntax expands to an empty string in that context, causing role creation to fail with:

```
ERROR: syntax error at or near ":"
```

The service databases (`agent_db`, `agency_db`, `eligibility_db`, `bff_db`) and their owning roles were therefore never created on a clean start. Services connecting on first boot would fail with `FATAL: role "agent_svc" does not exist`.

**Note:** The existing running database on `iaop-keycloak-dev` was bootstrapped manually and is NOT affected. This fix applies only to clean-start (empty `/data/iaop-dev/postgres`) scenarios.

---

## Fix Applied

**Removed:** `instabox/dev/initdb/01-databases.sql`  
**Added:** `instabox/dev/initdb/01-databases.sh`

The shell script reads passwords from environment variables that Docker Compose now passes through the `db` service:

```bash
AGENT_DB_PASSWORD: ${AGENT_DB_PASSWORD:?set in .env}
AGENCY_DB_PASSWORD: ${AGENCY_DB_PASSWORD:?set in .env}
ELIG_DB_PASSWORD:  ${ELIG_DB_PASSWORD:?set in .env}
BFF_DB_PASSWORD:   ${BFF_DB_PASSWORD:?set in .env}
```

The script is idempotent via `IF NOT EXISTS` guards:

```bash
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agent_svc') THEN
    CREATE USER agent_svc WITH PASSWORD '${AGENT_DB_PASSWORD}';
  END IF;
  ...
END
$$;

SELECT 'CREATE DATABASE agent_db OWNER agent_svc'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'agent_db')
\gexec
```

Each database also receives explicit `GRANT ALL PRIVILEGES` after creation.

---

## Verification Method

This fix cannot be tested against the live running database without destroying the existing data. Verification is structural:

| Check | Status |
|---|---|
| `.sql` file removed from initdb | DONE |
| `.sh` file uses `set -euo pipefail` | DONE |
| Passwords read from env vars (not hardcoded) | DONE |
| All 4 roles created with `IF NOT EXISTS` guards | DONE |
| All 4 databases created with `\gexec` conditional | DONE |
| `GRANT ALL PRIVILEGES` for each pair | DONE |
| Compose `db` service passes all 4 password env vars | DONE |
| `.env` file is gitignored | CONFIRMED (`.gitignore` in initdb dir) |

---

## Expected Behavior on Clean Bootstrap

```
iaop-dev-db  | /docker-entrypoint-initdb.d/01-databases.sh
iaop-dev-db  | DO
iaop-dev-db  | CREATE DATABASE
iaop-dev-db  | CREATE DATABASE
iaop-dev-db  | CREATE DATABASE
iaop-dev-db  | CREATE DATABASE
iaop-dev-db  | GRANT
iaop-dev-db  | GRANT
iaop-dev-db  | GRANT
iaop-dev-db  | GRANT
iaop-dev-db  | IAOP DEV: databases and roles bootstrapped successfully.
```

---

## Impact on Existing Running Database

**NONE.** Docker only runs `POSTGRES_INITDB_SCRIPTS` when the data directory is empty. The existing `/data/iaop-dev/postgres` on the InstaBox machine contains an already-initialized cluster, so this script will never execute against it.

---

## Files Changed

| File | Change |
|---|---|
| `instabox/dev/initdb/01-databases.sql` | REMOVED |
| `instabox/dev/initdb/01-databases.sh` | ADDED (idempotent shell bootstrap) |
| `instabox/dev/compose/docker-compose.yml` | Added 4 password env vars to `db` service |
