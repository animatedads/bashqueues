#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() { echo "[FAIL] $*" >&2; exit 1; }

expected_files=(
  assets.d/msad.sh
  assets.d/entra.sh
  assets.d/msfs.sh
  assets.d/mscloud.sh
  assets.d/exchange.sh
  assets.d/teams.sh
  assets.d/msdns.sh
  assets.d/msca.sh
  assets.d/winrm.sh
  assets.d/azure.sh
  assets.d/vault.sh
)

for f in "${expected_files[@]}"; do
  [[ -f "$f" ]] || fail "missing Microsoft asset helper: $f"
  bash -n "$f" || fail "bash -n failed for $f"
  grep -q '^queue_asset_facilities()' "$f" || fail "$f does not publish queue_asset_facilities"
  grep -q '^queue_asset_hints()' "$f" || fail "$f does not publish queue_asset_hints"
  grep -q 'queue_asset_check_' "$f" || fail "$f does not define asset checks"
done

[[ -f classes/MSDOMAIN.env ]] || fail "missing MSDOMAIN class template"
bash -n classes/MSDOMAIN.env || fail "bash -n failed for classes/MSDOMAIN.env"
grep -q 'microsoft:graph_api' classes/MSDOMAIN.env || fail "MSDOMAIN class missing Graph global claim"

out="$(QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -c 'source ./queuebash.sh >/dev/null; queue assets list --json')"
for facility in \
  msad:ldap_bind msad:kerberos_ticket msad:group_membership \
  entra:token_valid entra:graph_scope \
  msfs:smb_mountable msfs:smb_permissions \
  mscloud:sharepoint_access mscloud:onedrive_file_exists \
  exchange:mailbox_exists exchange:send_test_mail \
  teams:webhook_alive teams:graph_presence \
  msdns:record_exists \
  msca:crl_valid msca:ocsp_status \
  winrm:connect winrm:run_command \
  azure:resource_exists azure:vm_powerstate azure:storage_account_access \
  vault:secret_exists vault:secret_version; do
  grep -q '"facility":"'"$facility"'"' <<<"$out" || fail "missing facility in assets JSON: $facility"
done

# Asset listing must remain metadata-only. These strings indicate a live probe/prompt leaked into discovery.
if grep -qiE 'authenticity of host|are you sure you want to continue|asset_check_blocked|asset_check_ok' <<<"$out"; then
  fail "asset list --json appears to have executed a live check or prompted"
fi

[[ ! -e assets.d/net_usage.sh ]] || fail "assets.d/net_usage.sh must remain absent"

echo "[PASS] Microsoft asset helpers are present and published through metadata-only JSON discovery"
