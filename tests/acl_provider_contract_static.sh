#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail(){ echo "FAIL $0: $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.18.22"' queuebash.sh || fail "version not bumped"
grep -q '_queue_acl_command' queuebash.sh || fail "queue acl command missing"
grep -q 'queuebash.acl_decision.v1' queuebash.sh || fail "ACL decision schema missing from command surface"
grep -q 'queue acl check SUBJECT OPERATION RESOURCE' queuebash.sh || fail "canonical ACL check usage missing"
grep -q 'queue acl set module provider:NAME OPERATION SUBJECT' queuebash.sh || fail "canonical ACL set usage missing"
grep -q 'job.submit' queuebash.sh || fail "normalized operation job.submit missing"
grep -q 'ai.context.job_metadata' queuebash.sh || fail "normalized AI metadata operation missing"
grep -q 'providers supply normalized data, never shell\|provider output is normalized data, never shell' queuebash.sh || fail "provider data-never-shell rule missing"

test -f docs/ACL_PROVIDER_CONTRACT.md || fail "ACL provider contract doc missing"
test -f docs/KEY_PROVIDER_CONTRACT.md || fail "key provider contract doc missing"
for f in examples/providers/acl/file.env.example examples/providers/acl/ldap.env.example examples/providers/acl/pam.env.example; do
  test -f "$f" || fail "missing example: $f"
  grep -q '/etc/queuebash' "$f" || fail "example does not use /etc/queuebash: $f"
  ! grep -q '/etc/bashqueues' "$f" || fail "stale /etc/bashqueues path in $f"
done

grep -q 'Can subject X perform operation Y on resource Z' docs/ACL_PROVIDER_CONTRACT.md || fail "ACL question model missing"
grep -q 'allow.*deny.*error\|allow' docs/ACL_PROVIDER_CONTRACT.md || fail "allow/deny/error decision model missing"
grep -q 'Providers return data, never shell' docs/ACL_PROVIDER_CONTRACT.md || fail "data never shell rule missing"
grep -q 'missing, malformed, or failed provider output fails closed' docs/KEY_PROVIDER_CONTRACT.md || fail "key fail-closed rule missing"

echo "PASS $0"
