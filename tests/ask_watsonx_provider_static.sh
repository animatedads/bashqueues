#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q '0.18.49 - BOB11 ask IBM watsonx.ai live-provider pack' CHANGELOG.md || fail 'changelog missing watsonx provider entry'
grep -q 'queue-ai-ask-watsonx' queuebash.sh || fail 'queue ask does not resolve watsonx helper'
grep -q 'live_watsonx_provider' queuebash.sh || fail 'watsonx live audit reason missing'
grep -q 'watsonx' queuebash.sh || fail 'watsonx live/provider support missing'
grep -q 'QUEUEBASH_AI_WATSONX_PROJECT_ID' queuebash.sh || fail 'watsonx project id help missing'

test -x bin/queue-ai-ask-watsonx || fail 'watsonx helper missing or not executable'
test -x providers.d/ask/watsonx.sh || fail 'watsonx ask provider descriptor missing or not executable'
test -f docs/ASK_WATSONX_PROVIDER.md || fail 'watsonx ask provider doc missing'
test -f policies.d/ask/watsonx.env.example || fail 'watsonx ask policy example missing'
test -f examples/providers/ai/watsonx.env.example || fail 'watsonx provider example missing'

grep -q '/ml/v1/text/generation' docs/ASK_WATSONX_PROVIDER.md || fail 'watsonx doc missing text generation endpoint note'
grep -q 'QUEUEBASH_AI_WATSONX_BEARER_TOKEN_FILE' bin/queue-ai-ask-watsonx || fail 'watsonx bearer token file lookup missing'
grep -q 'IBM_CLOUD_API_KEY' bin/queue-ai-ask-watsonx || fail 'standard IBM Cloud key lookup missing'
grep -q 'redact_secret_values' bin/queue-ai-ask-watsonx || fail 'watsonx error redaction missing'
grep -q 'queuebash.ai_advisory.response.v1' bin/queue-ai-ask-watsonx || fail 'watsonx normalized response schema missing'
grep -q 'Provider output is data, never shell' docs/ASK_WATSONX_PROVIDER.md || fail 'watsonx provider output safety wording missing'
grep -Eq '^watsonx[[:space:]]+yes[[:space:]]+yes[[:space:]]+yes' policies.d/ask/providers.tsv.example || fail 'watsonx provider policy row missing'

! grep -R 'IBM_CLOUD_API_KEY=.*[A-Za-z0-9]' docs/ASK_WATSONX_PROVIDER.md policies.d/ask/watsonx.env.example examples/providers/ai/watsonx.env.example >/dev/null || fail 'looks like concrete IBM key in docs/examples'
! grep -R 'eval .*watsonx\|source .*watsonx\|bash -c .*watsonx' queuebash.sh docs/ASK_WATSONX_PROVIDER.md providers.d/ask/watsonx.sh >/dev/null || fail 'unsafe watsonx provider shell execution pattern found'

echo PASS
