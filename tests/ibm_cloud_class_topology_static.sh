#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL $*" >&2; exit 1; }

for cls in CLOUD_IBM_GDPR CLOUD_IBM_FINREG CLOUD_IBM_LEGAL_READONLY CLOUD_IBM_LEGAL_COMPLIANCE; do
  f="classes/${cls}.env"
  [[ -f "$f" ]] || fail "missing $f"
  bash -n "$f" || fail "syntax: $f"
  grep -q 'QUEUEBASH_CLOUD_PROVIDER=ibm' "$f" || fail "$cls missing IBM provider marker"
  grep -q 'queue_class_shared_asset ibm_identity auth_active' "$f" || fail "$cls missing IBM auth gate"
  grep -q 'queue_class_shared_asset ibm_identity target_region_allowed' "$f" || fail "$cls missing IBM region gate"
  grep -q 'CLASS_DEFAULT_RUNTIME_CAPS=.*no-spawn-shell' "$f" || fail "$cls missing no-spawn-shell cap"
  grep -q 'CLASS_DEFAULT_SANDBOX_LEVEL' "$f" || fail "$cls missing sandbox default"
done

grep -q 'queue_class_shared_asset legal retention_respected' classes/CLOUD_IBM_FINREG.env || fail 'FINREG missing legal retention gate'
grep -q 'queue_class_shared_asset integrity manifest_verified' classes/CLOUD_IBM_FINREG.env || fail 'FINREG missing integrity gate'
grep -q 'QUEUEBASH_LEGAL_EFFECT=readonly' classes/CLOUD_IBM_LEGAL_READONLY.env || fail 'LEGAL_READONLY missing readonly effect'
grep -q 'QUEUEBASH_LEGAL_EFFECT=destructive' classes/CLOUD_IBM_LEGAL_COMPLIANCE.env || fail 'LEGAL_COMPLIANCE missing destructive effect marker'

! grep -R '/etc/bashqueues' classes/CLOUD_IBM_*.env docs/IBM_CLOUD_GOVERNANCE.md policies.d/sovereign/ibm.env.example >/tmp/ibm_old_paths.out || fail "IBM files contain old /etc/bashqueues paths: $(cat /tmp/ibm_old_paths.out)"

echo "PASS tests/ibm_cloud_class_topology_static.sh"
