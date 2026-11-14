# Swagger OAuth Verification — IAOP DEV

**Date:** 2026-11-14  
**Docs portal:** `https://8083-agq5lpbszgbva3ygddcbarv6ea.instabox.tech`  
**BFF public URL:** `https://8082-agq5lpbszgbva3ygddcbarv6ea.instabox.tech`

---

## Current State

The developer portal at port 8083 renders OpenAPI specs and the Swagger UI. `Try it out` does not work for protected endpoints because:

1. No dedicated `iaop-swagger-dev` Keycloak client exists for the portal to initiate an OAuth flow
2. The BFF spec's `serverUrl` in `catalog/services.yaml` points to `https://api-dev.iaop.internal/agent-bff` — an internal URL not reachable from a public browser
3. Domain service specs also use internal `serverUrl` values; only the BFF is publicly accessible

---

## Fix Plan

### Part A — Create iaop-swagger-dev Keycloak Client

This is a **one-time setup** that must run on the InstaBox machine with Keycloak admin credentials.

```bash
# Step 1: Get KC admin credentials from secrets.env
KC_ADMIN_USER=$(instabox exec iaop-keycloak-dev -- \
  docker exec iaop-keycloak sh -c 'grep KC_ADMIN_USER /data/iaop-keycloak/secrets.env | cut -d= -f2')
KC_ADMIN_PASSWORD=$(instabox exec iaop-keycloak-dev -- \
  docker exec iaop-keycloak sh -c 'grep KC_ADMIN_PASSWORD /data/iaop-keycloak/secrets.env | cut -d= -f2')

# Step 2: Authenticate kcadm
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-keycloak /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user "$KC_ADMIN_USER" \
    --password "$KC_ADMIN_PASSWORD"

# Step 3: Create the public Swagger client
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-keycloak /opt/keycloak/bin/kcadm.sh \
    create clients -r iaop-dev \
    -s clientId=iaop-swagger-dev \
    -s 'name=IAOP Swagger DEV Portal' \
    -s publicClient=true \
    -s standardFlowEnabled=true \
    -s directAccessGrantsEnabled=false \
    -s 'redirectUris=["https://8083-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/oauth2-redirect.html"]' \
    -s 'webOrigins=["https://8083-agq5lpbszgbva3ygddcbarv6ea.instabox.tech"]' \
    -s 'attributes={"pkce.code.challenge.method":"S256"}'
```

**Client properties:**
- `publicClient: true` — no client secret; PKCE is the security mechanism
- `standardFlowEnabled: true` — authorization code flow
- `directAccessGrantsEnabled: false` — no password grant from browser
- `pkce.code.challenge.method: S256` — required by Keycloak 21+

**Status: BLOCKED** — requires InstaBox shell access.

---

### Part B — Portal OAuth Configuration (catalog/services.yaml)

Add an `oauth` section to `catalog/services.yaml` so the portal can render the Swagger OAuth dialog:

```yaml
oauth:
  authorizationUrl: "https://8080-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/realms/iaop-dev/protocol/openid-connect/auth"
  tokenUrl: "https://8080-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/realms/iaop-dev/protocol/openid-connect/token"
  clientId: "iaop-swagger-dev"
  usePkce: true
  scopes:
    - openid
    - profile
```

This requires the portal binary (`iaop-developer-portal`) to read and expose the OAuth config to the Swagger UI renderer. If the portal doesn't currently support this `oauth:` key, it needs a minor code change to pass OAuth configuration to Swagger UI's `initOAuth()` call.

**Status:** Configuration structure documented. Portal code change required if not already implemented. Tracked as a P2 backlog item.

---

### Part C — BFF serverUrl in catalog (critical for Try it out)

The agent-bff entry in `catalog/services.yaml` currently uses:

```yaml
serverUrl: https://api-dev.iaop.internal/agent-bff
```

This internal URL is not reachable from a public browser. For the DEV portal, the serverUrl should be the public BFF endpoint. Two options:

**Option 1 (immediate):** Update the DEV catalog directly:
```yaml
# In catalog/services.yaml, agent-bff service:
serverUrl: https://8082-agq5lpbszgbva3ygddcbarv6ea.instabox.tech
```

**Option 2 (better for production parity):** Add an `envOverrides.serverUrl` field that the portal reads per-environment. This avoids conflating the internal service mesh URL with the public portal URL.

The InstaBox URL format (`8082-agq5lpbszgbva3ygddcbarv6ea.instabox.tech`) is specific to the current sandbox allocation — it will change when the sandbox is recreated. For now, Option 1 is simpler and the docs portal is DEV-only.

**Applied:** Updated `catalog/services.yaml` agent-bff `serverUrl` to the public BFF URL.

---

## Verification Steps (once Keycloak client exists)

```bash
# 1. Open Swagger UI
open https://8083-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/swagger-ui/

# 2. Click "Authorize" → OAuth2 / PKCE flow should initiate
# 3. Login with demo.agent.1 credentials
# 4. Try GET /api/v1/me → should return 200 with real profile

# Health check for docs portal
curl -fsS https://8083-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/health/live
# → {"status":"ok"}  ← CONFIRMED LIVE 2026-11-14

curl -fsS https://8083-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/api/v1/catalog
# → service catalog JSON  ← CONFIRMED LIVE 2026-11-14
```

---

## Status Summary

| Task | Status |
|---|---|
| Docs portal at 8083 is live and serving specs | **LIVE — CONFIRMED** |
| Swagger UI renders at `/swagger-ui/` | **LIVE — CONFIRMED** |
| `iaop-swagger-dev` Keycloak client created | **BLOCKED** (requires InstaBox exec) |
| `catalog/services.yaml` OAuth config added | **DOCUMENTED** (pending portal code support) |
| BFF `serverUrl` updated to public URL | **DONE** (catalog updated) |
| Swagger Try it out end-to-end | **BLOCKED** (depends on Keycloak client creation) |
