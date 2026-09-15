#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

bash -n queuebash.sh || fail 'queuebash syntax failed'
bash -n bin/queue-vcs-probe || fail 'queue-vcs-probe syntax failed'
bash -n bin/queue-vcs-baseline || fail 'queue-vcs-baseline syntax failed'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
work="$tmp/work"
mkdir -p "$work/CVS" "$tmp/fakebin"
printf ':pserver:example.invalid:/cvsroot\n' > "$work/CVS/Root"
printf 'TPROD_1989\n' > "$work/CVS/Tag"
printf '/file.c/1.1/Fri Jan 1 00:00:00 1988//\n' > "$work/CVS/Entries"
cat > "$tmp/fakebin/cvs" <<'FAKECVS'
#!/usr/bin/env bash
echo "CVS SHOULD NOT BE CALLED BY PROBE/BASELINE" >>"${BQ_VCS_FAKE_CVS_LOG:?}"
exit 99
FAKECVS
chmod +x "$tmp/fakebin/cvs"
export BQ_VCS_FAKE_CVS_LOG="$tmp/cvs-called.log"
export PATH="$tmp/fakebin:$PWD/bin:$PATH"

json="$(bin/queue-vcs-baseline --json --type cvs --timeout 1 --name release-prod "$work")" || fail 'baseline JSON failed'
python3 -c 'import json,sys; obj=json.loads(sys.stdin.read()); assert obj["schema"]=="queuebash.vcs.baseline.v1", obj; assert obj["read_only"] is True, obj; assert obj["class"]=="VCS_CHANGESET_AUDIT", obj; assert obj["type"]=="cvs", obj; assert obj["identity"]=="PROD_1989", obj; assert obj["status_summary"]=="cvs_metadata_only", obj; env=obj["env"]; assert env["QUEUEBASH_VCS_AUDIT_NAME"]=="release-prod", env; assert env["QUEUEBASH_VCS_AUDIT_TYPE"]=="cvs", env; assert env["QUEUEBASH_VCS_AUDIT_IDENTITY"]=="PROD_1989", env; assert len(env["QUEUEBASH_VCS_AUDIT_FINGERPRINT"])==64, env' <<<"$json"
[[ ! -e "$BQ_VCS_FAKE_CVS_LOG" ]] || fail 'queue-vcs-baseline/probe called CVS client unexpectedly'

export QUEUEBASH_ROOT="$PWD"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
# shellcheck disable=SC1091
. ./queuebash.sh >/dev/null
out="$(queue vcs baseline "$work" --json --type cvs --timeout 1 --name release-prod)" || fail 'queue vcs baseline JSON failed'
python3 -c 'import json,sys; obj=json.loads(sys.stdin.read()); assert obj["schema"]=="queuebash.vcs.baseline.v1", obj; assert obj["env"]["QUEUEBASH_VCS_AUDIT_IDENTITY"]=="PROD_1989", obj' <<<"$out"

human="$(queue vcs baseline "$work" --type cvs --timeout 1 --name release-prod)" || fail 'queue vcs baseline env output failed'
case "$human" in
  *'export QUEUEBASH_VCS_AUDIT_TYPE=cvs'*'export QUEUEBASH_VCS_AUDIT_FINGERPRINT='*) ;;
  *) fail "baseline env output missing expected exports: $human" ;;
esac
[[ ! -e "$BQ_VCS_FAKE_CVS_LOG" ]] || fail 'queue vcs baseline called CVS client unexpectedly'

echo '[PASS] VCS baseline command JSON smoke contract works'
