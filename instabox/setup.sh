#!/usr/bin/env bash
# Idempotent IAOP Keycloak setup — run ON the instabox machine.
# Safe to re-run: secrets are generated once, realm import is skipped
# when the realm exists, users are never deleted or reset.
set -euo pipefail

BASE=/data/iaop-keycloak
COMPOSE_DIR=$BASE/compose
SECRETS=$BASE/secrets.env
mkdir -p "$COMPOSE_DIR" "$BASE/backups" "$BASE/reports"
chmod 700 "$BASE"

# --- secrets (generated once, never printed) -------------------------------
if [ ! -f "$SECRETS" ]; then
  {
    echo "KC_DB_PASSWORD=$(openssl rand -hex 24)"
    echo "KC_ADMIN_USER=iaop-admin"
    echo "KC_ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -d '=+/')Aa1!"
    echo "E2E_USER_PASSWORD=$(openssl rand -base64 18 | tr -d '=+/')Aa1!"
  } > "$SECRETS"
  chmod 600 "$SECRETS"
  echo "secrets.env generated"
else
  echo "secrets.env exists — keeping existing credentials"
fi
set -a; . "$SECRETS"; set +a

# --- public URL (published port) -------------------------------------------
if [ -z "${KC_PUBLIC_URL:-}" ]; then
  echo "KC_PUBLIC_URL not set — publish the edge port first, then re-run with it." >&2
  exit 2
fi
echo "KC_PUBLIC_URL=$KC_PUBLIC_URL" >> "$SECRETS"
export KC_PUBLIC_URL

cd "$COMPOSE_DIR"
docker compose up -d

# wait for keycloak health (management port inside container)
echo "waiting for keycloak..."
for i in $(seq 1 60); do
  if docker exec iaop-keycloak test -f /tmp/.kc-healthy 2>/dev/null; then break; fi
  code=$(docker exec iaop-keycloak curl -sf -o /dev/null -w '%{http_code}' http://127.0.0.1:9000/health/ready 2>/dev/null || true)
  [ "$code" = "200" ] && break
  sleep 5
done

# --- realm import (idempotent) ----------------------------------------------
KC="docker exec iaop-keycloak /opt/keycloak/bin/kcadm.sh"
$KC config credentials --server http://127.0.0.1:8080 --realm master \
  --user "$KC_ADMIN_USER" --password "$KC_ADMIN_PASSWORD" >/dev/null

if $KC get realms/iaop-dev >/dev/null 2>&1; then
  echo "realm iaop-dev exists — skipping import"
else
  $KC create realms -f /tmp/realm-iaop-dev.json && echo "realm iaop-dev imported"
fi

# --- synthetic E2E user (dev only; password in secrets.env) ------------------
if ! $KC get "users?username=e2e-agent-admin&exact=true" 2>/dev/null | grep -q '"id"'; then
  $KC create users -r iaop-dev -s username=e2e-agent-admin -s enabled=true \
    -s emailVerified=true -s "firstName=E2E" -s "lastName=AgentAdmin" \
    -s "credentials=[{\"type\":\"password\",\"value\":\"$E2E_USER_PASSWORD\",\"temporary\":false}]" \
    && echo "e2e-agent-admin created"
fi
# grant realm role + agent-api client roles
docker exec iaop-keycloak bash -c '
set -e
KC=/opt/keycloak/bin/kcadm.sh
UID=$($KC get "users?username=e2e-agent-admin&exact=true" -r iaop-dev --fields id --format csv --noquotes)
CID=$($KC get clients -r iaop-dev -q clientId=iaop-agent-api --fields id --format csv --noquotes)
$KC update "users/$UID/role-mappings/realm" -r iaop-dev -b "[{\"id\":\"'$($KC get roles/IAOP_PLATFORM_ADMIN -r iaop-dev --fields id --format csv --noquotes)'\",\"name\":\"IAOP_PLATFORM_ADMIN\"}]" 2>/dev/null || true
for p in agent:read agent:create agent:update agent:activate agent:suspend agent:reinstate agent:terminate agent:history:read agent:identity:link; do
  RID=$($KC get "clients/$CID/roles/$p" -r iaop-dev --fields id --format csv --noquotes)
  $KC create "users/$UID/role-mappings/clients/$CID" -r iaop-dev -b "[{\"id\":\"$RID\",\"name\":\"$p\"}]" || true
done
' && echo "e2e-agent-admin roles assigned"

echo "SETUP COMPLETE"
echo "issuer: $KC_PUBLIC_URL/realms/iaop-dev"
