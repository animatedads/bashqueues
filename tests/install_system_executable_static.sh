#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

[[ -f install-system.sh ]] || fail 'install-system.sh missing'
[[ -x install-system.sh ]] || fail 'install-system.sh must be executable so ./install-system.sh --dryrun works for operators'
bash -n install-system.sh || fail 'install-system.sh syntax failed'

out="$(./install-system.sh --dryrun 2>&1 || true)"
printf '%s\n' "$out" | grep -q 'bashqueues system install plan' || fail 'dry-run did not print install plan header'
printf '%s\n' "$out" | grep -q 'policy dir:    /etc/queuebash/policies.d' || fail 'dry-run did not report canonical policy dir'
! printf '%s\n' "$out" | grep -q 'policy dir:    /etc/bashqueues/policies.d' || fail 'dry-run reported legacy policy dir as active'

echo '[PASS] install-system executable dry-run contract'
