#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

cd "$ROOT"
grep -q 'QUEUEBASH_VERSION="0.18.6"' queuebash.sh || fail "version not bumped to 0.18.6"
grep -q '_queue_clearance_archive_job_file' queuebash.sh || fail "clearance archive helper missing"
grep -q '_queue_cleared_candidate_files_for_state' queuebash.sh || fail "cleared archive scanner missing"
grep -q 'root/clearance/\$state' queuebash.sh || fail "queue audit cleared must scan clearance archive state dirs"
grep -q 'Cleared \$what jobs (archived \$archived_count record(s))' queuebash.sh || fail "clear command should archive records, not silently delete them"
! grep -q 'rm -f "\$root/\$what"/\*.job' queuebash.sh || fail "queue clear <state> must not rm job records"

echo "[PASS] clear archive/audit static checks pass"
