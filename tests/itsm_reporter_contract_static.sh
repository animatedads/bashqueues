#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { echo "FAIL: $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.18.22"' queuebash.sh || fail "version not bumped to 0.18.22"
grep -q '_queue_itsm_emit_contract_event' queuebash.sh || fail "missing ITSM contract emitter"
grep -q '_queue_itsm_command' queuebash.sh || fail "missing queue itsm command handler"
grep -q 'queuebash.reporter.itsm_event.v1' queuebash.sh || fail "missing ITSM event schema"
grep -q 'ticket_requested":false' queuebash.sh || fail "ITSM events must not claim ticket requested by default"
grep -q 'ticket_created":false' queuebash.sh || fail "ITSM events must not claim ticket creation"
grep -q 'itsm|ticketing)' queuebash.sh || fail "missing queue itsm command case"
grep -q 'queue itsm status' queuebash.sh || fail "help text missing queue itsm"

grep -q 'queuebash.reporter.itsm_event.v1' docs/ITSM_REPORTER_CONTRACT.md || fail "contract docs missing schema"
grep -q 'QUEUEBASH_ITSM_ENABLED' examples/reporters/itsm.env.example || fail "example env missing enable flag"
grep -q 'contract-only' docs/ITSM_REPORTER_CONTRACT.md || fail "docs must state contract-only scope"

echo "PASS tests/itsm_reporter_contract_static.sh"
