#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "queue_ai_broker_contract_static: $*" >&2; exit 1; }

[[ -f docs/QUEUE_AI_BROKER.md ]] || fail "missing docs/QUEUE_AI_BROKER.md"
[[ -f docs/QUEUE_AI_JOB_USAGE.md ]] || fail "missing docs/QUEUE_AI_JOB_USAGE.md"
[[ -f docs/QUEUE_AI_PROVIDER_SELECTION.md ]] || fail "missing docs/QUEUE_AI_PROVIDER_SELECTION.md"

grep -q 'queue ai broker' docs/QUEUE_AI_BROKER.md || fail "broker doc missing title/content"
grep -q 'queuebash.ai.broker.request.v1' docs/QUEUE_AI_BROKER.md || fail "request schema not documented"
grep -q 'queuebash.ai.broker.response.v1' docs/QUEUE_AI_BROKER.md || fail "response schema not documented"
grep -q 'queuebash.ai.provider_registry.v1' policies.d/ai-broker/provider-registry.example.json || fail "provider registry schema missing"
grep -q 'AI_PROFILE_NAME="balanced"' policies.d/ai-profiles/balanced.env.example || fail "balanced profile missing"
grep -q 'AI_ALLOW_CLOUD=0' policies.d/ai-profiles/private_only.env.example || fail "private_only should deny cloud"
grep -q 'AI_REQUIRE_JSON_MODE=1' policies.d/ai-profiles/json_strict.env.example || fail "json_strict should require JSON"
grep -q 'queuebash.ai.request.v1' docs/QUEUE_AI_BROKER.md || fail "audit event not documented"
grep -q 'no runtime broker implementation' docs/QUEUE_AI_BROKER.md || fail "non-goal boundary missing"

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(7[8-9]|[8-9][0-9])"' queuebash.sh || fail "version not bumped to merged 0.18.78+ line"

echo "PASS queue_ai_broker_contract_static"
