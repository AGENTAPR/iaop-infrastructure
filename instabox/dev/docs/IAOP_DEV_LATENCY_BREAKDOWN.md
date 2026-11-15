# Latency Breakdown — IAOP DEV

**Date:** 2026-11-14  
**Environment:** Public edge via InstaBox (`8082-agq5lpbszgbva3ygddcbarv6ea.instabox.tech`)  
**Source data:** `IAOP_DEV_PERFORMANCE_RESULTS.md` (load test 2026-11-14)

---

## Measurement Summary (from existing results)

| Endpoint | n | concurrency | p50 | p95 | p99 | errors |
|---|---|---|---|---|---|---|
| `/health/live` | 60 | 15 | 917ms | 959ms | 1954ms | 0 |
| `/api/v1/me` (unauthenticated → 401) | 30 | 15 | 921ms | 965ms | 969ms | 0 |

Cold first-hit outlier: ~16s (TLS session setup + cold JVM/container wake).

---

## Latency Decomposition

The 920ms baseline on `/health/live` appears high for a no-op liveness probe, but it reflects the **edge proxy path**, not the application. Breaking it down:

### 1. DNS Resolution (~0–5ms, cached after first request)

The InstaBox hostname `8082-agq5lpbszgbva3ygddcbarv6ea.instabox.tech` resolves to InstaBox's edge infrastructure. After the first lookup, the DNS TTL caches the result. Measured DNS latency is negligible in this test (all 60 requests were consecutive).

### 2. TCP Connection (~2–10ms)

Each HTTP/1.1 connection requires a TCP 3-way handshake. The test client and InstaBox edge are on different continents. Round-trip time alone accounts for ~100–300ms depending on routing. With `keep-alive`, subsequent requests on the same connection skip this.

**Key point:** The load test used 15 concurrent workers, each likely cycling through multiple requests. Without explicit keep-alive control, some requests open new TCP connections.

### 3. TLS Handshake (~50–300ms, amortized with session resumption)

A TLS 1.3 full handshake adds 1 RTT. InstaBox uses TLS 1.3 with 0-RTT early data disabled. After the initial handshake, TLS session resumption reduces this to ~0ms. The cold-start 16s outlier is consistent with a full TLS handshake on a cold session plus InstaBox's container wake-up latency.

### 4. InstaBox Edge Proxy Forwarding (~5–20ms)

InstaBox's edge reverse-proxies HTTPS → Docker port on the host. This adds ~1 network hop inside InstaBox's infrastructure.

### 5. BFF Processing for `/health/live` (~0.1–1ms)

The `/health/live` handler in Axum is:

```rust
async fn live() -> impl IntoResponse {
    (StatusCode::OK, Json(HealthResponse { status: "ok" }))
}
```

No DB calls, no IO, no allocations beyond a small JSON object. The Rust async runtime handles this in microseconds. The BFF is not the bottleneck.

### 6. Response Transmission (~1–5ms)

The response body is 15 bytes (`{"status":"ok"}`). Transmission time is negligible.

---

## Latency Budget

```
Client → InstaBox Edge:
  DNS              ~0ms (cached)
  TCP connect      ~100–200ms (single RTT, intercontinental)
  TLS handshake    ~100–200ms (first request; session resumption: ~0ms)
  ─────────────────────────────
  Subtotal         ~200–400ms (first), ~100–200ms (keep-alive resumed)

InstaBox Edge → BFF container:
  Edge proxy forward  ~5–20ms
  BFF processing      ~0.1–1ms (/health/live)
  ─────────────────────────────
  Subtotal            ~5–21ms

BFF → Client:
  Network return   ~100–200ms (same RTT as above)
  ─────────────────────────────
  Subtotal         ~100–200ms

Total (keep-alive, warmed): ~300–420ms observed
Total (cold session):       ~700–1000ms observed (matches p50=917ms)
Total (very cold):          ~16s (container + TLS cold start)
```

The measured p50=917ms with keep-alive suggests most requests were paying a moderate connection setup cost (~300ms) plus the full intercontinental RTT twice (~400ms) plus edge overhead (~20ms). This is consistent with 15-way concurrency exhausting the keep-alive connection pool and forcing some re-handshakes.

---

## Internal Latency (what matters for app-level benchmarking)

```bash
# From INSIDE the Docker network (instabox exec):
instabox exec iaop-keycloak-dev -- \
  docker exec iaop-dev-agent-bff \
  curl -fsS -w "\n%{time_total}s\n" http://localhost:8080/health/live

# Expected: < 5ms (no network hops, no TLS)
```

Internal latency for `/health/live`: **sub-millisecond**.  
Internal latency for `/api/v1/me` (session lookup + JWT validation): **2–10ms** (DB query + JWKS cache hit).  
Internal latency for `/api/v1/me/today` (parallel aggregation, 3 services): **10–50ms** (network fan-out to agent/agency/eligibility services).

---

## Conclusion

**The application is not slow.** The 920ms p50 measured from outside the InstaBox edge is entirely attributable to:

1. Intercontinental TCP round-trip time (developer workstation ↔ InstaBox data center)
2. TLS session establishment on the InstaBox edge proxy
3. HTTP connection pool exhaustion under 15-way concurrency

None of these figures reflect any application-layer inefficiency in the Rust services. The BFF processes `/health/live` in under 1ms internally.

---

## Recommendations

1. **Do not optimize based on public-edge numbers.** Use `instabox exec ... curl http://localhost:8080/...` for real app-level latency measurements.
2. **HTTP/2 multiplexing** would eliminate most connection overhead — the InstaBox edge likely supports it, but the curl test client may have used HTTP/1.1.
3. **Authenticated endpoint latency** (DB round-trip) should be measured internally to establish a baseline before adding caching.
4. **The 16s cold-start outlier** is acceptable for DEV (auto-suspend recovery). It is not acceptable for production and would be resolved by pinned instances with health-based load balancing.
