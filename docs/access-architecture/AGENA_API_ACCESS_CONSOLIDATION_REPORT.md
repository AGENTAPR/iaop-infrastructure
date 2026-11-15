# AGENA — API Access Architecture & Gateway Consolidation Report

Date: 2026-11-15
Scope: InstaBox DEV (live), self-hosted-dev compose (config), k8s manifests (config)

## A. Before / After

**Before**
- Single `iaop-dev` Docker bridge for all services; edge = instabox per-port
  publishing (BFF:8082, portal:8083, keycloak-edge:8080).
- Self-hosted Caddyfile proxied `/api/v1/agents*`, `/api/v1/agencies*`,
  `/api/v1/integration*`, `/flowable-rest*`, `/prometheus*` **directly to
  domain/internal services** — public bypass of BFF.
- Self-hosted compose published Postgres (`PUBLIC_POSTGRES_PORT`), Kafka
  (`PUBLIC_KAFKA_PORT`), Prometheus, OTLP on all interfaces.
- `iaop-api-gateway` Rust scaffold present in org + catalog.

**After**
- Three networks: `iaop-edge` (BFF, portal), `iaop-domain` (domain services +
  authorized callers), `iaop-data` (Postgres, Kafka + dual-homed services).
- Caddyfile rewritten: host-based allowlist (`AGENT_HOST`→BFF,
  `PORTAL_HOST`→portal, `AUTH_HOST`→Keycloak), terminal 404, normalized
  `X-Request-ID`, 10MB body limit, timeouts/keepalive. Zero domain routes.
- Postgres/Kafka/Prometheus/OTLP bound to `127.0.0.1`; Keycloak public only
  via Caddy `AUTH_HOST`.
- Gateway catalog entry/spec removed; repo retirement blocked on GitHub admin.

## B. Repository changes

| Repo | Branch | Commits |
|---|---|---|
| iaop-infrastructure | `feature/dev-portal-sso-compose` | `21520a7` network segmentation + Caddyfile + port bindings; `12ecfe3` docs |
| iaop-api-contracts | `feature/portal-scalar-v2-sso` | `7d72121` gateway catalog/spec removal |

`development` push **blocked** by repo ruleset ("requires approval from
someone other than the last pusher") — recoverable commits preserved on the
feature branches above.

## C. Gateway removal

- Runtime dependencies: **none found** in any repo (services, compose, k8s,
  Keycloak, env, CI).
- References removed: catalog `services.yaml`, `manifest.development.json`,
  `specs/development/api-gateway/openapi.json`.
- Replacement: Caddy host-allowlist config (above).
- GitHub repo deletion: **BLOCKED** — token lacks `delete_repo` scope/admin
  rights (`HTTP 403`). Recovery archive verified: two `git bundle` files with
  complete history in `iaop-workspace/backup*-iaop-api-gateway.bundle`.
  Remaining action: org admin deletes `AGENTAPR/iaop-api-gateway`.

## D. Network security

See `AGENA_NETWORK_SECURITY_MATRIX.md`. Summary: only BFF+portal published;
domain/data have no ports; edge containers cannot resolve domain/db/kafka
(DNS-level isolation verified live); self-hosted DB/Kafka no longer public.

## E. Authentication & authorization

Unchanged and preserved: portal session (`agena_session_id`), BFF session
(`__Host-iaop_session` + CSRF), domain bearer JWTs with per-service audiences
(`iaop-agent-api`, `iaop-agency-api`, `iaop-eligibility-api`), service-account
client credentials for BFF-adjacent validation (`iaop-agency-service`→agent).

## F. Security verification (live)

| Test | Result |
|---|---|
| edge→agency-service / agent-service / db / kafka | DNS unresolvable |
| edge→agent-bff / api-docs health | 200 (allowed) |
| domain-net→db/kafka | unresolvable |
| Public portal `/health/live` | 200 |
| Public BFF `/health/live` | 200 |
| Public BFF `/api/v1/me` no-auth | 401 |
| Agency service no-auth / wrong-aud / agent-no-claim | 401 / 401 / 403 (prior phase) |

## G. Deployment

- Compose redeployed on InstaBox; all 7 iaop-dev containers healthy; data
  volumes preserved (27 agencies, 101 outbox rows intact).
- Self-hosted/k8s changes are config-only (not deployed anywhere).

## H. Remaining risks

1. **GitHub repo deletion BLOCKED** (admin action required; archive verified).
2. `development` branch integration blocked by ruleset approval requirement.
3. Docker bridge segmentation is coarse — no per-process firewall; documented.
4. k8s NetworkPolicies defined as intent only; no cluster to verify CNI.
5. Caddy not deployed on InstaBox (platform edge = instabox port publishing,
   which already exposes only BFF+portal); Caddy is the edge for
   self-hosted/k8s paths. A consolidated Caddy port on InstaBox was not added
   to preserve existing public URLs.
6. Frontend repos (`agena-*-web`) not present in workspace — no frontend code
   to audit; same-origin/BFF-only policy documented for when they land.
7. Operations BFF is a scaffold — not deployed, no route exposed.
8. InstaBox disk ~93% full.

## I. Final verdict

**CONDITIONALLY DEV READY**

The architectural invariant holds on the live DEV environment: public ingress
reaches only BFF + Developer Portal; domain services and data plane are
network-unreachable from edge workloads and have no public ports; all
services healthy post-migration; gateway removed from runtime + catalog.
Conditioned on: GitHub repo deletion (admin action), development-branch merge
approval, and k8s CNI verification when a cluster exists.
