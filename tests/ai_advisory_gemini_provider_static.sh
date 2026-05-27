#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }
cd "$(dirname "$0")/.."

grep -q 'QUEUEBASH_VERSION="0.18.6"' queuebash.sh || fail 'version not bumped to 0.18.6'
grep -q '0.18.4 - Gemini model discovery and default refresh' CHANGELOG.md || fail 'changelog entry missing'
[[ -x bin/queue-ai-ask-gemini ]] || fail 'Gemini helper missing or not executable'

grep -q 'queue-ai-ask-gemini' queuebash.sh || fail 'queue ask does not resolve Gemini helper'
grep -q 'live_gemini_provider' queuebash.sh || fail 'Gemini live success reason missing'
grep -q 'QUEUEBASH_AI_GEMINI_API_KEY_FILE' bin/queue-ai-ask-gemini || fail 'Gemini key file lookup missing'
grep -q 'GEMINI_API_KEY' bin/queue-ai-ask-gemini || fail 'Gemini CLI environment key lookup missing'
grep -q 'GOOGLE_API_KEY' bin/queue-ai-ask-gemini || fail 'standard Google API key lookup missing'
grep -q 'redact_secret_values' bin/queue-ai-ask-gemini || fail 'Gemini error redaction missing'
grep -q 'gemini-2.5-flash' bin/queue-ai-ask-gemini || fail 'Gemini default model not refreshed'
grep -q -- '--list-models' bin/queue-ai-ask-gemini || fail 'Gemini model discovery flag missing'
grep -q 'gemini-2.5-flash' queuebash.sh || fail 'queue ask Gemini default model not refreshed'
grep -q 'queue-ai-ask-gemini --list-models' docs/AI_ADVISORY_PROVIDER.md || fail 'Gemini model discovery docs missing'
grep -q 'advisory_only' bin/queue-ai-ask-gemini || fail 'advisory only contract missing'
grep -q 'Provider output is data, never shell' README.md || fail 'README safety wording missing'
grep -q 'Gemini advisory provider' docs/AI_ADVISORY_PROVIDER.md || fail 'Gemini docs missing'
grep -q 'live_gemini_provider' docs/AI_AUDIT_LOGGING.md || fail 'Gemini audit docs missing'
[[ -f examples/providers/ai/gemini.env.example ]] || fail 'Gemini provider example missing'

# Prevent namespace drift and accidental secret examples.
! grep -R '/etc/bashqueues' docs/AI_ADVISORY_PROVIDER.md examples/providers/ai/gemini.env.example >/dev/null || fail 'legacy /etc/bashqueues namespace found'
! grep -R 'AIza[0-9A-Za-z_-]' examples/providers/ai/gemini.env.example docs/AI_ADVISORY_PROVIDER.md >/dev/null || fail 'looks like real Google API key in docs/examples'

echo PASS
