# Keycloak CORS Hardening — IAOP DEV

**Date:** 2026-11-14  
**Current state:** `webOrigins = ["+"]` (wildcard — reflects any Origin) on `iaop-agent-bff` client  
**Target state:** Explicit allowlist: `["https://8082-agq5lpbszgbva3ygddcbarv6ea.instabox.tech"]`

---

## Why This Matters

The `+` wildcard in Keycloak's `webOrigins` causes the token endpoint to respond with `Access-Control-Allow-Origin: <whatever-origin-sent>` for requests to the Keycloak token/OIDC endpoints originating from the browser. Any site that can trick a user into making a cross-origin Keycloak token exchange could benefit from this open CORS policy.

The BFF itself does not reflect arbitrary origins (confirmed: T5 in security negative E2E). This is a Keycloak-side concern for the authorization and token endpoints.

**The `+` shorthand was originally set to fix account-console login.** It is correct for the `account-console` client (which users access from any browser origin), but should be scoped for the BFF client.

---

## Fix: Update iaop-agent-bff Client webOrigins

### Prerequisite: SSH tunnel for kcadm admin access

```bash
# Open SSH tunnel to reach Keycloak admin console
instabox ssh -L 8081:localhost:8081 iaop-keycloak-dev
# Keep this running in a terminal
```

### Step 1: Get KC admin credentials

```bash
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-keycloak sh -c 'grep KC_ADMIN /data/iaop-keycloak/secrets.env'
```

### Step 2: Authenticate kcadm

```bash
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-keycloak /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user <KC_ADMIN_USER> \
    --password <KC_ADMIN_PASSWORD>
```

### Step 3: Find the iaop-agent-bff client ID

```bash
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-keycloak /opt/keycloak/bin/kcadm.sh \
    get clients -r iaop-dev --fields id,clientId \
    --query "clientId=iaop-agent-bff"
# Note the internal `id` UUID (not the clientId string)
```

### Step 4: Update webOrigins to explicit allowlist

```bash
# Replace <CLIENT_UUID> with the id from step 3
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-keycloak /opt/keycloak/bin/kcadm.sh \
    update clients/<CLIENT_UUID> -r iaop-dev \
    -s 'webOrigins=["https://8082-agq5lpbszgbva3ygddcbarv6ea.instabox.tech"]'
```

### Step 5: Verify the change

```bash
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-keycloak /opt/keycloak/bin/kcadm.sh \
    get clients/<CLIENT_UUID> -r iaop-dev --fields webOrigins
# Expected: {"webOrigins":["https://8082-agq5lpbszgbva3ygddcbarv6ea.instabox.tech"]}
```

### Step 6: Test that login still works

```bash
# Full BFF login flow must still return session cookie
curl -s -D - -o NUL --max-redirs 0 \
  "https://8082-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/auth/login"
# Must return: 303 with Location → Keycloak authorize URL
```

Then complete the full PKCE login with demo.agent.1 and verify `/api/v1/me` returns 200.

---

## Impact Assessment

| Client | Current webOrigins | Required change |
|---|---|---|
| `iaop-agent-bff` | `["+"]` | → `["https://8082-...instabox.tech"]` |
| `account-console` | `["+"]` | **Keep `["+"]`** — users access account console from arbitrary origins |
| `security-admin-console` | `["+"]` | **Keep as-is** — admin console is not publicly exposed |

Do NOT change `account-console`'s `webOrigins`. It was deliberately set to `["+"]` to fix a known account-console login issue (Origin header validation).

---

## Status

**BLOCKED** — requires InstaBox shell access with Keycloak admin credentials.

This change is non-breaking for the existing login flow (the BFF redirect URI does not change, only the CORS origin allowlist tightens). However, it must be tested after application to confirm the full PKCE flow still works.

The change is safe to apply to the running environment without container restarts — Keycloak reads client configuration from its database on each request.
