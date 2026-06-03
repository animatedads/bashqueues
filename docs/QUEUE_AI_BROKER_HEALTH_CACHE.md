# Queue AI broker health cache

`queue ai` uses the provider registry as its static inventory, but runtime provider/model availability can change. The local health cache is a small JSON overlay that lets the broker skip unavailable, rate-limited, missing, timed-out, disabled, or cooling-down models before it attempts provider fallback.

The cache is advisory governance data. It is not a credential store, not a provider API client, and not authority for live calls. Live execution remains gated by `QUEUEBASH_AI_LIVE_ENABLED=1` and the existing provider helper policy.

## Paths

Read order:

```text
$QUEUEBASH_AI_BROKER_HEALTH_CACHE
$QUEUEBASH_ROOT/ai-broker/health-cache.json
/etc/bashqueues/policies.d/ai-broker/health-cache.json
./policies.d/ai-broker/health-cache.json
./policies.d/ai-broker/health-cache.example.json
./tests/fixtures/ai_broker/health_cache.example.json
```

Writes go to `$QUEUEBASH_AI_BROKER_HEALTH_CACHE` when set, otherwise to `$QUEUEBASH_ROOT/ai-broker/health-cache.json`.

## Commands

List effective provider/model health:

```sh
queue ai health --json
```

Update a provider/model state:

```sh
queue ai health \
  --provider openai_compat \
  --model local-model \
  --set-state timeout \
  --reason "provider timed out" \
  --cooldown-seconds 60 \
  --json
```

Updates emit schema:

```text
queuebash.ai_broker.health_update.v1
```

## States

Accepted states are:

```text
available
healthy
degraded
rate_limited
auth_failed
model_missing
timeout
disabled_by_policy
disabled_by_cost
cooldown
```

Selection behaviour:

- `available` and `healthy` can be selected.
- `degraded` is skipped unless the profile enables degraded fallback with `AI_ALLOW_DEGRADED_FALLBACK=1` or `AI_ALLOW_DEGRADED_HEALTH=1`.
- `rate_limited`, `auth_failed`, `model_missing`, `timeout`, and active `cooldown` entries are skipped for normal fallback.
- `disabled_by_policy` and `disabled_by_cost` are always skipped.

Explain output includes health rejection reasons such as `health_timeout`, `health_model_missing`, `health_rate_limited`, `health_cooldown`, `health_disabled_by_policy`, and `health_disabled_by_cost`.

## Cache schema

```json
{
  "schema": "queuebash.ai_broker.health_cache.v1",
  "updated_at": "2026-06-03T00:00:00Z",
  "entries": [
    {
      "provider": "openai_compat",
      "model": "local-model",
      "state": "timeout",
      "reason": "provider timed out",
      "updated_at": "2026-06-03T00:00:00Z",
      "cooldown_seconds": 60,
      "cooldown_until_epoch": 1780502460,
      "cooldown_until": "2026-06-03T00:01:00Z"
    }
  ]
}
```
