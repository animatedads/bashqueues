#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(4[1-9]|[5-9][0-9])"' queuebash.sh || fail 'version not current enough for ask provider compatibility'
grep -q '0.18.40 - BOB10 cloud provisioning lifecycle + ask provider merged' CHANGELOG.md || fail 'changelog missing ask provider merge entry'
grep -q '_queue_ai_provider_discovery_command' queuebash.sh || fail 'provider discovery command missing'
grep -q 'queue ask providers \[--json\]' queuebash.sh || fail 'ask providers help missing'
grep -q 'queuebash.ask_provider.discovery.v1' queuebash.sh || fail 'discovery JSON schema missing in queuebash'
grep -q 'queuebash.ask_provider.fixture_test.v1' queuebash.sh || fail 'fixture test schema missing in queuebash'
grep -q 'queuebash.ask_provider.response.v1' queuebash.sh || fail 'fixture response schema missing in queuebash execution path'
grep -q 'fixture_provider_failed_or_timed_out' queuebash.sh || fail 'fixture provider bounded failure path missing'

test -x providers.d/ask/contract.sh || fail 'ask contract helper missing or not executable'
test -x providers.d/ask/fixture.sh || fail 'ask fixture helper missing or not executable'
test -f policies.d/ask/providers.tsv.example || fail 'ask providers policy example missing'
test -f policies.d/ask/context-policy.tsv.example || fail 'ask context policy example missing'
test -f policies.d/ask/redaction.env.example || fail 'ask redaction policy example missing'
test -f docs/ASK_PROVIDER_CONTRACT.md || fail 'ask provider contract doc missing'
test -f docs/ASK_SECURITY_MODEL.md || fail 'ask security doc missing'
test -f docs/ASK_CONTEXT_BUNDLES.md || fail 'ask context bundles doc missing'
test -f docs/ASK_AUDIT_LOGGING.md || fail 'ask audit doc missing'

grep -q 'provider output is data and is never evaluated as shell' docs/ASK_PROVIDER_CONTRACT.md || fail 'provider output data rule missing'
grep -q 'QUEUEBASH_AI_LIVE_ENABLED' docs/ASK_PROVIDER_CONTRACT.md || fail 'live gate missing in docs'
grep -q 'fixture-first' docs/ASK_SECURITY_MODEL.md || fail 'fixture-first security rule missing'
! grep -R 'API_KEY=.*[A-Za-z0-9]' policies.d/ask docs/ASK_* providers.d/ask || fail 'possible API key in ask contract files'

echo PASS
