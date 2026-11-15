# InstaBox Network Verification — 2026-11-15

Environment: `iaop-keycloak-dev` (`m_agq5lpbszgbva3ygddcbarv6ea`), compose
project `iaop-dev`, source `instabox/dev/compose/docker-compose.yml` @
`21520a7` (feature/dev-portal-sso-compose).

## Deployment

`docker compose config -q` OK → `docker compose up -d` recreated all
services onto segmented networks. All containers healthy post-change.
Volumes (`/data/iaop-dev/postgres`, `/data/iaop-dev/kafka`) untouched;
no data loss (agencies=27, outbox=101 rows verified after).

## Membership (verified via `docker network inspect`)

- `iaop-edge`: `iaop-dev-agent-bff`, `iaop-dev-api-docs`
- `iaop-domain`: agent-bff, api-docs, agent-service, agency-service,
  eligibility-service
- `iaop-data`: db, kafka, agent-service, agency-service,
  eligibility-service, agent-bff (bff_db session store)
- Legacy `iaop-dev` bridge removed after migration.

## Negative tests (untrusted container on `iaop-edge`) — actual results

| Probe | Result |
|---|---|
| `http://agency-service:8080` | `Could not resolve host` |
| `http://agent-service:8080` | `Could not resolve host` |
| `http://db:5432` | `Could not resolve host` |
| `http://kafka:9092` | `Could not resolve host` |
| `http://agent-bff:8080/health/live` | **200** (allowed) |
| `http://docs:8080/health/live` | **200** (allowed) |

Domain-net-only probe: `db`/`kafka` unresolvable (data plane requires
dual-homing, which only real service workloads have).

## Public surface (unchanged URLs)

- `https://8082-….instabox.tech` → agent-bff (`/api/v1/me` no-auth = **401**)
- `https://8083-….instabox.tech` → developer portal (`/health/live` = **200**)
- `https://8080-….instabox.tech` → keycloak-edge (IdP only)
- Domain services: no host ports — unreachable from internet.

## Regression

Portal 200, BFF health 200, BFF unauthenticated API 401 — all verified
post-migration.
