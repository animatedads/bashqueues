#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "[FAIL] $*" >&2; exit 1; }

grep -q 'def queue_job_reference_choices' queuemgr_panel.py || fail "missing queue job reference choice helper"
grep -q '"<clear>"' queuemgr_panel.py || fail "queue reference chooser lacks clear option"
grep -q 'def edit_job_reference_field' queuemgr_panel.py || fail "missing Task Creator queue-reference editor"
grep -q 'raw == "\*"' queuemgr_panel.py || fail "literal star is not intercepted for queue-reference fields"
grep -q 'edit_job_reference_field("After-success dependencies"' queuemgr_panel.py || fail "dependencies field does not use queue-reference chooser"
grep -q 'edit_job_reference_field("Inherit env from"' queuemgr_panel.py || fail "inherit-env field does not use queue-reference chooser"
grep -q 'must not be stored as a literal wildcard' queuemgr_panel.py || fail "wildcard safety note missing"

grep -q 'queue-reference fields' docs/QUEUEMGR.md || fail "QueueManager docs missing queue-reference field documentation"
grep -q 'inherit env from.*existing queue job names' README.md || fail "README missing inherit-env chooser documentation"

if find assets.d -maxdepth 1 -name 'net_usage.sh' | grep -q .; then
  fail "assets.d/net_usage.sh must not be restored"
fi

echo "[PASS] Task Creator dependency/inherit fields use queue job chooser with clear option"
