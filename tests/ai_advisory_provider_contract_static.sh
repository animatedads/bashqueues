#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(4[3-9]|[5-9][0-9]|42|43|44|45|46)"' queuebash.sh || fail 'version not current enough for AI advisory compatibility'
grep -q '0.18.2 - Ollama advisory provider failure handling' CHANGELOG.md || fail 'changelog entry missing'
grep -q '_queue_ai_ask_command' queuebash.sh || fail 'queue ask function missing'
grep -q 'ask|ai-ask|advisory|advise)' queuebash.sh || fail 'queue ask dispatch missing'
grep -q 'queue ask \[--provider NAME\]' queuebash.sh || fail 'queue help missing ask usage'

test -f docs/AI_ADVISORY_PROVIDER.md || fail 'AI advisory docs missing'
test -f docs/AI_AUDIT_LOGGING.md || fail 'AI audit docs missing'
test -f examples/providers/ai/watson.env.example || fail 'Watson example missing'
test -f examples/providers/ai/ollama.env.example || fail 'Ollama example missing'
test -x bin/queue-ai-ask-ollama || fail 'Ollama helper missing or not executable'

grep -q 'queuebash.ai_advisory.request.v1' docs/AI_ADVISORY_PROVIDER.md || fail 'request schema missing'
grep -q 'queuebash.ai_advisory.audit.v1' docs/AI_AUDIT_LOGGING.md || fail 'audit schema missing'
grep -q 'advisory only' docs/AI_ADVISORY_PROVIDER.md || fail 'advisory-only rule missing'
grep -q 'never evaluated as shell' docs/AI_ADVISORY_PROVIDER.md || fail 'provider-output-as-data rule missing'
grep -q 'IBM Watson' docs/AI_ADVISORY_PROVIDER.md || fail 'Watson provider example missing'
grep -q 'Ollama' docs/AI_ADVISORY_PROVIDER.md || fail 'Ollama provider docs missing'
grep -q 'QUEUEBASH_AI_LIVE_ENABLED' docs/AI_ADVISORY_PROVIDER.md || fail 'live provider policy gate missing'
grep -q 'tests as the highest-authority implementation evidence' bin/queue-ai-ask-ollama || fail 'tests priority rule missing from helper'

! grep -R '/etc/bashqueues' docs/AI_ADVISORY_PROVIDER.md docs/AI_AUDIT_LOGGING.md examples/providers/ai/watson.env.example examples/providers/ai/ollama.env.example || fail 'legacy /etc/bashqueues namespace drift'
! grep -R 'eval .*provider\|bash -c .*provider' docs/AI_ADVISORY_PROVIDER.md queuebash.sh examples/providers/ai/watson.env.example || fail 'provider shell execution pattern found'

echo PASS
