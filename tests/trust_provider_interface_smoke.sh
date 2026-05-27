#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
work="$(mktemp -d "${TMPDIR:-/tmp}/bq-trust-provider.XXXXXX")"
trap 'rm -rf "$work"' EXIT
profile="$work/self.seccomp.env"
cat > "$profile" <<'PROFILE'
SECPROFILE_STATUS=approved
SECPROFILE_SHOULD_BE_SIGNED=1
SECPROFILE_SIGNED=1
SECPROFILE_SIGNED_BY=self:tester
SECPROFILE_SELF_SIGNED=1
SECPROFILE_ALLOWED_SYSCALLS=read,write,exit_group
SECPROFILE_SIGNATURE_ALG=sha256-self
PROFILE
sig="$(grep -Ev '^SECPROFILE_(SIGNATURE_SHA256|SIGNATURE_PAYLOAD_SHA256|SIGNATURE_B64|SIGNATURE_ALG|PUBLIC_KEY_SHA256)=' "$profile" | sha256sum | awk '{print $1}')"
printf 'SECPROFILE_SIGNATURE_SHA256=%s\n' "$sig" >> "$profile"
source assets.d/secprofile.sh
queue_asset_check_secprofile_profile_verified token self profile_file="$profile" allow_self_signed=1 >/tmp/bq-trust-pass.out || fail 'file provider should allow explicit self-signed dev profile'
policy="$work/trust.conf"
cat > "$policy" <<'POLICY'
TRUST_PROVIDER=file
TRUST_DENY_SELF_SIGNED=1
POLICY
if queue_asset_check_secprofile_profile_verified token self profile_file="$profile" allow_self_signed=1 trust_policy="$policy" >"$work/deny.out" 2>&1; then
  cat "$work/deny.out" >&2
  fail 'file policy should override and deny self-signed profile'
fi
grep -q 'self_signed_not_allowed' "$work/deny.out" || fail 'deny reason should mention self-signed block'
helper="$work/trust-helper"
cat > "$helper" <<'HELPER'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  public-key)
    echo "/tmp/nonexistent.pub.pem"
    exit 0
    ;;
  signer-allowed)
    case "${TRUST_HELPER_DECISION:-allow}" in
      allow) exit 0 ;;
      deny) exit 7 ;;
    esac
    ;;
esac
exit 9
HELPER
chmod +x "$helper"
queue_asset_check_secprofile_profile_verified token self profile_file="$profile" trust_provider=exec trust_helper="$helper" >/tmp/bq-trust-exec-pass.out || fail 'exec provider should be able to allow signer'
if TRUST_HELPER_DECISION=deny queue_asset_check_secprofile_profile_verified token self profile_file="$profile" trust_provider=exec trust_helper="$helper" >"$work/exec-deny.out" 2>&1; then
  cat "$work/exec-deny.out" >&2
  fail 'exec provider denial should block profile'
fi
grep -q 'trust_provider_denied' "$work/exec-deny.out" || fail 'exec deny reason should mention provider denial'
export QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_ROOT="$work/root"
source ./queuebash.sh
queue dev functions --file assets.d/secprofile.sh --json > "$work/functions.json"
python3 - "$work/functions.json" <<'PY'
import json, sys
j=json.load(open(sys.argv[1]))
names={f['function'] for f in j['functions']}
assert '_queue_asset_secprofile_trust_ok' in names
assert '_queue_asset_secprofile_public_key' in names
PY
queue dev extract _queue_asset_secprofile_trust_ok --file assets.d/secprofile.sh --json > "$work/extract.json"
python3 - "$work/extract.json" <<'PY'
import json, sys
j=json.load(open(sys.argv[1]))
assert 'trust_provider=exec' in j['body']
assert 'signer-allowed' in j['body']
PY
echo '[PASS] trust provider interface smoke checks pass'
