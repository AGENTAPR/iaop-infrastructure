# AGENA API Access Architecture (ADR-001)

Status: Accepted — deployed on InstaBox DEV (2026-11-15)

## Decision

Caddy is the single Edge Gateway. The Rust `iaop-api-gateway` microservice is
retired. There is no gateway hop between Caddy and BFFs.

```
                        INTERNET
                           |
                    [ CADDY EDGE ]          <- only public ingress
                           |
              +------------+------------+
              |            |            |
         Agent BFF   Operations BFF  (future Customer BFF)
              |            |
              +------------+------------+
                     PRIVATE NETWORKS
        +----------------+----------------+
        |                |                |
   Domain Services   Workers/Internal   Developer Portal
        |                                 (DEV testing plane)
        +----------------+----------------+
                     DATA NETWORK
              PostgreSQL      Kafka
        KEYCLOAK = identity provider (public OIDC issuer only)
```

## Invariants

- `FRONTEND -> CADDY -> designated BFF -> authorized domain services`
- Never: `FRONTEND -> DOMAIN SERVICE`, `FRONTEND -> DB`, `FRONTEND -> KAFKA`.
- Domain services have **no published ports** and enforce their own JWT +
  resource authorization regardless of caller.
- Network reachability never replaces business authorization.
- Developer Portal is a separate DEV access plane, not application ingress.

## Identity planes

| Plane | Credential | Purpose |
|---|---|---|
| Developer Portal | `agena_session_id` portal session | docs, contracts, authorized API testing |
| Agent BFF | `__Host-iaop_session` HttpOnly cookie + CSRF | agent-facing app APIs |
| Domain services | `Authorization: Bearer` audience-valid JWT | business authorization |

`portal-api-tester` never grants agent permissions. BFF tokens stay
server-side; browsers never see JWTs.

## Edge routing (self-hosted Caddy)

Host-based allowlist only — `self-hosted-dev/proxy/Caddyfile`:

- `{$AGENT_HOST}` -> `iaop-agent-bff:8080`
- `{$PORTAL_HOST}` -> `iaop-developer-portal:8080`
- `{$AUTH_HOST}` -> `keycloak:8080`
- Any other Host -> `404`. No path-based catch-alls into internals.

On InstaBox the platform ingress publishes only BFF (`:8082`) and portal
(`:8083`) ports; domain/data services publish nothing.
