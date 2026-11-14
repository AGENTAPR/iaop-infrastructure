# InstaBox Current State Audit — 2026-11-14

## Machine
- Sandbox: `iaop-keycloak-dev` (existing; NOT recreated)
- Plan class: Pro 4 vCPU / 8 GiB; ~6 GiB free RAM observed with Keycloak stack running
- OS: Linux VM with Docker; persistent data at `/data`

## Existing workloads (preserved)
| Container | Role | Status |
|---|---|---|
| iaop-keycloak | Keycloak IdP | Up, healthy |
| iaop-keycloak-edge | TLS edge proxy :8080 | Up |
| iaop-keycloak-db | Keycloak PostgreSQL | Up |

## Keycloak (verified live)
- Public issuer: `https://8080-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/realms/iaop-dev`
- OIDC discovery reachable; auth/token/JWKS endpoints over HTTPS
- Realm `iaop-dev`; demo users `demo.agent.1..3` (see IAOP_DEV_DEMO_USERS.md)
- Client `iaop-agent-bff` updated: added redirect `https://8082-...instabox.tech/auth/callback`, `webOrigins=["+"]`
- Issuer unchanged; no users/sessions/DB touched

## Auto-pause
- Machine runs on-demand; services recover via `restart: unless-stopped`. Cold start acceptable for DEV; Postgres/Kafka persist on `/data` volume. NOT suitable as 24/7 production — DEV only.
