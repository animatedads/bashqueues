# Grid Energy Cost Model

`0.18.69` adds a fixture-first Grid FinOps contract for businesses whose jobs
are exposed to real-time electricity prices or carbon-intensity targets.

The package deliberately separates three layers:

1. **Collectors** refresh local market/carbon cache files from approved sources
   such as ERCOT, Nord Pool, ENTSO-E, UK ESO, or a site-local utility feed.
   Collectors are outside the worker preflight path and are not implemented here.
2. **The grid-energy provider** evaluates normalized local JSON observations and
   emits allow/deny JSON. It performs no live HTTP calls.
3. **The `grid_energy` asset plugin** lets queue classes block dispatch when
   price/carbon policy is not satisfied.

This means a queue worker can safely answer: "is power cheap/green enough to run
this non-essential job now?" without credentials, network access, or access to
industrial control systems.

## Normalized observation

```json
{
  "schema": "queuebash.grid_energy_observation.v1",
  "market": "uk_eso",
  "zone": "GB",
  "source": "fixture",
  "observed_at_epoch": 1780000000,
  "price_per_kwh": 0.104,
  "carbon_gco2_kwh": 91.2
}
```

The cache is intentionally provider-neutral. A separate approved collector may
translate an ERCOT node price, a Nord Pool bidding-zone price, an ENTSO-E zone,
or a UK ESO carbon feed into this schema.

## Dispatch gates

Examples:

```bash
queue_class_shared_asset grid_energy price_below 0.15 \
  cache_file=/var/cache/bashqueues/grid-energy/uk_eso_gb.json \
  market=uk_eso zone=GB max_age_seconds=900

queue_class_shared_asset grid_energy carbon_below 120 \
  cache_file=/var/cache/bashqueues/grid-energy/entsoe_de_lu.json \
  market=entsoe zone=DE_LU max_age_seconds=900

queue_class_shared_asset grid_energy negative_price _ \
  cache_file=/var/cache/bashqueues/grid-energy/nordpool_se3.json \
  market=nordpool zone=SE3 max_age_seconds=900
```

Missing, stale, malformed, mismatched, expensive, or high-carbon cache data is a
block by default.

## OT/ICS boundary

This package does **not** write to OPC UA, SCADA, Kepware, MQTT, Sparkplug B, or
cloud IoT platforms. Those are future control-plane providers and must be
separately ACL-gated, dual-control approved, audited, and read/write scoped.

Grid energy policy should first control ordinary queue dispatch for safe,
interruptible IT workloads. Industrial actuation belongs behind stronger OT
change-control rails.
