#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -q 'BOB11 Cerebras ask-provider pack' CHANGELOG.md || fail 'changelog missing cerebras provider entry'
grep -q 'queue-ai-ask-cerebras' queuebash.sh || fail 'queue ask does not resolve cerebras helper'
grep -q 'live_cerebras_provider' queuebash.sh || fail 'cerebras live audit reason missing'
grep -q 'cerebras' queuebash.sh || fail 'cerebras live/provider support missing'
grep -q 'QUEUEBASH_AI_CEREBRAS_ENDPOINT' queuebash.sh || fail 'cerebras help endpoint missing'

test -x bin/queue-ai-ask-cerebras || fail 'cerebras helper missing or not executable'
test -x providers.d/ask/cerebras.sh || fail 'cerebras ask provider descriptor missing or not executable'
test -f docs/ASK_CEREBRAS_PROVIDER.md || fail 'cerebras ask provider doc missing'
test -f policies.d/ask/cerebras.env.example || fail 'cerebras ask policy example missing'
test -f examples/providers/ai/cerebras.env.example || fail 'cerebras provider example missing'

grep -q 'https://api.cerebras.ai/v1/chat/completions' docs/ASK_CEREBRAS_PROVIDER.md || fail 'cerebras doc missing chat completions endpoint note'
grep -q 'QUEUEBASH_AI_CEREBRAS_API_KEY_FILE' bin/queue-ai-ask-cerebras || fail 'cerebras key file lookup missing'
grep -q 'CEREBRAS_API_KEY' bin/queue-ai-ask-cerebras || fail 'standard cerebras key lookup missing'
grep -q 'cerebras_api_key_missing' bin/queue-ai-ask-cerebras || fail 'cerebras missing-key guard absent'
grep -q 'redact_secret_values' bin/queue-ai-ask-cerebras || fail 'cerebras error redaction missing'
grep -q 'queuebash.ai_advisory.response.v1' bin/queue-ai-ask-cerebras || fail 'cerebras normalized response schema missing'
grep -q 'Provider output is data only' docs/ASK_CEREBRAS_PROVIDER.md || fail 'cerebras provider output safety wording missing'
grep -Eq '^cerebras[[:space:]]+yes[[:space:]]+no[[:space:]]+yes' policies.d/ask/providers.tsv.example || fail 'cerebras provider policy row missing'

! grep -R 'CEREBRAS_API_KEY=.*[A-Za-z0-9]' docs/ASK_CEREBRAS_PROVIDER.md policies.d/ask/cerebras.env.example examples/providers/ai/cerebras.env.example >/dev/null || fail 'looks like concrete cerebras key in docs/examples'
! grep -R 'eval .*cerebras\|source .*cerebras\|bash -c .*cerebras' queuebash.sh docs/ASK_CEREBRAS_PROVIDER.md providers.d/ask/cerebras.sh >/dev/null || fail 'unsafe cerebras provider shell execution pattern found'

echo 'PASS ask_cerebras_provider_static'
