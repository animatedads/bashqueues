# queue AI broker implementation

0.18.79 adds the first runtime implementation of the `queue ai` broker surface.

The implementation is intentionally conservative:

- it loads AI profiles from `policies.d/ai-profiles/*.env` or `/etc/bashqueues/policies.d/ai-profiles/*.env`;
- it loads the provider registry from `policies.d/ai-broker/provider-registry*.json` or `/etc/bashqueues/policies.d/ai-broker/provider-registry.json`;
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
