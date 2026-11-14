# DEV Deployment Runbook

Files: `instabox/dev/compose/docker-compose.yml`, `instabox/dev/initdb/01-databases.sql`, `.env` (sandbox-only, gitignored).

## Deploy
1. `instabox exec iaop-keycloak-dev -- sh -c 'cd /data/iaop-dev/compose && docker compose --env-file .env up -d'`
2. First boot: initdb creates DBs/roles; services run migrations automatically on start.
3. Publish ports: `instabox port publish iaop-keycloak-dev 8082 --name iaop-agent-bff --public` (and 8083 for docs).

## Verify
- `curl https://8082-.../health/live` → 200; `/health/ready` → 200
- `curl https://8083-.../api/v1/catalog` → service list; `/swagger-ui/` → 200
- Login: GET `/auth/login` → 303 to Keycloak → demo user → callback → session cookie.

## Ops
- Logs: `docker logs iaop-dev-<svc>`; restart: `docker compose restart <svc>`
- Stop: `docker compose down` (volumes persist on /data)
- Rollback: rebuild image from previous git SHA, `up -d`

## Known issue fixed
initdb `Permission denied` → init script must be readable by the postgres user; container HEALTHCHECKs disabled in compose (wget absent in debian:slim) — liveness verified via HTTP instead.
