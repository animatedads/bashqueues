# queue AI broker live-call delegation

Version: 0.18.83 Bob11 queue AI broker live-call delegation

This document describes the first runtime bridge from `queue ai` broker selection to
existing ask-provider helpers.

## Purpose

Earlier AI broker runtime work selected a provider/model and returned advisory JSON
without making a provider call. This patch keeps that safe default, but adds an
explicit governed execution path:

```bash
queue ai chat --profile balanced --message "Summarise this" --live --json
queue ai json --profile json_strict --message '{"hello":"world"}' --live --json
```

Live delegation is blocked unless:

```bash
QUEUEBASH_AI_LIVE_ENABLED=1
```

Credentials alone are not sufficient.

## Selection and delegation

The broker still resolves provider/model using the profile, provider registry,
capability requirements, health state, locality/cloud policy, estimated cost, and
policy links.

When `--live` is supplied and live mode is enabled, the broker delegates to the
selected provider helper, for example:

```text
openai_compat -> bin/queue-ai-ask-openai-compat
mistral       -> bin/queue-ai-ask-mistral
groq          -> bin/queue-ai-ask-groq
cerebras      -> bin/queue-ai-ask-cerebras
perplexity    -> bin/queue-ai-ask-perplexity
```

The broker writes a normalised `queuebash.ai_advisory.request.v1` JSON request to
a temporary file, invokes the helper with `--request-json` and `--output-json`, and
normalises the helper response back to:

```text
queuebash.ai_broker.response.v1
```

## Fallback

If `AI_FALLBACK_ENABLED=1`, the broker may attempt the next viable candidate when
the selected helper fails, times out, is missing, or returns an error response.
The returned JSON records fallback evidence:

```json
{
  "fallback": {
    "used": true,
    "attempted": [
      {"provider": "anthropic", "model": "claude-default"}
    ],
    "reason": "first_viable_provider_failed"
  }
}
```

If no candidate succeeds, the broker returns a fail-closed error response and does
not fabricate provider output.

## Safety boundary

The brokered live-call path remains advisory only:

```text
- no model output is executed
- no provider credentials are logged by the broker
- no live call occurs without QUEUEBASH_AI_LIVE_ENABLED=1
- provider helpers retain their own credential lookup and network policy behaviour
- regulatory/corporate/privacy/data-residency/export-control/audit policy links are preserved in the broker response
```

Default tests do not call real providers. The live-call smoke test uses a local
fixture helper injected through `QUEUEBASH_AI_OPENAI_COMPAT_HELPER`.
