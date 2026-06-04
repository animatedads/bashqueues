#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

fail(){ echo "FAIL: $*" >&2; exit 1; }

[[ -x bin/queue-ai-broker ]] || fail "bin/queue-ai-broker executable missing"
grep -q '_queue_ai_broker_command' queuebash.sh || fail "queuebash.sh missing broker command helper"
grep -q 'ai|ai-broker)' queuebash.sh || fail "queue dispatcher missing ai command"
grep -q 'queue ai providers' queuebash.sh || fail "queue help missing queue ai surface"
grep -q 'queuebash.ai_broker.response.v1' bin/queue-ai-broker || fail "broker response schema missing"
grep -q 'provider-registry.example.json' bin/queue-ai-broker || fail "broker registry fallback missing"
grep -q 'health-cache.example.json' bin/queue-ai-broker || fail "broker health cache fallback missing"
grep -q 'queuebash.ai_broker.health_update.v1' bin/queue-ai-broker || fail "broker health update schema missing"
grep -q 'disabled_by_policy' docs/QUEUE_AI_BROKER_HEALTH_CACHE.md || fail "health cache docs missing disabled state evidence"
[[ -f policies.d/ai-broker/health-cache.example.json ]] || fail "health cache policy example missing"
[[ -f tests/fixtures/ai_broker/health_cache.example.json ]] || fail "health cache fixture missing"
grep -q 'brokered_live_provider_call' bin/queue-ai-broker || fail "brokered live provider call path missing"
grep -q 'QUEUEBASH_AI_LIVE_ENABLED' bin/queue-ai-broker || fail "broker live gate missing"
[[ -f docs/QUEUE_AI_BROKER_IMPLEMENTATION.md ]] || fail "implementation doc missing"
[[ -f docs/QUEUE_AI_BROKER_POLICY_LINKS.md ]] || fail "policy links doc missing"
grep -q 'policy_refs' policies.d/ai-broker/provider-registry.example.json || fail "provider registry missing policy refs"
grep -q 'AI_REGULATORY_POLICY_REFS' policies.d/ai-profiles/balanced.env.example || fail "balanced profile missing regulatory policy refs"
grep -q 'policy_links' bin/queue-ai-broker || fail "broker policy_links output missing"

bash -n queuebash.sh
python3 -m py_compile bin/queue-ai-broker

grep -q 'queuebash.ai_broker.health_feedback.v1' bin/queue-ai-broker || fail "broker health feedback schema missing"
grep -q 'queuebash.ai_broker.health_clear.v1' bin/queue-ai-broker || fail "broker health clear schema missing"
grep -q 'queuebash.ai_broker.health_prune.v1' bin/queue-ai-broker || fail "broker health prune schema missing"
grep -q 'queuebash.ai_broker.health_events.v1' bin/queue-ai-broker || fail "broker health events schema missing"
grep -q 'queuebash.ai_broker.health_events_prune.v1' bin/queue-ai-broker || fail "broker health events prune schema missing"
grep -q 'prune_health_events' bin/queue-ai-broker || fail "broker health event prune helper missing"
grep -q 'health-events.jsonl' bin/queue-ai-broker || fail "broker health event journal path missing"
grep -q 'classify_provider_failure' bin/queue-ai-broker || fail "broker failure classification missing"
grep -q 'AI_BROKER_AUTO_HEALTH_FEEDBACK' docs/QUEUE_AI_BROKER_HEALTH_CACHE.md || fail "health feedback docs missing toggle"
grep -q -- '--prune-expired' docs/QUEUE_AI_BROKER_HEALTH_CACHE.md || fail "health cache docs missing prune operation"
grep -q -- '--events' docs/QUEUE_AI_BROKER_HEALTH_CACHE.md || fail "health cache docs missing events operation"
grep -q 'queuebash.ai_broker.health_events.v1' docs/QUEUE_AI_BROKER_HEALTH_CACHE.md || fail "health events docs schema missing"
grep -q -- '--summary' docs/QUEUE_AI_BROKER_HEALTH_CACHE.md || fail "health events docs missing summary filter"
grep -q -- '--prune-events' docs/QUEUE_AI_BROKER_HEALTH_CACHE.md || fail "health events docs missing prune-events"
grep -q 'summarise_health_events' bin/queue-ai-broker || fail "health events summary helper missing"
echo "PASS queue_ai_broker_runtime_static"
