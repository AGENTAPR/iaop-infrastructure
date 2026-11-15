# Rust API Gateway Retirement Report

Date: 2026-11-15
Repository: `AGENTAPR/iaop-api-gateway`
Remote HEAD at retirement: `c26a33b330be0ab5209f7e988580a115f5e3973e`
("feat: scaffold iaop-api-gateway microservice" — single scaffold commit)

## Capability audit

The repository contains only a Rust/Axum scaffold: health, readiness,
system-info and OpenAPI endpoints. No routing, rate-limiting, auth, or
orchestration logic exists that Caddy + BFFs do not already provide.

## Dependency discovery (all workspace repos)

Searched `iaop-api-gateway`, `api-gateway`, `GATEWAY_URL`,
`GATEWAY_BASE_URL`, `gateway-service` across all repositories:

- **Runtime/config references: NONE** in any service, BFF, compose file,
  k8s manifest, Keycloak config, or env file.
- Catalog references removed in `iaop-api-contracts@7d72121`:
  `catalog/services.yaml` entry, `catalog/manifest.development.json`
  artifact, `specs/development/api-gateway/openapi.json`.
- Documentation mentions in `iaop-architecture/docs/*` are historical
  landscape/governance records — retained as history, not active config.

## Recovery archive (verified)

- `iaop-workspace/backup-iaop-api-gateway.bundle` and
  `backup2-iaop-api-gateway.bundle` — `git bundle verify` reports
  "The bundle records a complete history" for both.
- Local clone `iaop-workspace/iaop-api-gateway` retains full history.

## GitHub repository deletion: BLOCKED

`gh repo delete AGENTAPR/iaop-api-gateway` →
`HTTP 403: Must have admin rights to Repository` / token lacks `delete_repo`
scope. Required action: an org admin runs
`gh auth refresh -s delete_repo` then `gh repo delete AGENTAPR/iaop-api-gateway --yes`,
or deletes via GitHub UI. All runtime dependencies are already removed, so
deletion is safe to perform at any time.
