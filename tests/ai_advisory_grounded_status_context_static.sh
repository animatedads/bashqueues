#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.18.6"' queuebash.sh || fail 'version not bumped to 0.18.6'
grep -q '0.18.6 - AI advisory grounded status context' CHANGELOG.md || fail 'changelog entry missing'

grep -q '_queue_ai_build_dynamic_context' queuebash.sh || fail 'dynamic context builder missing'
grep -q '_queue_ai_detect_job_ids' queuebash.sh || fail 'job id detector missing'
grep -q '_queue_ai_command_inventory_text' queuebash.sh || fail 'command inventory collector missing'
grep -q '_queue_ai_asset_inventory_text' queuebash.sh || fail 'asset inventory collector missing'
grep -q '_queue_ai_job_status_text' queuebash.sh || fail 'job status collector missing'

grep -q 'QUEUEBASH_AI_ALLOW_QUEUE_STATUS' queuebash.sh || fail 'queue status gate missing'
grep -q 'QUEUEBASH_AI_ALLOW_JOB_STATUS' queuebash.sh || fail 'job status gate missing'
grep -q 'QUEUEBASH_AI_ALLOW_JOB_METADATA' queuebash.sh || fail 'job metadata gate missing'
grep -q 'QUEUEBASH_AI_ALLOW_JOB_TAIL' queuebash.sh || fail 'job tail gate missing'

grep -q 'dynamic_context_text' queuebash.sh || fail 'request dynamic context missing'
grep -q 'job_ids_detected' queuebash.sh || fail 'job id request/audit field missing'
grep -q 'job_context_collected' queuebash.sh || fail 'job context audit field missing'
grep -q 'tail_included' queuebash.sh || fail 'tail audit field missing'
grep -q 'command_payload_redacted: true' queuebash.sh || fail 'payload redaction marker missing'
grep -q 'stdout_stderr_redacted: true' queuebash.sh || fail 'stdout/stderr redaction marker missing'

grep -q 'dynamic_context_text = str(req.get("dynamic_context_text"' bin/queue-ai-ask-ollama || fail 'Ollama dynamic context ingestion missing'
grep -q 'dynamic_context_text = str(req.get("dynamic_context_text"' bin/queue-ai-ask-gemini || fail 'Gemini dynamic context ingestion missing'
grep -q 'Do not invent queue commands' bin/queue-ai-ask-ollama || fail 'Ollama prompt command grounding missing'
grep -q 'Do not invent queue commands' bin/queue-ai-ask-gemini || fail 'Gemini prompt command grounding missing'

grep -q 'Grounded status context (0.18.6)' docs/AI_ADVISORY_PROVIDER.md || fail 'provider docs missing grounded context section'
grep -q 'Grounded status context audit fields (0.18.6)' docs/AI_AUDIT_LOGGING.md || fail 'audit docs missing grounded context section'

! test -e assets.d/net_usage.sh || fail 'assets.d/net_usage.sh must remain absent'
test -e caps.d/net_usage.sh || fail 'caps.d/net_usage.sh should remain present'

echo PASS
