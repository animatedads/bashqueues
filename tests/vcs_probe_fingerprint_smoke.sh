#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd -P)"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/CVS"
printf '/legacy/cvsroot\n' > "$work/CVS/Root"
printf 'TREL_3_1\n' > "$work/CVS/Tag"

json="$($repo_root/bin/queue-vcs-probe --json --type cvs --timeout 1 "$work")" || fail "probe failed"
fingerprint="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("fingerprint", ""))' <<<"$json")"
case "$fingerprint" in
  ????????????????????????????????????????????????????????????????) ;;
  *) fail "unexpected fingerprint: $fingerprint" ;;
esac

# shellcheck source=/dev/null
source "$repo_root/assets.d/vcs.sh"
out="$(queue_asset_check_vcs_fingerprint token-vcs-fingerprint "$work" type=cvs require_fingerprint="$fingerprint" timeout=1)" || fail "fingerprint asset failed: $out"
case "$out" in
  *'asset_check_ok: token-vcs-fingerprint'*) ;;
  *) fail "unexpected fingerprint asset output: $out" ;;
esac

echo "[PASS] VCS probe fingerprint smoke contract works"
