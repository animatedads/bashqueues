#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q 'BOB11 DeepSeek ask-provider pack' CHANGELOG.md || fail 'changelog missing deepseek provider entry'
grep -q 'queue-ai-ask-deepseek' queuebash.sh || fail 'queue ask does not resolve deepseek helper'
grep -q 'live_deepseek_provider' queuebash.sh || fail 'deepseek live audit reason missing'
grep -q 'deepseek' queuebash.sh || fail 'deepseek live/provider support missing'
grep -q 'QUEUEBASH_AI_DEEPSEEK_ENDPOINT' queuebash.sh || fail 'deepseek help endpoint missing'

test -x bin/queue-ai-ask-deepseek || fail 'deepseek helper missing or not executable'
test -x providers.d/ask/deepseek.sh || fail 'deepseek ask provider descriptor missing or not executable'
test -f docs/ASK_DEEPSEEK_PROVIDER.md || fail 'deepseek ask provider doc missing'
test -f policies.d/ask/deepseek.env.example || fail 'deepseek ask policy example missing'
test -f examples/providers/ai/deepseek.env.example || fail 'deepseek provider example missing'

grep -q 'https://api.deepseek.com/chat/completions' docs/ASK_DEEPSEEK_PROVIDER.md || fail 'deepseek doc missing chat completions endpoint note'
grep -q 'QUEUEBASH_AI_DEEPSEEK_API_KEY_FILE' bin/queue-ai-ask-deepseek || fail 'deepseek key file lookup missing'
grep -q 'DEEPSEEK_API_KEY' bin/queue-ai-ask-deepseek || fail 'standard deepseek key lookup missing'
grep -q 'deepseek_api_key_missing' bin/queue-ai-ask-deepseek || fail 'deepseek missing-key guard absent'
grep -q 'redact_secret_values' bin/queue-ai-ask-deepseek || fail 'deepseek error redaction missing'
grep -q 'queuebash.ai_advisory.response.v1' bin/queue-ai-ask-deepseek || fail 'deepseek normalized response schema missing'
grep -q 'Provider output is data only' docs/ASK_DEEPSEEK_PROVIDER.md || fail 'deepseek provider output safety wording missing'
grep -Eq '^deepseek[[:space:]]+yes[[:space:]]+no[[:space:]]+yes' policies.d/ask/providers.tsv.example || fail 'deepseek provider policy row missing'

! grep -R 'DEEPSEEK_API_KEY=.*[A-Za-z0-9]' docs/ASK_DEEPSEEK_PROVIDER.md policies.d/ask/deepseek.env.example examples/providers/ai/deepseek.env.example >/dev/null || fail 'looks like concrete deepseek key in docs/examples'
! grep -R 'eval .*deepseek\|source .*deepseek\|bash -c .*deepseek' queuebash.sh docs/ASK_DEEPSEEK_PROVIDER.md providers.d/ask/deepseek.sh >/dev/null || fail 'unsafe deepseek provider shell execution pattern found'

echo PASS
