#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
export QUEUEBASH_SHARED_POLICY_ROOT="$tmp/etc/policies.d"
mkdir -p "$QUEUEBASH_ROOT" "$QUEUEBASH_SHARED_POLICY_ROOT/class-statement"
# shellcheck source=/dev/null
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh
# Root/default auto target should be shared in this test container.
path="$(queue policies path class-statement default)"
case "$path" in "$QUEUEBASH_SHARED_POLICY_ROOT/class-statement/default.env") ;; *) echo "wrong policy path: $path" >&2; exit 1 ;; esac
cat > "$tmp/editor.sh" <<'EOS'
#!/usr/bin/env bash
echo '# edited by smoke test' >> "$1"
EOS
chmod +x "$tmp/editor.sh"
VISUAL="$tmp/editor.sh" queue policies edit class-statement default >/tmp/pol_editor.out 2>/tmp/pol_editor.err
[[ -f "$QUEUEBASH_SHARED_POLICY_ROOT/class-statement/default.env" ]]
grep -q 'edited by smoke test' "$QUEUEBASH_SHARED_POLICY_ROOT/class-statement/default.env"
# A shared policy that marks explicit sandbox off as weak must not make an ordinary
# default submit require a reason. Explicit --sandbox off must still be gated.
cat > "$QUEUEBASH_SHARED_POLICY_ROOT/class-statement/default.env" <<'EOS'
QUEUEBASH_POLICY_KIND=class-statement
QUEUEBASH_POLICY_NAME=default
CLASS_POLICY_USER_SANDBOX_POLICIES="off network-none restrict-egress strict queue-default"
CLASS_POLICY_USER_SECCOMP_POLICIES="off docker-default strict queue-default"
CLASS_POLICY_WEAK_POLICY_REQUIRE="reason-or-authorisation"
CLASS_POLICY_SANDBOX_REASON_REQUIRED="off"
CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE="reason-or-authorisation"
CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="off"
EOS
queue submit ok_default -- echo ok >/tmp/submit_ok.out
if queue submit bad_explicit --sandbox off -- echo bad >/tmp/submit_bad.out 2>/tmp/submit_bad.err; then
  echo 'explicit weak sandbox submit unexpectedly succeeded' >&2
  exit 1
fi
grep -q 'requires --reason TEXT or --authorisation CODE' /tmp/submit_bad.err
jobf=("$QUEUEBASH_ROOT"/pending/*.job)
grep -q '^SECURITY_SANDBOX_EXPLICIT=0' "${jobf[0]}"
echo '[PASS] root-aware policy editor targets shared policy and implicit defaults are not weak exceptions'
