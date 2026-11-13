#!/usr/bin/env bash
# Restore Keycloak Postgres from a logical dump. DESTRUCTIVE — confirm first.
set -euo pipefail
DUMP=${1:?usage: restore.sh <backup.sql.gz>}
read -r -p "This DROPS and recreates the keycloak DB. Type RESTORE: " ans
[ "$ans" = "RESTORE" ] || { echo aborted; exit 1; }
gunzip -c "$DUMP" | docker exec -i iaop-keycloak-db psql -U keycloak_app -d postgres -c "DROP DATABASE IF EXISTS keycloak;" -c "CREATE DATABASE keycloak OWNER keycloak_app;"
gunzip -c "$DUMP" | docker exec -i iaop-keycloak-db psql -U keycloak_app -d keycloak
 docker restart iaop-keycloak
echo "restore complete — verify with verify steps"
