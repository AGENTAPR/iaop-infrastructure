# IAOP Phase 2 — Shared Keycloak & Backend Authentication
## Implementation Report

**Status:** `PARTIAL — core deployment LIVE-VERIFIED; BFF flow, rust-common
library extraction, and full security matrix remain open.`

## InstaBox (verified)

| Item | Value |
|---|---|
| Account | irsyadjpratamap@gmail.com (personal org, **free plan**) |
| Machine | `iaop-keycloak-dev` — id `m_agq5lpbszgbva3ygddcbarv6ea`, Running |
| Size | 4 vCPU / 8 GiB (only free-plan size) |
| Template | agent-browser (Debian 13, Docker) |
| Auto-suspend | **FIXED 30 min idle — cannot be disabled on free plan** |
| Public URL | `https://8080-agq5lpbszgbva3ygddcbarv6ea.instabox.tech` |
| Issuer | `https://8080-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/realms/iaop-dev` |
| Persistent disk | `/data` (20 GiB) — postgres + config under `/data/iaop-keycloak/` |

**Availability limitation (real):** the box pauses after 30 min idle.
Token issuance, login, and JWKS fetches fail while suspended. Resume via
`instabox resume iaop-keycloak-dev` (or first use). NOT always-on —
upgrade plan required for `--auto-suspend 0`.

## Keycloak (verified live)

- Version: `quay.io/keycloak/keycloak:26.8.2` (prod `start` mode, not start-dev)
- DB: `postgres:16-alpine`, dedicated `keycloak` db/user, NO public port
- Realm `iaop-dev` imported (idempotent setup.sh; re-run skips existing)
- Clients: `iaop-agent-bff`, `iaop-operations-bff` (confidential,
  auth-code + PKCE S256, no implicit/direct-grant, explicit redirects),
  15 bearer-only API audience clients, 3 service clients
  (client_credentials: workflow-worker, integration-worker,
  provisioning-admin), `iaop-dev-cli` (public, direct-grant — dev testing only)
- Roles: 10 IAOP_* realm roles; 9 `agent:*` client roles on iaop-agent-api
- User `e2e-agent-admin` created with generated password (in on-box
  secrets.env, never committed)

## Verified security evidence

- OIDC discovery returns correct issuer ✔
- `/admin/*` and `/realms/master/*` → 404 via nginx edge ✔
- Keycloak bound to `127.0.0.1:8081` on box — admin only via SSH tunnel ✔
- Postgres restart + Keycloak container restart → healthy, realm intact ✔
- Real user token: iss/aud/scope/realm+client roles correct ✔
- Agent Service (JWT mode, live JWKS): valid token → 200 read / 201 create;
  missing token → 401; malformed → 401; wrong audience → 401 InvalidAudience;
  tampered signature → 401 ✔

## Git

| Repo | Branch | PR | Status |
|---|---|---|---|
| iaop-infrastructure | feature/phase-2-shared-keycloak-identity | AGENTAPR/iaop-infrastructure#1 | OPEN |
| iaop-agent-service | feature/phase-2-shared-keycloak-identity | AGENTAPR/iaop-agent-service#2 | OPEN |

## NOT done (honest)

- BFF `/auth/*` backend-managed session flow — NOT IMPLEMENTED
- `iaop-rust-common` `iaop-security` JWKS library — agent-service has its
  own validator; shared extraction NOT done
- `iaop-local-dev` env templates/docs — NOT done
- Authorization Code + PKCE browser flow E2E — NOT VERIFIED (no browser)
- Negative matrix: disabled user, expired token, role-denied op —
  partially covered (aud/garbage/missing); disabled-user & expiry NOT run
- Backup restore TEST — backup.sh written, restore not executed
- Keycloak admin credential rotation procedure — documented gap
- Session/CSRF/token-refresh handling — not implemented (no BFF yet)
- Docs tree (KEYCLOAK_*.md etc.) — only instabox/README.md written

## Blockers

- Free-plan 30-min auto-suspend prevents always-on shared dev IdP.
- No custom domain — issuer URL contains machine id; stable while machine
  exists but changes if machine is recreated.
