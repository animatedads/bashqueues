#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -q 'BOB11 Baseten ask-provider coverage' CHANGELOG.md || fail 'changelog missing baseten provider entry'
grep -q 'queue-ai-ask-baseten' queuebash.sh || fail 'queue ask does not resolve baseten helper'
grep -q 'live_baseten_provider' queuebash.sh || fail 'baseten live audit reason missing'
grep -q 'baseten' queuebash.sh || fail 'baseten live/provider support missing'
grep -q 'QUEUEBASH_AI_BASETEN_ENDPOINT' queuebash.sh || fail 'baseten help endpoint missing'

test -x bin/queue-ai-ask-baseten || fail 'baseten helper missing or not executable'
test -x providers.d/ask/baseten.sh || fail 'baseten ask provider descriptor missing or not executable'
test -f docs/ASK_BASETEN_PROVIDER.md || fail 'baseten ask provider doc missing'
test -f policies.d/ask/baseten.env.example || fail 'baseten ask policy example missing'
test -f examples/providers/ai/baseten.env.example || fail 'baseten provider example missing'

grep -q 'https://inference.baseten.co/v1/chat/completions' docs/ASK_BASETEN_PROVIDER.md || fail 'baseten doc missing Model APIs endpoint note'
grep -q 'https://model-{model_id}.api.baseten.co/environments/production/sync/v1/chat/completions' docs/ASK_BASETEN_PROVIDER.md || fail 'baseten doc missing custom deployment endpoint note'
grep -q 'QUEUEBASH_AI_BASETEN_API_KEY_FILE' bin/queue-ai-ask-baseten || fail 'baseten key file lookup missing'
grep -q 'BASETEN_API_KEY' bin/queue-ai-ask-baseten || fail 'standard baseten key lookup missing'
grep -q 'baseten_api_key_missing' bin/queue-ai-ask-baseten || fail 'baseten missing-key guard absent'
grep -q 'redact_secret_values' bin/queue-ai-ask-baseten || fail 'baseten error redaction missing'
grep -q 'queuebash.ai_advisory.response.v1' bin/queue-ai-ask-baseten || fail 'baseten normalized response schema missing'
grep -q 'Provider output is data only' docs/ASK_BASETEN_PROVIDER.md || fail 'baseten provider output safety wording missing'
grep -Eq '^baseten[[:space:]]+yes[[:space:]]+no[[:space:]]+yes' policies.d/ask/providers.tsv.example || fail 'baseten provider policy row missing'

grep -q 'baseten' policies.d/ai-broker/provider-registry.example.json || fail 'AI broker registry missing baseten entry'
grep -q 'BASETEN_PROVIDER_APPROVAL' policies.d/ai-broker/provider-registry.example.json || fail 'baseten policy reference missing from broker registry'

! grep -R 'BASETEN_API_KEY=.*[A-Za-z0-9]' docs/ASK_BASETEN_PROVIDER.md policies.d/ask/baseten.env.example examples/providers/ai/baseten.env.example >/dev/null || fail 'looks like concrete baseten key in docs/examples'
! grep -R 'eval .*baseten\|source .*baseten\|bash -c .*baseten' queuebash.sh docs/ASK_BASETEN_PROVIDER.md providers.d/ask/baseten.sh >/dev/null || fail 'unsafe baseten provider shell execution pattern found'

echo 'PASS ask_baseten_provider_static'
