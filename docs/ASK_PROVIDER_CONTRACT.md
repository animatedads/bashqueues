# queue ask provider contract

`queue ask` is an advisory interface. It may explain, summarize, and suggest safe operator commands, but provider output is data and is never evaluated as shell.

This package adds the provider-neutral socket for future AI providers. The default test path is fixture-first and performs no live API calls.

## Commands

```text
queue ask providers [--json]
queue ask provider explain PROVIDER [--json]
queue ask provider test PROVIDER --fixture [--json]
queue ask --provider PROVIDER --context docs,commands --json "question"
```

## Discovery schema

```json
{
  "schema": "queuebash.ask_provider.discovery.v1",
  "provider": "fixture",
  "available": true,
  "live_enabled": false,
  "requires_network": false,
  "supports_streaming": false,
  "supports_json": true,
  "supports_context_refs": true,
  "supports_fixture": true,
  "live_supported": false,
  "policy": {
    "allowed": true,
    "reason": "fixture_or_contract_mode_allowed"
  }
}
```

## Response schema

```json
{
  "schema": "queuebash.ask_provider.response.v1",
  "provider": "fixture",
  "status": "ok",
  "answer_markdown": "Fixture response",
  "live_call_performed": false,
  "advisory_only": true,
  "usage": {
    "input_tokens": 0,
    "output_tokens": 0
  }
}
```

## Provider rule

Provider-specific request and response translation belongs under `providers.d/ask/` or bounded helper scripts. `queuebash.sh` may dispatch, build/redact context, apply policy, and audit, but should not learn every provider API shape.

## Live mode rule

Default tests are fixture-only. Live provider use is gated by `QUEUEBASH_AI_LIVE_ENABLED=1` and provider policy. API keys must not appear in command lines, scratchpad notes, logs, examples, package zips, or committed policy files.

## OpenAI provider pack

`0.18.46` carries Bob11's optional OpenAI provider descriptor and bounded helper onto the Bob12 dev file registry base. The provider is live-capable but default tests remain fixture-first. Live use still requires `QUEUEBASH_AI_LIVE_ENABLED=1` plus an OpenAI API key supplied by file or environment. Provider-specific OpenAI API translation is contained in `bin/queue-ai-ask-openai` and `providers.d/ask/openai.sh`.

## Anthropic provider pack

`0.18.46` carries Bob11's optional Anthropic provider descriptor and bounded helper onto the Bob12 dev file registry base. The provider remains advisory-only, fixture/gated in default tests, and live use requires `QUEUEBASH_AI_LIVE_ENABLED=1` plus an Anthropic API key supplied by file or environment. Provider-specific Anthropic Messages API translation is contained in `bin/queue-ai-ask-anthropic` and `providers.d/ask/anthropic.sh`.


## IBM watsonx.ai provider note

The `watsonx` provider follows the same normalized ask-provider contract as OpenAI and Anthropic. It is live-capable, network-required, advisory-only, fixture-testable by default, and gated by `QUEUEBASH_AI_LIVE_ENABLED` plus provider policy.

## OpenAI-compatible local/private provider

`openai_compat` is a live-capable ask provider for controlled OpenAI-style chat-completions endpoints. Provider-specific request/response translation belongs in `bin/queue-ai-ask-openai-compat` and `providers.d/ask/openai_compat.sh`; `queuebash.sh` only dispatches, gates, redacts, and audits. Default tests remain fixture/gated and do not require a live endpoint.

## Mistral AI provider

The `mistral` provider is a live-capable, fixture-gated ask provider for the Mistral AI chat completions endpoint family. Provider-specific HTTP translation belongs in `bin/queue-ai-ask-mistral`; `queuebash.sh` only performs provider selection, policy gating, context bundle creation, and audit handling.


## DeepSeek provider

`0.18.55` adds a DeepSeek provider descriptor and bounded helper. It uses the same queuebash advisory request/response contract as the other live providers and remains fixture-first by default. Live use requires `QUEUEBASH_AI_LIVE_ENABLED=1` and a DeepSeek API key supplied by file or environment. Provider-specific API translation is contained in `bin/queue-ai-ask-deepseek` and `providers.d/ask/deepseek.sh`.


## Groq provider note

The Groq provider is a live-capable, fixture-tested ask provider using an OpenAI-compatible chat completions endpoint. It is advisory-only and gated by QUEUEBASH_AI_LIVE_ENABLED plus provider policy.

## Cerebras provider

`cerebras` is a live-capable, fixture-tested provider descriptor using `queue-ai-ask-cerebras` and normalized `queuebash.ai_advisory.response.v1` output.


## Perplexity Sonar provider

The Perplexity provider is fixture-gated by default, uses the same advisory-only `queue ask` contract, and requires explicit live enablement plus a site-managed API key for live calls.

## Related non-AI provider sockets

`0.18.71` carries `providers.d/grid_energy/grid_energy_provider.sh` as a separate non-AI Grid FinOps provider. It follows the same fixture-first, no-live-default, bounded-JSON philosophy as ask providers, but it is used by asset/class policy gates rather than by `queue ask`.

## Baseten provider note

Baseten Model APIs are represented as an OpenAI-compatible cloud inference provider. Live use is gated, credential lookup is file/env based, and AI broker decisions should surface applicable corporate/vendor, privacy, data-residency, and audit policy references when configured.
