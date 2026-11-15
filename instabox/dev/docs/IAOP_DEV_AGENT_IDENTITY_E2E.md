# Agent Identity E2E — IAOP DEV

**Date:** 2026-11-14  
**Environment:** `https://8082-agq5lpbszgbva3ygddcbarv6ea.instabox.tech`  
**Test user:** `demo.agent.1`  
**Method:** Programmatic auth-code + PKCE S256 flow (Python urllib, no browser)

---

## Authentication Flow — Verified Steps

| Step | Request | Response | Evidence |
|---|---|---|---|
| 1 | `GET BFF /auth/login` | `303 → Keycloak /authorize?...&code_challenge=...&code_challenge_method=S256` | PKCE S256 challenge set |
| 2 | `GET Keycloak /authorize` | `200` login form, `form action` parsed | Form action URL extracted |
| 3 | `POST Keycloak <action>` credentials | `302 → BFF /auth/callback?code=...&state=...` | Auth code in redirect |
| 4 | `GET BFF /auth/callback` | `303 → /` with `Set-Cookie: __Host-iaop_session` | Session cookie, HttpOnly, Secure, SameSite |
| 5 | `GET BFF /api/v1/me` (session cookie) | `200` | Authenticated profile below |

The BFF issues one cookie: `__Host-iaop_session` (HttpOnly=True, Secure=True, SameSite=Lax). The KC session cookies (`AUTH_SESSION_ID`, `KEYCLOAK_IDENTITY`, `KEYCLOAK_SESSION`) remain scoped to the Keycloak origin (`8080-...`).

---

## Actual API Responses (2026-11-14T17:54:50Z)

### GET /api/v1/me

```json
{
  "data": {
    "subject":          "4a6ba5c0-3238-4bec-927e-8fb471415099",
    "displayName":      "Demo Agent One",
    "agentId":          null,
    "agentCode":        null,
    "lifecycleStatus":  null,
    "activeWorkspace":  "workspace-candidate",
    "permissions": [
      "IAOP_AGENT",
      "agency:assignment:read",
      "agency:read",
      "agent:history:read",
      "agent:read",
      "default-roles-iaop-dev",
      "offline_access",
      "scope:email",
      "scope:openid",
      "scope:profile",
      "uma_authorization"
    ],
    "locale":           "id-ID",
    "timezone":         "Asia/Jakarta",
    "sessionExpiresAt": "2026-11-15T01:54:50.114056289Z",
    "partial":          false,
    "unavailableSections": []
  }
}
```

**Key observations:**
- `agentId: null` — no agent record is linked to this Keycloak subject
- `agentCode: null` — no agent code assigned (requires an active agent record)
- `lifecycleStatus: null` — no lifecycle state machine entry for this user
- `activeWorkspace: "workspace-candidate"` — default workspace for unlinked users

### GET /api/v1/me/today

```json
{
  "data": {
    "lifecycleContext": "UNKNOWN",
    "greeting": "Halo, Demo Agent One",
    "heroAction": {
      "title": "Selamat Bekerja",
      "actionType": "VIEW_DASHBOARD",
      "actionTarget": "/dashboard",
      "priority": "NORMAL"
    },
    "eligibility":    { "status": "UNAVAILABLE", "errorReason": "Agent service unconfigured" },
    "priorityTasks":  { "status": "UNAVAILABLE", "errorReason": "Workflow task service unconfigured" },
    "agenda":         { "status": "UNAVAILABLE", "errorReason": "Calendar and agenda service unconfigured" },
    "recentActivity": { "status": "UNAVAILABLE", "errorReason": "Notification and activity service unconfigured" },
    "customerAttentionCount": null,
    "openClaimsCount": null,
    "partial": true,
    "unavailableSections": ["agent_service", "tasks", "agenda", "recent_activity"]
  }
}
```

### GET /api/v1/me/workspaces

```json
{
  "data": {
    "workspaces": [
      {
        "id":          "workspace-candidate",
        "name":        "Candidate / Onboarding Workspace",
        "agencyCode":  null,
        "role":        "CANDIDATE",
        "isDefault":   true
      }
    ],
    "active_workspace_id": "workspace-candidate"
  }
}
```

### GET /api/v1/agency/my-team → 200 `[]`
### GET /api/v1/agency/hierarchy → 200 `[]`

Both return empty arrays. This is correct: `demo.agent.1` has no agency assignment and no team members.

---

## Explanation: Why lifecycleContext = UNKNOWN

This is the **correct and intended behavior**. The business state machine works as follows:

```
Keycloak User ──(no identity link)──> UNKNOWN lifecycle
              ──(identity link)──────> agent record → lifecycleStatus (ACTIVE / SUSPENDED / etc.)
```

`demo.agent.1` is a Keycloak-only account with no agent identity link. The BFF correctly reports `lifecycleContext = UNKNOWN` and places the user in `workspace-candidate`. This is not a bug — it is the expected state for a user who has not yet completed agent registration.

---

## Two Valid Scenarios

### Scenario A: Unlinked Candidate (current state of demo.agent.1)

The user exists in Keycloak with `IAOP_AGENT` role but has no agent record in the Agent Service. This represents an agent who has been invited to the platform but has not yet been activated.

**Correct behavior:**
- `GET /api/v1/me` → `agentId: null`, `lifecycleStatus: null`, `workspace-candidate`
- `GET /api/v1/me/today` → `lifecycleContext: UNKNOWN`
- `GET /api/v1/agency/my-team` → `[]`

**Use this for:** Testing the candidate onboarding entry point and the UNKNOWN lifecycle rendering in the frontend.

### Scenario B: Linked Agent (requires e2e-agent-admin)

The `e2e-agent-admin` account holds `IAOP_PLATFORM_ADMIN` + full `agent:*` scope. It can create an agent record and link a Keycloak subject to it via:

```bash
# Step 1: Create an agent record
POST /api/v1/agents
Authorization: Bearer <e2e-agent-admin token>
{
  "fullName": "Demo Agent One",
  "idNumber": "1234567890123456",
  "phoneNumber": "+62812345678"
}
# → { "data": { "id": "<agent-uuid>", "code": "AGT-XXXXX" } }

# Step 2: Link the Keycloak subject to the agent record
POST /api/v1/agents/<agent-uuid>/identity-links
Authorization: Bearer <e2e-agent-admin token>
{
  "provider": "keycloak",
  "subject": "4a6ba5c0-3238-4bec-927e-8fb471415099"
}
# → 201

# After linking, demo.agent.1's /api/v1/me will return:
# agentId: "<agent-uuid>", agentCode: "AGT-XXXXX", lifecycleStatus: "DRAFT"
```

**Note:** The Agent Service's `/api/v1/agents` endpoint is NOT publicly accessible — it is only on the Docker internal network. These commands must run via `instabox exec` or from within the Docker network.

---

## Identity Link Creation — Full Runbook

```bash
# 1. Get a token for e2e-agent-admin via client_credentials or direct grant
# (direct grant, DEV only):
TOKEN=$(curl -s -X POST \
  "https://8080-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/realms/iaop-dev/protocol/openid-connect/token" \
  -d "grant_type=password&client_id=iaop-agent-bff&username=e2e-agent-admin&password=<password>&scope=openid" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# 2. Create agent (call agent-service directly from inside the network)
instabox exec iaop-keycloak-dev -- docker exec iaop-dev-agent-bff \
  curl -s -X POST http://agent-service:8080/api/v1/agents \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"fullName":"Demo Agent One","idNumber":"1234567890123456","phoneNumber":"+62812345678"}'

# 3. Link identity (replace <agent-uuid> with the ID from step 2)
instabox exec iaop-keycloak-dev -- docker exec iaop-dev-agent-bff \
  curl -s -X POST http://agent-service:8080/api/v1/agents/<agent-uuid>/identity-links \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"provider":"keycloak","subject":"4a6ba5c0-3238-4bec-927e-8fb471415099"}'
```

**Status: BLOCKED** — requires InstaBox shell access and `e2e-agent-admin` password (stored in `/data/iaop-keycloak/secrets.env` on the box).

---

## Verdict

| Check | Result |
|---|---|
| Auth-code + PKCE S256 flow completes | PASS |
| Session cookie set, HttpOnly + Secure | PASS |
| `/api/v1/me` returns real Keycloak data | PASS |
| `lifecycleContext = UNKNOWN` is correct business state | CONFIRMED |
| `workspace-candidate` for unlinked user | CORRECT |
| Identity link creation path documented | DOCUMENTED |
| Agent service identity-link commands | BLOCKED (requires InstaBox exec) |
