# IAOP Self-Hosted DEV — RAM Allocation Budget
## Target Host: AMD Ryzen 5, 16 GB Physical RAM

---

## 1. Executive Summary & Host Protection Guardrail

In a single-node self-hosted development machine with **16 GB RAM**, running 10+ microservices and distributed platform infrastructure without strict resource boundaries will cause OS thrashing, swap exhaustion, and sudden Out-Of-Memory (OOM) kills.

To guarantee rock-solid stability:
1. **Host OS & Tooling Reserve:** **3.5 GB** is strictly preserved for Windows/Linux OS, Docker daemon, terminal shells, IDE, and developer tools.
2. **Total Docker Workload Ceiling:** **12.5 GB max limit**, with normal runtime steady-state targeted at **~5.5 GB to 7.0 GB**.
3. **Hard Memory Limits (`mem_limit`):** Every container specifies an explicit memory limit to prevent single-process memory leaks from crashing the host.

---

## 2. Container Memory Budget Breakdown

| Container | Service Name | Profile | Memory Limit (`mem_limit`) | Memory Reservation (`mem_reservation`) | Runtime Rationale / JVM Settings |
|---|---|---|---|---|---|
| **iaop-postgres** | PostgreSQL 16 | `foundation` | **1536 MB** | 512 MB | `shared_buffers=512MB`, `work_mem=16MB`, connections capped at 100. |
| **iaop-keycloak** | Keycloak 24 (SSO) | `foundation` | **1024 MB** | 256 MB | `-Xms256m -Xmx768m` JVM heap. |
| **iaop-kafka** | Apache Kafka KRaft 3.7 | `foundation` | **1024 MB** | 256 MB | Single-node KRaft mode; `-Xms256m -Xmx768m`. |
| **iaop-developer-portal** | Swagger Portal (Rust) | `foundation` | **256 MB** | 64 MB | In-memory catalog; static asset serving; negligible footprint. |
| **iaop-caddy** | Caddy Reverse Proxy | `foundation` | **256 MB** | 64 MB | Zero-allocation HTTP proxy & security header injection. |
| **iaop-cloudflared** | Cloudflare Tunnel | `cloudflared` | **256 MB** | 64 MB | Optional zero-trust tunnel ingress. |
| **Subtotal Foundation** | | | **4352 MB (~4.25 GB)** | **1216 MB (~1.18 GB)** | Foundation core running continuously. |
| **iaop-agent-service** | Agent Service (Rust) | `agent` | **384 MB** | 128 MB | Tokio async runtime + SQLx connection pool (max 10). |
| **iaop-agency-service** | Agency Service (Rust) | `agency` | **384 MB** | 128 MB | Hierarchy query engine + SQLx connection pool (max 10). |
| **iaop-agent-bff** | Agent BFF (Rust) | `agent` | **512 MB** | 128 MB | Session store + HTTP client upstream buffers. |
| **iaop-integration-service** | Integration Service (Rust) | `integration` | **512 MB** | 128 MB | Outbox leasing worker + HTTP connector dispatcher. |
| **Subtotal Domain Services** | | | **1792 MB (~1.75 GB)** | **512 MB (~0.5 GB)** | Core business microservices. |
| **iaop-workflow** | Flowable OSS 7.0 | `workflow` | **1536 MB** | 512 MB | Spring Boot + Java 17; `-Xms256m -Xmx1024m`. |
| **Subtotal Workflow** | | | **1536 MB (~1.5 GB)** | **512 MB (~0.5 GB)** | BPMN 2.0 orchestration engine. |
| **iaop-otel-collector** | OpenTelemetry Collector | `observability` | **384 MB** | 128 MB | Memory limiter processor set to 300 MB limit. |
| **iaop-prometheus** | Prometheus TSDB | `observability` | **1024 MB** | 256 MB | In-memory sample buffer; TSDB retention limit 15 GB. |
| **Subtotal Observability** | | | **1408 MB (~1.38 GB)** | **384 MB (~0.37 GB)** | Platform metrics and tracing. |

---

## 3. Total System Allocation Summary

```
Total Physical Host RAM:        16,384 MB (16.0 GB)
Host OS Reserve:                 3,584 MB ( 3.5 GB)
---------------------------------------------------
Available Docker Pool:          12,800 MB (12.5 GB)

Maximum Combined Upper Limit:    9,088 MB ( 8.87 GB) [ALL PROFILES RUNNING]
Standard Dev Working Set:        6,144 MB ( 6.00 GB) [Foundation + Domains]
Guaranteed Minimum Free Headroom: 7,296 MB ( 7.13 GB)
```

## 4. OOM Guard Recommendations

1. **Do not disable memory limits:** Keep `deploy.resources.limits.memory` configured in Compose files.
2. **Selective Profile Usage:** For day-to-day feature development on Agent or Integration features, run only the relevant profiles:
   ```bash
   docker compose --profile foundation --profile agent up -d
   ```
   This keeps total memory usage under **5.0 GB**, leaving **11 GB** for lightning-fast host compilation with `cargo`.
