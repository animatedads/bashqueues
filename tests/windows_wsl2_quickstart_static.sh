#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT/docs/WINDOWS_WSL2_QUICKSTART.md"
POLICY="$ROOT/policies.d/platform/windows-wsl2-quickstart.json"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

[[ -f "$DOC" ]] || fail "missing $DOC"
[[ -f "$POLICY" ]] || fail "missing $POLICY"

for token in \
  "WSL2" "Linux distribution" "Linux filesystem" "/mnt/c" "queue version --json" \
  "native PowerShell worker runtime" "Windows Service worker installation" \
  "Task Scheduler" "NTFS ACL" "LF" "CRLF" "WinRM" "OpenSSH" "MSAD" "MSDNS" "MSFS"; do
  grep -Fq "$token" "$DOC" || fail "WSL2 quickstart missing token: $token"
done

for token in \
  'queuebash.windows_wsl2_quickstart.v1' \
  'wsl2_linux_guest_runtime' \
  'linux_filesystem_not_mnt_c' \
  'lf_required_for_shell_scripts' \
  'not_supported_yet' \
  'native_powershell_worker_runtime' \
  'windows_service_worker_installation'; do
  grep -Fq "$token" "$POLICY" || fail "WSL2 quickstart policy missing token: $token"
done

python3 - "$POLICY" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
assert data['schema'] == 'queuebash.windows_wsl2_quickstart.v1'
assert data['owner'] == 'BOB30'
assert data['first_supported_route'] == 'wsl2_linux_guest_runtime'
assert data['native_windows_claim'] == 'not_supported_yet'
assert 'queue version --json' in data['minimum_wsl2_smoke']
PY

if grep -R -nE 'native Windows (is )?(supported|complete)|PowerShell-native worker support is supported|Windows Service worker support is supported' \
  "$DOC" "$POLICY" >/tmp/windows_wsl2_forbidden.$$ 2>/dev/null; then
  cat /tmp/windows_wsl2_forbidden.$$ >&2
  rm -f /tmp/windows_wsl2_forbidden.$$
  fail 'unsupported native Windows support claim leaked into WSL2 quickstart'
fi
rm -f /tmp/windows_wsl2_forbidden.$$

echo 'PASS windows_wsl2_quickstart_static'
