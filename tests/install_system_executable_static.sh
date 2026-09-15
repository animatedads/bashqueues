#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "[FAIL] $*" >&2; exit 1; }

[[ -f install-system.sh ]] || fail "install-system.sh missing"
[[ -x install-system.sh ]] || fail "install-system.sh is not executable"
bash -n install-system.sh || fail "install-system.sh syntax check failed"

out="$(./install-system.sh --dryrun 2>&1)" || fail "install-system.sh --dryrun failed"
printf '%s\n' "$out" | grep -q '/etc/queuebash/policies.d' || fail "installer dryrun does not report canonical policy root /etc/queuebash/policies.d"
if printf '%s\n' "$out" | grep -q '/etc/bashqueues/policies.d'; then
    fail "installer dryrun reports legacy /etc/bashqueues/policies.d as active policy root"
fi

echo "[PASS] install-system executable and policy namespace guard passed"
