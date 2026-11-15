# Network Security Matrix — InstaBox DEV (verified 2026-11-15)

Docker networks: `iaop-edge`, `iaop-domain`, `iaop-data`.

| From \ To | agent-bff | api-docs | domain svcs | db | kafka |
|---|---|---|---|---|---|
| **iaop-edge** (untrusted test container) | 200 OK | 200 OK | DNS unresolvable | DNS unresolvable | DNS unresolvable |
| **iaop-domain** (untrusted test container) | — | — | reachable | unresolvable | unresolvable |
| domain services (dual-homed domain+data) | n/a | n/a | reachable | connected (healthy) | connected (healthy) |
| agent-bff (edge+domain+data) | n/a | n/a | reachable | bff_db connected | n/a (not a member) |

Published host ports (all `127.0.0.1` except Keycloak edge `0.0.0.0:8080`):

| Port | Service | Public? |
|---|---|---|
| 8080 | keycloak-edge (nginx) | yes — IdP only |
| 8081 | keycloak (localhost) | no |
| 8082 | agent-bff | yes — application API via BFF |
| 8083 | api-docs (Developer Portal) | yes — DEV access plane |
| 5432 | postgres | localhost only (tests/admin) |
| 29092 | kafka HOST listener | localhost only (tests) |

Domain services (`agent`, `agency`, `eligibility`): `8080/tcp` exposed
container-internal only — **no host binding**.

## Limitations (honest)

- Docker bridge networks are L2 segments, not firewalls: any container on a
  shared network can reach peers. Segmentation limits *which workloads can
  even resolve* a service; it does not do per-process auth.
- `127.0.0.1` port bindings are reachable from the sandbox host and via the
  instabox port-forward mechanism only for explicitly published ports.
- Kubernetes NetworkPolicy manifests exist under `k8s/` (default-deny +
  portal policy); enforcement depends on the cluster CNI and is **not
  verified** — no k8s cluster is deployed in this environment.
