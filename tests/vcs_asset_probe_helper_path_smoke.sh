#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd -P)"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

work="$(mktemp -d)"
other="$(mktemp -d)"
trap 'rm -rf "$work" "$other"' EXIT
mkdir -p "$work/CVS"
printf '/legacy/cvsroot\n' > "$work/CVS/Root"
printf 'TREL_3_1\n' > "$work/CVS/Tag"

# Source from the project tree, then change cwd away from the tree to match
# installed/runtime asset evaluation. The VCS asset must still find the
# queue-vcs-probe helper via the asset file location, not via ./bin.
# shellcheck source=/dev/null
source "$repo_root/assets.d/vcs.sh"
cd "$other"
out="$(queue_asset_check_vcs_identity token-vcs-identity "$work" type=cvs require_identity=REL_3_1 timeout=1)" || fail "identity asset failed away from repo cwd: $out"
case "$out" in
  *'asset_check_ok: token-vcs-identity'*) ;;
  *) fail "unexpected identity output: $out" ;;
esac

out="$(queue_asset_check_vcs_revision token-vcs-revision "$work" type=cvs require_revision=/legacy/cvsroot timeout=1)" || fail "revision asset failed away from repo cwd: $out"
case "$out" in
  *'asset_check_ok: token-vcs-revision'*) ;;
  *) fail "unexpected revision output: $out" ;;
esac

echo "[PASS] VCS probe-backed assets resolve helper independent of cwd"
