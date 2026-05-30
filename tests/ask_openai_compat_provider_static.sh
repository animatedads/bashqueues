#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q '0.18.50 - BOB11 OpenAI-compatible local/private ask-provider pack' CHANGELOG.md || fail 'changelog missing openai_compat provider entry'
grep -q 'queue-ai-ask-openai-compat' queuebash.sh || fail 'queue ask does not resolve openai_compat helper'
grep -q 'live_openai_compat_provider' queuebash.sh || fail 'openai_compat live audit reason missing'
grep -q 'openai_compat' queuebash.sh || fail 'openai_compat live/provider support missing'
grep -q 'QUEUEBASH_AI_OPENAI_COMPAT_ENDPOINT' queuebash.sh || fail 'openai_compat help endpoint missing'

test -x bin/queue-ai-ask-openai-compat || fail 'openai_compat helper missing or not executable'
test -x providers.d/ask/openai_compat.sh || fail 'openai_compat ask provider descriptor missing or not executable'
test -f docs/ASK_OPENAI_COMPAT_PROVIDER.md || fail 'openai_compat ask provider doc missing'
test -f policies.d/ask/openai_compat.env.example || fail 'openai_compat ask policy example missing'
test -f examples/providers/ai/openai_compat.env.example || fail 'openai_compat provider example missing'

grep -q '/v1/chat/completions' docs/ASK_OPENAI_COMPAT_PROVIDER.md || fail 'openai_compat doc missing chat completions endpoint note'
grep -q 'QUEUEBASH_AI_OPENAI_COMPAT_API_KEY_FILE' bin/queue-ai-ask-openai-compat || fail 'openai_compat key file lookup missing'
grep -q 'OPENAI_COMPAT_API_KEY' bin/queue-ai-ask-openai-compat || fail 'standard openai_compat key lookup missing'
grep -q 'redact_secret_values' bin/queue-ai-ask-openai-compat || fail 'openai_compat error redaction missing'
grep -q 'queuebash.ai_advisory.response.v1' bin/queue-ai-ask-openai-compat || fail 'openai_compat normalized response schema missing'
grep -q 'Provider output is data, never shell' docs/ASK_OPENAI_COMPAT_PROVIDER.md || fail 'openai_compat provider output safety wording missing'
grep -Eq '^openai_compat[[:space:]]+yes[[:space:]]+yes[[:space:]]+no' policies.d/ask/providers.tsv.example || fail 'openai_compat provider policy row missing'

! grep -R 'OPENAI_COMPAT_API_KEY=.*[A-Za-z0-9]' docs/ASK_OPENAI_COMPAT_PROVIDER.md policies.d/ask/openai_compat.env.example examples/providers/ai/openai_compat.env.example >/dev/null || fail 'looks like concrete openai_compat key in docs/examples'
! grep -R 'eval .*openai_compat\|source .*openai_compat\|bash -c .*openai_compat' queuebash.sh docs/ASK_OPENAI_COMPAT_PROVIDER.md providers.d/ask/openai_compat.sh >/dev/null || fail 'unsafe openai_compat provider shell execution pattern found'

echo PASS
