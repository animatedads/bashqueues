#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q 'BOB11 Mistral AI ask-provider pack' CHANGELOG.md || fail 'changelog missing mistral provider entry'
grep -q 'queue-ai-ask-mistral' queuebash.sh || fail 'queue ask does not resolve mistral helper'
grep -q 'live_mistral_provider' queuebash.sh || fail 'mistral live audit reason missing'
grep -q 'mistral' queuebash.sh || fail 'mistral live/provider support missing'
grep -q 'QUEUEBASH_AI_MISTRAL_ENDPOINT' queuebash.sh || fail 'mistral help endpoint missing'

test -x bin/queue-ai-ask-mistral || fail 'mistral helper missing or not executable'
test -x providers.d/ask/mistral.sh || fail 'mistral ask provider descriptor missing or not executable'
test -f docs/ASK_MISTRAL_PROVIDER.md || fail 'mistral ask provider doc missing'
test -f policies.d/ask/mistral.env.example || fail 'mistral ask policy example missing'
test -f examples/providers/ai/mistral.env.example || fail 'mistral provider example missing'

grep -q '/v1/chat/completions' docs/ASK_MISTRAL_PROVIDER.md || fail 'mistral doc missing chat completions endpoint note'
grep -q 'QUEUEBASH_AI_MISTRAL_API_KEY_FILE' bin/queue-ai-ask-mistral || fail 'mistral key file lookup missing'
grep -q 'MISTRAL_API_KEY' bin/queue-ai-ask-mistral || fail 'standard mistral key lookup missing'
grep -q 'mistral_api_key_missing' bin/queue-ai-ask-mistral || fail 'mistral missing-key guard absent'
grep -q 'redact_secret_values' bin/queue-ai-ask-mistral || fail 'mistral error redaction missing'
grep -q 'queuebash.ai_advisory.response.v1' bin/queue-ai-ask-mistral || fail 'mistral normalized response schema missing'
grep -q 'Provider output is data, never shell' docs/ASK_MISTRAL_PROVIDER.md || fail 'mistral provider output safety wording missing'
grep -Eq '^mistral[[:space:]]+yes[[:space:]]+yes[[:space:]]+yes' policies.d/ask/providers.tsv.example || fail 'mistral provider policy row missing'

! grep -R 'MISTRAL_API_KEY=.*[A-Za-z0-9]' docs/ASK_MISTRAL_PROVIDER.md policies.d/ask/mistral.env.example examples/providers/ai/mistral.env.example >/dev/null || fail 'looks like concrete mistral key in docs/examples'
! grep -R 'eval .*mistral\|source .*mistral\|bash -c .*mistral' queuebash.sh docs/ASK_MISTRAL_PROVIDER.md providers.d/ask/mistral.sh >/dev/null || fail 'unsafe mistral provider shell execution pattern found'

echo PASS
