#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(49|([5-9][0-9]|[1-9][0-9][0-9]))"' queuebash.sh || fail 'version not compatible with 0.18.49+ current package'
# Preserve the OpenAI provider delivery ledger while allowing later Bob11 packages to advance version.
grep -q '0.18.43 - BOB11 ask OpenAI live-provider pack' CHANGELOG.md || fail 'changelog missing OpenAI provider entry'
grep -q 'queue-ai-ask-openai' queuebash.sh || fail 'queue ask does not resolve OpenAI helper'
grep -q 'live_openai_provider' queuebash.sh || fail 'OpenAI live audit reason missing'
grep -q 'openai' queuebash.sh || fail 'OpenAI live/provider support missing'
grep -q 'QUEUEBASH_AI_OPENAI_API_KEY_FILE' queuebash.sh || fail 'OpenAI key lookup docs missing from queue ask help'

test -x bin/queue-ai-ask-openai || fail 'OpenAI helper missing or not executable'
test -x providers.d/ask/openai.sh || fail 'OpenAI ask provider descriptor missing or not executable'
test -f docs/ASK_OPENAI_PROVIDER.md || fail 'OpenAI ask provider doc missing'
test -f policies.d/ask/openai.env.example || fail 'OpenAI ask policy example missing'
test -f examples/providers/ai/openai.env.example || fail 'OpenAI provider example missing'

grep -q 'Responses API' docs/ASK_OPENAI_PROVIDER.md || fail 'OpenAI provider doc missing Responses API note'
grep -q 'QUEUEBASH_AI_OPENAI_API_KEY_FILE' bin/queue-ai-ask-openai || fail 'OpenAI helper key file lookup missing'
grep -q 'OPENAI_API_KEY' bin/queue-ai-ask-openai || fail 'standard OpenAI key lookup missing'
grep -q 'redact_secret_values' bin/queue-ai-ask-openai || fail 'OpenAI error redaction missing'
grep -q 'queuebash.ai_advisory.response.v1' bin/queue-ai-ask-openai || fail 'OpenAI normalized response schema missing'
grep -q 'Provider output is data, never shell' docs/AI_ADVISORY_PROVIDER.md || fail 'OpenAI provider output safety wording missing'
grep -Eq '^openai[[:space:]]+yes[[:space:]]+yes[[:space:]]+yes' policies.d/ask/providers.tsv.example || fail 'OpenAI provider policy row missing'

! grep -R 'sk-[A-Za-z0-9]' docs/ASK_OPENAI_PROVIDER.md policies.d/ask/openai.env.example examples/providers/ai/openai.env.example >/dev/null || fail 'looks like concrete OpenAI key in docs/examples/helper'
! grep -R 'eval .*openai\|source .*openai\|bash -c .*openai' queuebash.sh docs/ASK_OPENAI_PROVIDER.md providers.d/ask/openai.sh >/dev/null || fail 'unsafe OpenAI provider shell execution pattern found'

echo PASS
