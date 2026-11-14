# Cost Comparison (DEV scope)

| Architecture | Monthly incremental cost | Notes |
|---|---|---|
| A. All-in-one InstaBox (SELECTED) | $0 | Existing sandbox allowance; ports already published |
| B. + managed Postgres (Neon/Supabase free tier) | $0–$19 | Free tiers suspend on idle — bad for always-on DEV |
| C. + managed Kafka (Confluent/Aiven free) | $0 limited | Free tiers have throughput/retention caps; egress latency to sandbox |
| D. InstaBox Keycloak + external compute | $10–40+ | Unnecessary at current scale |

Assumptions: existing Pro plan covers the sandbox; no new subscription. Recommendation: Option A; revisit if team grows beyond ~25 concurrent DEV users or 24/7 availability is required.
