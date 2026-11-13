#!/usr/bin/env bash
# Logical backup of Keycloak Postgres + realm export. Run ON the box.
set -euo pipefail
BASE=/data/iaop-keycloak
TS=$(date +%Y%m%d-%H%M%S)
OUT=$BASE/backups/keycloak-$TS.sql.gz
mkdir -p "$OUT.d" 2>/dev/null || true
docker exec iaop-keycloak-db pg_dump -U keycloak_app -d keycloak | gzip > "$OUT"
# realm export via admin API (kcadm session required; uses admin creds from secrets.env)
. /data/iaop-keycloak/secrets.env
docker exec iaop-keycloak /opt/keycloak/bin/kcadm.sh config credentials --server http://127.0.0.1:8080 --realm master --user "$KC_ADMIN_USER" --password "$KC_ADMIN_PASSWORD" >/dev/null 2>&1 || true
docker exec iaop-keycloak /opt/keycloak/bin/kcadm.sh get realms/iaop-dev -r iaop-dev > "$BASE/backups/realm-iaop-dev-$TS.json" || true
echo "backup written: $OUT (+ realm json)"
ls -lh "$BASE/backups" | tail -5
