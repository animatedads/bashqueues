#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL $*" >&2; exit 1; }

[[ -f assets.d/ibm_identity.sh ]] || fail 'missing assets.d/ibm_identity.sh'
bash -n assets.d/ibm_identity.sh || fail 'ibm identity asset syntax'
grep -q 'ibm_identity:auth_active' assets.d/ibm_identity.sh || fail 'missing auth_active facility'
grep -q 'ibm_identity:target_region_allowed' assets.d/ibm_identity.sh || fail 'missing target_region_allowed facility'
grep -q 'QUEUEBASH_IBM_REGION' assets.d/ibm_identity.sh || fail 'missing QUEUEBASH_IBM_REGION support'
grep -q 'QUEUEBASH_IBM_ACCOUNT_ID' assets.d/ibm_identity.sh || fail 'missing account id support'
grep -q 'tool_missing=ibmcloud' assets.d/ibm_identity.sh || fail 'missing fail-closed missing CLI message'
grep -q 'QUEUEBASH_VERSION="0.18.22"' queuebash.sh || fail 'version not bumped to 0.18.22'

# Smoke the asset without live IBM credentials by using a fake ibmcloud binary.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/ibmcloud" <<'FAKE'
#!/usr/bin/env bash
case "$1" in
  target)
    cat <<'OUT'
API endpoint:      https://cloud.ibm.com
Region:            eu-gb
User:              tester@example.com
Account:           acct-123
Resource group:    default
OUT
    exit 0 ;;
  *) exit 2 ;;
esac
FAKE
chmod +x "$tmp/ibmcloud"

PATH="$tmp:$PATH" QUEUEBASH_IBM_REGION=eu-gb QUEUEBASH_IBM_ACCOUNT_ID=acct-123 bash -c '
  source assets.d/ibm_identity.sh
  queue_asset_check_ibm_identity_auth_active tok acct-123 >/tmp/ibm_auth.out
  queue_asset_check_ibm_identity_target_region_allowed tok GDPR >/tmp/ibm_region.out
'
grep -q 'asset_check_ok: tok' /tmp/ibm_auth.out || fail 'fake ibm auth did not pass'
grep -q 'asset_check_ok: tok' /tmp/ibm_region.out || fail 'fake ibm region did not pass'

set +e
QUEUEBASH_IBM_REGION=us-south bash -c '
  source assets.d/ibm_identity.sh
  queue_asset_check_ibm_identity_target_region_allowed tok GDPR >/tmp/ibm_region_bad.out 2>&1
'
bad_rc=$?
set -e
[[ "$bad_rc" -ne 0 ]] || fail 'GDPR should not allow us-south by default'
grep -q 'asset_check_blocked: ibm_identity:target_region_allowed' /tmp/ibm_region_bad.out || fail 'bad IBM region did not block as expected'

echo "PASS tests/ibm_identity_asset_static.sh"
