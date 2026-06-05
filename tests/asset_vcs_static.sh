#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "[FAIL] $*" >&2; exit 1; }

bash -n assets.d/vcs.sh || fail "bash -n failed for assets.d/vcs.sh"
source assets.d/vcs.sh

for check in repo_exists clean_tree branch identity revision tool_available; do
    queue_asset_facilities | grep -q "vcs:$check" || fail "facility missing: vcs:$check"
    declare -F "queue_asset_check_vcs_${check}" >/dev/null || fail "function missing: queue_asset_check_vcs_${check}"
    queue_asset_hints | grep -q "vcs:$check" || fail "hint missing: vcs:$check"
done

for t in git svn cvs hg p4; do
    cmd="$(_vcs_type_command "$t")"
    [[ -n "$cmd" ]] || fail "type command missing for $t"
done

(
    PATH=/nonexistent
    result="$(queue_asset_check_vcs_tool_available _tok svn type=svn 2>&1 || true)"
    case "$result" in *tool_missing=svn*) ;; *) fail "vcs:tool_available must emit tool_missing for absent svn" ;; esac
)

repo="$(mktemp -d)"
trap 'rm -rf "$repo"' EXIT
mkdir -p "$repo/CVS"
echo '/cvs/root' > "$repo/CVS/Root"
queue_asset_check_vcs_repo_exists _tok "$repo" type=auto | grep -q 'asset_check_ok' || fail "auto should detect CVS metadata"

printf 'TREL_1_0\n' > "$repo/CVS/Tag"
queue_asset_check_vcs_branch _tok "$repo" type=cvs require_tag=REL_1_0 | grep -q 'asset_check_ok' || fail "CVS sticky tag branch check failed"

bash -n bin/queue-vcs-detect || fail "bash -n failed for bin/queue-vcs-detect"
bash bin/queue-vcs-detect --json "$repo" | grep -q '"type":"cvs"' || fail "queue-vcs-detect did not report cvs"

bash -n bin/queue-vcs-probe || fail "bash -n failed for bin/queue-vcs-probe"
probe="$(bash bin/queue-vcs-probe --json "$repo")"
grep -q '"schema":"queuebash.vcs.probe.v1"' <<< "$probe" || fail "queue-vcs-probe schema missing"
grep -q '"type":"cvs"' <<< "$probe" || fail "queue-vcs-probe did not report cvs"
grep -q '"identity":"REL_1_0"' <<< "$probe" || fail "queue-vcs-probe did not report CVS sticky tag identity"
queue_asset_check_vcs_identity _tok "$repo" type=cvs require_identity=REL_1_0 | grep -q 'asset_check_ok' || fail "vcs identity check failed for CVS sticky tag"
queue_asset_check_vcs_revision _tok "$repo" type=cvs require_revision=/cvs/root | grep -q 'asset_check_ok' || fail "vcs revision check failed for CVS root metadata"

echo "[PASS] vcs asset facilities, hints, detection, and tool_missing paths are wired"
