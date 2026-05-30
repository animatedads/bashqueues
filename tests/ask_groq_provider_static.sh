#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q 'BOB11 Groq ask-provider pack' CHANGELOG.md || fail 'changelog missing groq provider entry'
grep -q 'queue-ai-ask-groq' queuebash.sh || fail 'queue ask does not resolve groq helper'
grep -q 'live_groq_provider' queuebash.sh || fail 'groq live audit reason missing'
grep -q 'groq' queuebash.sh || fail 'groq live/provider support missing'
grep -q 'QUEUEBASH_AI_GROQ_ENDPOINT' queuebash.sh || fail 'groq help endpoint missing'

test -x bin/queue-ai-ask-groq || fail 'groq helper missing or not executable'
test -x providers.d/ask/groq.sh || fail 'groq ask provider descriptor missing or not executable'
test -f docs/ASK_GROQ_PROVIDER.md || fail 'groq ask provider doc missing'
test -f policies.d/ask/groq.env.example || fail 'groq ask policy example missing'
test -f examples/providers/ai/groq.env.example || fail 'groq provider example missing'

grep -q 'https://api.groq.com/openai/v1/chat/completions' docs/ASK_GROQ_PROVIDER.md || fail 'groq doc missing chat completions endpoint note'
grep -q 'QUEUEBASH_AI_GROQ_API_KEY_FILE' bin/queue-ai-ask-groq || fail 'groq key file lookup missing'
grep -q 'GROQ_API_KEY' bin/queue-ai-ask-groq || fail 'standard groq key lookup missing'
grep -q 'groq_api_key_missing' bin/queue-ai-ask-groq || fail 'groq missing-key guard absent'
grep -q 'redact_secret_values' bin/queue-ai-ask-groq || fail 'groq error redaction missing'
grep -q 'queuebash.ai_advisory.response.v1' bin/queue-ai-ask-groq || fail 'groq normalized response schema missing'
grep -q 'Provider output is data only' docs/ASK_GROQ_PROVIDER.md || fail 'groq provider output safety wording missing'
grep -Eq '^groq[[:space:]]+yes[[:space:]]+no[[:space:]]+yes' policies.d/ask/providers.tsv.example || fail 'groq provider policy row missing'

! grep -R 'GROQ_API_KEY=.*[A-Za-z0-9]' docs/ASK_GROQ_PROVIDER.md policies.d/ask/groq.env.example examples/providers/ai/groq.env.example >/dev/null || fail 'looks like concrete groq key in docs/examples'
! grep -R 'eval .*groq\|source .*groq\|bash -c .*groq' queuebash.sh docs/ASK_GROQ_PROVIDER.md providers.d/ask/groq.sh >/dev/null || fail 'unsafe groq provider shell execution pattern found'

echo PASS
