#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "queue_ai_job_usage_static: $*" >&2; exit 1; }

[[ -f docs/QUEUE_AI_JOB_USAGE.md ]] || fail "missing job usage doc"
grep -q -- '--uses-ai' docs/QUEUE_AI_JOB_USAGE.md || fail "uses-ai submit flag contract missing"
grep -q 'CLASS_USES_AI=1' docs/QUEUE_AI_JOB_USAGE.md || fail "class AI metadata missing"
grep -q 'QUEUEBASH_JOB_USES_AI=1' docs/QUEUE_AI_JOB_USAGE.md || fail "job env contract missing"
grep -q 'queuebash.ai.provider_pinned.v1' docs/QUEUE_AI_JOB_USAGE.md || fail "provider pin audit schema missing"
grep -q 'Default policy should be deny' docs/QUEUE_AI_JOB_USAGE.md || fail "default deny statement missing"
grep -q 'AI_ALIAS_json_default_PROFILE="json_strict"' policies.d/ai-broker/model-aliases.env.example || fail "json alias missing"

echo "PASS queue_ai_job_usage_static"
