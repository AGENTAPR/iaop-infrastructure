# IAOP shared-dev Keycloak on InstaBox

Machine: `iaop-keycloak-dev` (agent-browser template, 4 vCPU / 8 GiB, free plan).
**Auto-suspend is fixed at 30 min idle on the free plan** — the box pauses;
run `instabox resume iaop-keycloak-dev` (or it resumes on next use) to restore
the issuer. This is a documented limitation, not always-on.

## Layout on the box (`/data/iaop-keycloak/`)

- `compose/docker-compose.yml` — postgres:16-alpine + keycloak:26.8.2 + nginx edge
- `compose/nginx/default.conf` — public allowlist (realm `iaop-dev` OIDC surface only)
- `config/realm-iaop-dev.json` — realm import (idempotent via setup.sh)
- `secrets.env` (600) — generated credentials, never committed
- `secrets-clients.env` (600) — client secrets
- `setup.sh` — idempotent provisioning (secrets, compose up, realm, e2e user)
- `backups/` — pg_dump output

## Access model

- Public: `https://8080-<machine>.instabox.tech` → nginx → Keycloak
  (only `/realms/iaop-dev/{.well-known,protocol/openid-connect,account,login-actions}` + `/resources/`)
- Admin console / admin REST / master realm: **not proxied** (404).
  Admin via SSH tunnel: `instabox ssh -L 8081:localhost:8081 iaop-keycloak-dev`
  then `http://localhost:8081/admin` (keycloak bound to 127.0.0.1:8081).
- Issuer: `https://8080-agq5lpbszgbva3ygddcbarv6ea.instabox.tech/realms/iaop-dev`

## Redeploy / verify

```powershell
.\deploy.ps1     # push bundle + run setup.sh (idempotent)
.\verify.ps1     # health, discovery, admin-block, token smoke
.\backup.sh      # on box: pg_dump + realm export to backups/
```
