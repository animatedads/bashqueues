#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.18.22"' queuebash.sh || fail 'version not bumped to 0.18.22'
grep -q '0.18.2 - Ollama advisory provider failure handling' CHANGELOG.md || fail 'changelog entry missing'
test -x bin/queue-ai-ask-ollama || fail 'ollama helper missing'
test -f examples/providers/ai/ollama.env.example || fail 'ollama example missing'

grep -q -- '--live' queuebash.sh || fail 'queue ask --live missing'
grep -q 'QUEUEBASH_AI_LIVE_ENABLED' queuebash.sh || fail 'live provider policy gate missing'
grep -q 'QUEUEBASH_AI_OLLAMA_HELPER' queuebash.sh || fail 'helper override missing'
grep -q 'QUEUEBASH_AI_OLLAMA_URL' bin/queue-ai-ask-ollama || fail 'ollama url config missing'
grep -q 'QUEUEBASH_AI_CONTEXT_TOTAL_BYTES' bin/queue-ai-ask-ollama || fail 'context bound missing'
grep -q 'Tests are deliberately treated as high-authority implementation evidence' bin/queue-ai-ask-ollama || fail 'tests priority comment missing'
grep -q 'never executes' bin/queue-ai-ask-ollama || fail 'advisory-only helper rule missing'

grep -q 'ollama_timeout_after_' bin/queue-ai-ask-ollama || fail 'timeout reason handling missing'
grep -q 'ollama_provider_error' bin/queue-ai-ask-ollama || fail 'provider error stderr handling missing'
grep -q 'TimeoutError' bin/queue-ai-ask-ollama || fail 'TimeoutError handling missing'
grep -q 'QUEUEBASH_AI_OLLAMA_TIMEOUT=180' examples/providers/ai/ollama.env.example || fail 'example timeout not updated'
grep -q 'provider failed:' queuebash.sh || fail 'queue ask provider reason display missing'
grep -q 'export QUEUEBASH_AI_LIVE_ENABLED=1' queuebash.sh || fail 'live enable hint missing'

! grep -R '/etc/bashqueues' docs/AI_ADVISORY_PROVIDER.md docs/AI_AUDIT_LOGGING.md examples/providers/ai/ollama.env.example bin/queue-ai-ask-ollama || fail 'legacy /etc/bashqueues namespace drift'
! grep -R 'eval .*answer\|eval .*provider\|shell=True\|subprocess.run' bin/queue-ai-ask-ollama queuebash.sh docs/AI_ADVISORY_PROVIDER.md || fail 'AI provider execution pattern found'

echo PASS
