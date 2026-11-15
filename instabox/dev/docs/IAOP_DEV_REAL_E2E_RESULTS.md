# Real E2E Results — 2026-11-14 (authenticated, demo.agent.1)

Flow executed programmatically (auth-code + PKCE S256, real Keycloak login form POST):

| Step | Result |
|---|---|
| GET /auth/login | 303 → Keycloak authorize URL w/ code_challenge+nonce ✓ |
| Keycloak login page | 200, form action parsed ✓ |
| Credential POST (demo.agent.1) | 302 → BFF /auth/callback?code=... ✓ |
| Callback | 303 → /, session cookie set ✓ |
| GET /api/v1/me | 200 — verified subject, displayName, permissions from JWT ✓ |
| GET /api/v1/me/today | 200 — aggregated dashboard, lifecycleContext=UNKNOWN (honest) ✓ |
| GET /api/v1/me/tasks | 503 DEPENDENCY_UNAVAILABLE "Workflow task service is not configured" — fail-closed ✓ |
| GET /api/v1/agency/my-team | 200 [] — real agency-service call (candidate: no team) ✓ |
| GET /api/v1/agency/hierarchy | 200 [] ✓ |
| GET /api/v1/me/workspaces | 200 — workspace-candidate only ✓ |
| Unauthenticated /api/v1/me | 401 UNAUTHENTICATED ✓ |
| POST /auth/logout w/o CSRF | 403 — CSRF enforced ✓ |

PostgreSQL: migrations applied on all 4 services; outbox_events table present; outbox publishers started with atomic leasing (agent/agency). Kafka: broker healthy; no domain write command executed yet → no events emitted (documented gap — needs a staff-scoped write journey).

Passwords/tokens never printed or stored.
