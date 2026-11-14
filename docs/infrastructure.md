# IAOP Infrastructure

Target platform: Kubernetes. This repo holds cluster-level manifests and
environment configuration; per-service Deployments/Services live in each
service repo under `deploy/k8s/` (added when services are deployed).

## Layout

- `k8s/base/` — cluster foundations: namespace, default-deny
  NetworkPolicies, shared ConfigMaps/Secrets *templates* (no real
  secrets — use External Secrets / sealed secrets).
- `docs/` — environment topology, decision records.

## Decisions pending

- GitOps tooling (ArgoCD vs Flux) — to be decided before first deploy.
- Secret management: External Secrets Operator vs Sealed Secrets.
- Ingress/controller: nginx-ingress vs Gateway API.

## Rules

- No production auto-deploy from `main` CI (see
  `iaop-architecture/docs/standards/IAOP_CICD_MAIN_ONLY_POLICY.md`).
- Manifests must be valid YAML; `kubectl --dry-run=client` where possible.
- Secrets never committed; use placeholders + external secret refs only.
