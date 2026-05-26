#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
fail(){ echo "[FAIL] $*" >&2; exit 1; }
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
# shellcheck source=/dev/null
source ./queuebash.sh
out="$(queue system-daemon --once --dryrun --min-workers 1 2>&1 || true)"
grep -q 'DRYRUN: would run system-daemon' <<<"$out" || fail "dryrun header missing"
echo "[PASS] system daemon dryrun works"
