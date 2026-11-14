#!/usr/bin/env bash
# IAOP DEV — Idempotent database bootstrap
# Docker runs this script on first PostgreSQL init (empty data dir).
# It is NOT re-run on subsequent container restarts.
#
# Required env vars (set in docker-compose.yml db service):
#   AGENT_DB_PASSWORD   AGENCY_DB_PASSWORD   ELIG_DB_PASSWORD   BFF_DB_PASSWORD
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL

  -- ── Idempotent role creation ────────────────────────────────────
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agent_svc') THEN
      CREATE USER agent_svc WITH PASSWORD '${AGENT_DB_PASSWORD}';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agency_svc') THEN
      CREATE USER agency_svc WITH PASSWORD '${AGENCY_DB_PASSWORD}';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'elig_svc') THEN
      CREATE USER elig_svc WITH PASSWORD '${ELIG_DB_PASSWORD}';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bff_svc') THEN
      CREATE USER bff_svc WITH PASSWORD '${BFF_DB_PASSWORD}';
    END IF;
  END
  \$\$;

  -- ── Idempotent database creation ────────────────────────────────
  SELECT 'CREATE DATABASE agent_db OWNER agent_svc'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'agent_db')
  \gexec

  SELECT 'CREATE DATABASE agency_db OWNER agency_svc'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'agency_db')
  \gexec

  SELECT 'CREATE DATABASE eligibility_db OWNER elig_svc'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'eligibility_db')
  \gexec

  SELECT 'CREATE DATABASE bff_db OWNER bff_svc'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'bff_db')
  \gexec

EOSQL

# GRANT ALL PRIVILEGES must run once each database exists.
# psql -d <db> is needed here since GRANT runs in the target database context.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "agent_db" \
  -c "GRANT ALL PRIVILEGES ON DATABASE agent_db TO agent_svc;"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "agency_db" \
  -c "GRANT ALL PRIVILEGES ON DATABASE agency_db TO agency_svc;"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "eligibility_db" \
  -c "GRANT ALL PRIVILEGES ON DATABASE eligibility_db TO elig_svc;"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "bff_db" \
  -c "GRANT ALL PRIVILEGES ON DATABASE bff_db TO bff_svc;"

echo "IAOP DEV: databases and roles bootstrapped successfully."
