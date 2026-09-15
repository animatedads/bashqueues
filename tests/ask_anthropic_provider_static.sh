#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(49|[5-9][0-9])"' queuebash.sh || fail 'version not compatible with 0.18.49+'
grep -q '0.18.44 - BOB11 ask Anthropic live-provider pack' CHANGELOG.md || fail 'changelog missing Anthropic provider entry'
grep -q 'queue-ai-ask-anthropic' queuebash.sh || fail 'queue ask does not resolve Anthropic helper'
grep -q 'live_anthropic_provider' queuebash.sh || fail 'Anthropic live audit reason missing'
grep -q 'openai|anthropic) echo true\|openai|anthropic' queuebash.sh || fail 'Anthropic live/provider support missing'
grep -q 'QUEUEBASH_AI_ANTHROPIC_API_KEY_FILE' queuebash.sh || fail 'Anthropic key lookup docs missing from queue ask help'

test -x bin/queue-ai-ask-anthropic || fail 'Anthropic helper missing or not executable'
test -x providers.d/ask/anthropic.sh || fail 'Anthropic ask provider descriptor missing or not executable'
test -f docs/ASK_ANTHROPIC_PROVIDER.md || fail 'Anthropic ask provider doc missing'
test -f policies.d/ask/anthropic.env.example || fail 'Anthropic ask policy example missing'
test -f examples/providers/ai/anthropic.env.example || fail 'Anthropic provider example missing'

grep -q 'Messages API' docs/ASK_ANTHROPIC_PROVIDER.md || fail 'Anthropic provider doc missing Messages API note'
grep -q 'QUEUEBASH_AI_ANTHROPIC_API_KEY_FILE' bin/queue-ai-ask-anthropic || fail 'Anthropic helper key file lookup missing'
grep -q 'ANTHROPIC_API_KEY' bin/queue-ai-ask-anthropic || fail 'standard Anthropic key lookup missing'
grep -q 'redact_secret_values' bin/queue-ai-ask-anthropic || fail 'Anthropic error redaction missing'
grep -q 'queuebash.ai_advisory.response.v1' bin/queue-ai-ask-anthropic || fail 'Anthropic normalized response schema missing'
grep -q 'x-api-key' bin/queue-ai-ask-anthropic || fail 'Anthropic x-api-key header missing'
grep -q 'anthropic-version' bin/queue-ai-ask-anthropic || fail 'Anthropic version header missing'
grep -q 'Provider output is data, never shell' docs/AI_ADVISORY_PROVIDER.md || fail 'Anthropic provider output safety wording missing'
grep -Eq '^anthropic[[:space:]]+yes[[:space:]]+yes[[:space:]]+yes' policies.d/ask/providers.tsv.example || fail 'Anthropic provider policy row missing'

! grep -R 'sk-ant-[A-Za-z0-9]' docs/ASK_ANTHROPIC_PROVIDER.md policies.d/ask/anthropic.env.example examples/providers/ai/anthropic.env.example >/dev/null || fail 'looks like concrete Anthropic key in docs/examples/helper'
! grep -R 'eval .*anthropic\|source .*anthropic\|bash -c .*anthropic' queuebash.sh docs/ASK_ANTHROPIC_PROVIDER.md providers.d/ask/anthropic.sh >/dev/null || fail 'unsafe Anthropic provider shell execution pattern found'

echo PASS
