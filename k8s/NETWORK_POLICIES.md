# Kubernetes NetworkPolicy intent (iaop namespace)

`base/default-deny-networkpolicy.yaml` denies all ingress/egress by default;
`allow-dns-egress` permits DNS. `apps/api-docs/networkpolicy.yaml` is the
reference per-workload policy.

## Intended policies as workloads are added

| Workload | Ingress | Egress |
|---|---|---|
| ingress controller / edge | -> BFF pods, -> developer-portal (DEV only) | DNS |
| agent-bff | edge only | agent-service, agency-service, eligibility-service, keycloak (JWKS/token), its DB |
| operations-bff (future) | edge only | staff-authorized domain services, keycloak, its DB |
| domain services | ONLY from authorized BFF/worker pods — never from ingress namespace | own DB schema, kafka, keycloak JWKS, approved peers |
| developer-portal | DEV-controlled ingress only | allowlisted domain services for /dev-api testing |
| postgres / kafka | domain/data pods only | — |

## Rules

- Ingress controller must NEVER route to domain services.
- Domain services enforce JWT + resource authz independently; NetworkPolicy
  is workload segmentation, not authorization.
- Verify CNI NetworkPolicy support before claiming enforcement
  (`kubectl get pods -n kube-system` CNI / test from unauthorized pod).
