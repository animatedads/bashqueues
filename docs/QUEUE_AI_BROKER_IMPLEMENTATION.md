# queue AI broker implementation

0.18.79 adds the first runtime implementation of the `queue ai` broker surface.

The implementation is intentionally conservative:

- it loads AI profiles from `policies.d/ai-profiles/*.env` or `/etc/queuebash/policies.d/ai-profiles/*.env`;
- it loads the provider registry from `policies.d/ai-broker/provider-registry*.json` or `/etc/queuebash/policies.d/ai-broker/provider-registry.json`;
- it scores providers/models by profile order, required capabilities, health state, locality, and approximate cost;
- it exposes provider/model inventory, health, explain, and selection-only chat/json responses;
- it performs no live provider call in this implementation stage.

## Commands

```sh
queue ai providers --json
queue ai models --json
queue ai health --json
queue ai explain --profile balanced --capability chat,json --json
queue ai chat --profile balanced --message "Summarise this" --json
queue ai json --profile json_strict --message '{"hello":"world"}' --json
```

`queue ai chat` and `queue ai json` currently return normalised broker selection
responses with `live_call_performed=false`. Future patches may delegate selected
requests to `queue ask` provider helpers when policy allows live calls.

## Fail closed

The broker denies selection when no provider/model satisfies all required
profile constraints. Common denial reasons include:

- provider not in profile order;
- cloud/locality not allowed;
- health state not available;
- missing required capability;
- cost ceiling exceeded.

## Boundaries

The broker does not execute model output, provision resources, edit policy, read
secrets, or perform live API calls by default. It is a governed selection layer
above existing `queue ask` provider packs.

## Policy links in decisions

0.18.80 adds `policy_links` to broker explain and selection responses. Profiles, providers, and individual models may reference regulatory, corporate, privacy, data-residency, export-control, and audit policy records. The broker merges applicable links into its JSON response so a job or reviewer can see which governance documents apply to the selection.

See `docs/QUEUE_AI_BROKER_POLICY_LINKS.md`.


## 0.18.83 live-call delegation

`queue ai chat` and `queue ai json` still default to selection-only mode. When `--live` is provided and `QUEUEBASH_AI_LIVE_ENABLED=1` is set, `bin/queue-ai-broker` now delegates to the selected provider helper using the existing ask-provider `--request-json` / `--output-json` contract. The broker returns normalized `queuebash.ai_broker.response.v1` JSON and records whether fallback was used.

No default test performs a real network call. The smoke test injects a local fake helper through the provider helper environment override.

## Baseten provider note

Baseten Model APIs are represented as an OpenAI-compatible cloud inference provider. Live use is gated, credential lookup is file/env based, and AI broker decisions should surface applicable corporate/vendor, privacy, data-residency, and audit policy references when configured.

## 0.18.98 health-cache fallback evidence

The broker now overlays static registry health hints with a local health cache. This keeps provider selection fixture-first while allowing runtime evidence to mark a provider/model as timed out, rate-limited, missing, disabled, degraded, or cooling down.

The health cache is documented in `docs/QUEUE_AI_BROKER_HEALTH_CACHE.md`. It is consumed before model selection, and explain output records health rejection reasons so reviewers can see why fallback skipped a candidate.

Example:

```sh
queue ai health \
  --provider openai_compat \
  --model local-model \
  --set-state timeout \
  --reason "provider timed out" \
  --cooldown-seconds 60 \
  --json
```

This emits `queuebash.ai_broker.health_update.v1`. Subsequent `queue ai explain --json` and brokered calls skip that model while the cooldown is active and report `health_cooldown` or the relevant health state in rejected-candidate evidence.


## 0.18.101 live health feedback

The broker now records bounded local health feedback during explicitly enabled brokered live calls. If a selected helper times out, rate-limits, rejects credentials, reports a missing model, or otherwise fails, the broker writes a health-cache update with a short cooldown and attempts the next selected fallback candidate. Successful provider calls restore that provider/model to `available`.

This remains fixture-first and local: live execution is still blocked unless `QUEUEBASH_AI_LIVE_ENABLED=1`, credentials alone are not authority, and feedback is advisory evidence rather than policy authority. JSON responses include `health_feedback` entries with schema `queuebash.ai_broker.health_feedback.v1`.
