#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
grep -q 'QUEUEBASH_VERSION="0.17.51"' queuebash.sh || fail "version not bumped"
grep -q '_queue_cron_set_class_command' queuebash.sh || fail "cron class command missing"
grep -q 'queue cron class \[USER\] ENTRY CLASS' queuebash.sh || fail "cron class usage missing"
grep -q '#class' docs/CRON_BRIDGE.md || fail "cron docs missing #class directive"
grep -q '_parse_comment_directive' bin/bashqueues-cron-ticker.py || fail "ticker comment directive parser missing"
grep -q 'class|set-class' queuebash.sh || fail "cron class case missing"
echo "[PASS] cron class directive helpers are wired"
