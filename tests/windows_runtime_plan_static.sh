#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT/docs/WINDOWS_RUNTIME_PLAN.md"
POLICY="$ROOT/policies.d/platform/windows-runtime-parity.json"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

[[ -f "$DOC" ]] || fail "missing $DOC"
[[ -f "$POLICY" ]] || fail "missing $POLICY"

for token in \
  "WSL2" "Git Bash" "MSYS2" "Cygwin" "PowerShell" "Windows service" \
  "Task Scheduler" "WinRM" "OpenSSH" "NTFS ACL" "CRLF" "case-insensitive" \
  "flock" "process-tree" "signals" "path adapter" "identity adapter" \
  "Windows native operation is complete"; do
  grep -Fq "$token" "$DOC" || fail "Windows runtime plan missing token: $token"
done

for token in \
  'queuebash.windows_runtime_parity.v1' \
  'wsl2_first_native_windows_not_yet_supported' \
  'first_viable_target' \
  'constrained_client_candidate' \
  'future_adapter_required' \
  'native_windows_support_claim' \
  'assets.d/winrm.sh' \
  'assets.d/msad.sh' \
  'assets.d/msdns.sh' \
  'assets.d/msfs.sh'; do
  grep -Fq "$token" "$POLICY" || fail "Windows runtime parity policy missing token: $token"
done

python3 - "$POLICY" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
assert data["schema"] == "queuebash.windows_runtime_parity.v1"
assert data["owner"] == "BOB30"
assert data["support_claim"] == "wsl2_first_native_windows_not_yet_supported"
ids = {tier["id"] for tier in data["tiers"]}
assert ids == {"W1", "W2", "W3"}
required = set(data["required_adapters"])
for key in ["path", "process", "lock", "permission_acl", "scheduler_service", "identity"]:
    assert key in required
PY

if grep -R -nE 'native Windows (is )?(supported|complete)|PowerShell-native worker support is supported|Windows Service worker support is supported' \
  "$DOC" "$POLICY" >/tmp/windows_runtime_forbidden.$$ 2>/dev/null; then
  cat /tmp/windows_runtime_forbidden.$$ >&2
  rm -f /tmp/windows_runtime_forbidden.$$
  fail 'unsupported native Windows support claim leaked into Bob30 plan'
fi
rm -f /tmp/windows_runtime_forbidden.$$

echo 'PASS windows_runtime_plan_static'
