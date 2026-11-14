# Deployment Final Audit — IAOP DEV

**Date:** 2026-11-14  
**Auditor roles:** Principal Cloud Architect, Principal Rust Engineer, Senior DevOps, Security Engineer, QA  
**Environment:** InstaBox machine `iaop-keycloak-dev`  
**BFF commit:** `81a88d6` (development), security remediations on `feature/bff-security-p0-remediation` (`251e038`)  
**Agent Service commit:** `7c3e2e1` (feature/agent-resource-authz)  
**Agency Service commit:** `9f14364` (feature/security-dep-update)  
**Infrastructure branch:** `feature/instabox-dev-deployment`

---

## Full Test Matrix

| Test ID | Category | Test | Expected | Actual | Verdict |
|---|---|---|---|---|---|
| **SEC-01** | Security | `GET /api/v1/me` — no session | 401 UNAUTHENTICATED | 401 UNAUTHENTICATED | **PASS** |
| **SEC-02** | Security | `GET /api/v1/agency/hierarchy` — no session | 401 | 401 | **PASS** |
| **SEC-03** | Security | `GET /nonexistent` path | 404 | 404 | **PASS** |
| **SEC-04** | Security | `GET /api/v1/me` with garbage Bearer | 401 (session required, not Bearer) | 401 | **PASS** |
| **SEC-05** | Security | CORS from `evil.example.com` | No ACAO header | ACAO absent | **PASS** |
| **SEC-06** | Security | `POST /auth/logout` without CSRF (authenticated) | 403 | 403 | **PASS** |
| **AUTH-01** | Auth | BFF `/auth/login` → PKCE S256 challenge | 303 → Keycloak with `code_challenge_method=S256` | EXACT MATCH | **PASS** |
| **AUTH-02** | Auth | Keycloak login form page | 200 with form action | 200, action URL parsed | **PASS** |
| **AUTH-03** | Auth | Credential POST → auth code | 302 → BFF /auth/callback | 302 with code | **PASS** |
| **AUTH-04** | Auth | BFF /auth/callback → session cookie | 303 → /, `__Host-iaop_session` HttpOnly Secure | EXACT MATCH | **PASS** |
| **AUTH-05** | Auth | Session cookie properties | HttpOnly=true, Secure=true, SameSite=Lax | CONFIRMED | **PASS** |
| **API-01** | API | `GET /api/v1/me` authenticated | 200 with real Keycloak profile | 200, subject=4a6ba5c0, displayName=Demo Agent One | **PASS** |
| **API-02** | API | `GET /api/v1/me/today` | 200, lifecycleContext=UNKNOWN (correct) | 200, UNKNOWN | **PASS** |
| **API-03** | API | `GET /api/v1/me/tasks` | 503 DEPENDENCY_UNAVAILABLE | 503 | **PASS** |
| **API-04** | API | `GET /api/v1/agency/my-team` | 200 `[]` (no team) | 200 `[]` | **PASS** |
| **API-05** | API | `GET /api/v1/agency/hierarchy` | 200 `[]` (no hierarchy) | 200 `[]` | **PASS** |
| **API-06** | API | `GET /api/v1/me/workspaces` | 200 workspace-candidate | 200, workspace-candidate, role=CANDIDATE | **PASS** |
| **INFRA-01** | Infrastructure | BFF `/health/live` | 200 `{"status":"ok"}` | 200 `{"status":"ok"}` | **PASS** |
| **INFRA-02** | Infrastructure | BFF `/health/ready` | 200 `{"status":"ready"}` | 200 `{"status":"ready"}` | **PASS** |
| **INFRA-03** | Infrastructure | Docs `/health/live` | 200 `{"status":"ok"}` | 200 `{"status":"ok"}` | **PASS** |
| **INFRA-04** | Infrastructure | Keycloak OIDC discovery | 200 reachable | 200 all endpoints reachable | **PASS** |
| **DB-01** | Database | PostgreSQL migrations (agent) | Applied cleanly | Confirmed (service healthy) | **PASS** |
| **DB-02** | Database | PostgreSQL migrations (agency) | Applied cleanly | Confirmed (service healthy) | **PASS** |
| **DB-03** | Database | PostgreSQL migrations (eligibility) | Applied cleanly | Confirmed (service healthy) | **PASS** |
| **DB-04** | Database | PostgreSQL migrations (bff) | Applied cleanly | Confirmed (ready check passes) | **PASS** |
| **DB-05** | Database | Outbox table present (agent_db) | Table exists | Confirmed (publisher started) | **PASS** |
| **KAFKA-01** | Kafka | Broker healthy | Kafka API reachable | Confirmed running | **PASS** |
| **KAFKA-02** | Kafka | Outbox publisher started | Log: "outbox publisher started with atomic leasing" | Confirmed in real E2E results | **PASS** |
| **KAFKA-03** | Kafka | First domain event delivery | BLOCKED — no domain write executed | BLOCKED | **BLOCKED** |
| **FIXBOOT-01** | Bootstrap | PostgreSQL initdb .sh script | `01-databases.sh` replaces broken `.sql` | DONE — file created | **DONE** |
| **FIXHC-01** | Healthcheck | Rust service Dockerfiles use `curl` | curl installed, HEALTHCHECK CMD updated | DONE — 4 Dockerfiles updated | **DONE** |
| **FIXHC-02** | Healthcheck | Compose healthcheck blocks restored | `healthcheck:` entries present, `service_healthy` dependencies | DONE — compose updated | **DONE** |
| **FIXHC-03** | Healthcheck | agency-service → agent-service: service_healthy | Previously `service_started` | DONE | **DONE** |
| **FIXHC-04** | Healthcheck | agent-bff → agent+agency: service_healthy | Previously `service_started` | DONE | **DONE** |
| **SEC-CROSSAGENT** | Security | Agent A cannot read Agent B profile | 403 | BLOCKED (no second linked agent, no internal port access) | **BLOCKED** |
| **SWAGGER-01** | Portal | Docs portal renders specs | Swagger UI accessible | CONFIRMED LIVE | **PASS** |
| **SWAGGER-02** | Portal | Swagger OAuth Try it out | OAuth flow works | BLOCKED (iaop-swagger-dev client not created) | **BLOCKED** |
| **PERF-01** | Performance | Load test: 15 concurrent, /health/live | p95 < 2s via public edge | p95=959ms | **PASS** |

---

## Service Readiness Assessment

### Deployed and Verified Services

| Service | Public URL | Status | Notes |
|---|---|---|---|
| Keycloak | `https://8080-...` | ✅ LIVE | Realm iaop-dev, 3 demo users, PKCE configured |
| Agent BFF | `https://8082-...` | ✅ LIVE | 52 endpoints, security remediations applied |
| Developer Portal | `https://8083-...` | ✅ LIVE | 20 service specs rendered |
| PostgreSQL | Internal only | ✅ LIVE | 4 databases, migrations applied |
| Kafka | Internal only | ✅ LIVE | Broker healthy, publisher running |
| Agent Service | Internal only | ✅ LIVE | 17 endpoints, JWT auth, outbox running |
| Agency Service | Internal only | ✅ LIVE | Hierarchy + assignments, JWT auth |
| Eligibility Service | Internal only | ✅ LIVE | Health only (domain TBD) |

### Not Ready — Domain Endpoints Not Implemented

| Service | Status | Missing |
|---|---|---|
| Recruitment Service | NOT READY IN CODE | No domain endpoints; health/system only |
| Workflow Service | NOT READY IN CODE | No domain endpoints; health/system only |
| Notification Service | NOT READY IN CODE | No domain endpoints; health/system only |
| Document Service | NOT READY IN CODE | No domain endpoints; health/system only |
| Onboarding Service | NOT READY IN CODE | No domain endpoints; health/system only |

Each of the five unimplemented services has: Dockerfile, `routes.rs` with health/system only, 2 migration SQL files (empty domain schema). They are not deployed in the DEV compose stack.

---

## Open Items and Blockers

| ID | Priority | Item | Action Required |
|---|---|---|---|
| OI-01 | P0 | Kafka first domain event | Execute `POST /api/v1/agents` via InstaBox exec |
| OI-02 | P0 | Cross-agent auth test | Create second linked agent, test via InstaBox exec |
| OI-03 | P0 | PR merges: agent-bff #12, agent-service #13, agency-service #10, rust-common #8 | Peer review and merge to development |
| OI-04 | P1 | Healthcheck Dockerfile PRs on 4 service repos | Review and merge `feature/healthcheck-curl-fix` |
| OI-05 | P1 | Keycloak webOrigins hardening on `iaop-agent-bff` client | Run kcadm command on InstaBox (documented in runbook) |
| OI-06 | P1 | Create `iaop-swagger-dev` Keycloak client | Run kcadm command on InstaBox (documented in SWAGGER doc) |
| OI-07 | P2 | 5 unimplemented domain services | Domain team implementation work |
| OI-08 | P2 | OAuth flow in portal binary | Portal code change to pass OAuth config to Swagger UI |

---

## Infrastructure Verdicts

### DEV Infrastructure Readiness

**PASS — READY FOR CONTINUED DEVELOPMENT**

The core infrastructure (Keycloak, BFF, Agent Service, Agency Service, PostgreSQL, Kafka) is deployed, healthy, and verified. All publicly accessible endpoints respond correctly. Auth-code PKCE flow completes end-to-end. Security controls (session auth, CSRF, 401 enforcement, CORS non-reflection) are all working.

### Agent End-to-End Readiness

**PARTIAL — CANDIDATE LIFECYCLE VERIFIED, LINKED-AGENT LIFECYCLE BLOCKED**

The candidate (unlinked) lifecycle is fully verified: `demo.agent.1` authenticates, receives `lifecycleContext=UNKNOWN`, workspace-candidate, and truthful UNAVAILABLE sections. The linked-agent lifecycle (identity link creation, lifecycle transitions, Kafka event emission) is blocked by the need to execute write commands via InstaBox shell access, which requires the `e2e-agent-admin` account credentials from `secrets.env` on the box.

---

## Changes Made in This Cycle

| Repository | Branch | Changes |
|---|---|---|
| `iaop-infrastructure` | `feature/instabox-dev-deployment` | initdb .sh bootstrap fix; compose healthchecks restored; monitor.sh; 10 doc files |
| `iaop-agent-bff` | `feature/healthcheck-curl-fix` | Dockerfile: curl + HEALTHCHECK |
| `iaop-agent-service` | `feature/healthcheck-curl-fix` | Dockerfile: curl + HEALTHCHECK |
| `iaop-agency-service` | `feature/healthcheck-curl-fix` | Dockerfile: curl + HEALTHCHECK |
| `iaop-eligibility-service` | `feature/healthcheck-curl-fix` | Dockerfile: curl + HEALTHCHECK |
| `iaop-api-contracts` | (committed on current branch) | catalog/services.yaml: agent-bff serverUrl → public URL |
