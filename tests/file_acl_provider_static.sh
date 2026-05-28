#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL $0: $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.18.22"' queuebash.sh || fail "version not bumped"
grep -q '_queue_acl_file_check' queuebash.sh || fail "file ACL check helper missing"
grep -q '_queue_acl_file_mutate' queuebash.sh || fail "file ACL mutation helper missing"
grep -q 'QUEUEBASH_FILE_ACL_POLICY' queuebash.sh || fail "file ACL policy env missing"
grep -q 'file_acl_policy_malformed' queuebash.sh || fail "malformed fail-closed reason missing"
grep -q 'no_matching_file_acl_rule' queuebash.sh || fail "no-match deny reason missing"
grep -q 'Providers supply normalized data, never shell' queuebash.sh || fail "provider-never-shell rule missing"

test -f policies.d/acl/file.example.tsv || fail "file ACL TSV example missing"
test -f examples/providers/acl/file.env.example || fail "file provider env example missing"
grep -q 'QUEUEBASH_ACL_PROVIDER=file' examples/providers/acl/file.env.example || fail "file provider env not canonical"
grep -q '/etc/queuebash/policy/acl/file_acl.tsv' examples/providers/acl/file.env.example || fail "canonical file ACL path missing"
! grep -R '/etc/bashqueues' docs/ACL_PROVIDER_CONTRACT.md examples/providers/acl/file.env.example policies.d/acl/file.example.tsv >/dev/null || fail "stale /etc/bashqueues path"
! grep -Ei 'ldap.*live|pam.*live|nss.*live' docs/ACL_PROVIDER_CONTRACT.md examples/providers/acl/file.env.example >/dev/null || fail "file provider release should not claim live LDAP/PAM/NSS"

grep -q 'subject<TAB>operation<TAB>resource<TAB>decision<TAB>reason' docs/ACL_PROVIDER_CONTRACT.md || fail "TSV format not documented"
grep -q 'subject exact beats subject \*' docs/ACL_PROVIDER_CONTRACT.md || fail "specificity rule not documented"
grep -q 'no active provider.*error.*fail_closed' docs/ACL_PROVIDER_CONTRACT.md || fail "no-provider fail-closed not documented"
grep -q 'active file provider.*no matching rule.*deny' docs/ACL_PROVIDER_CONTRACT.md || fail "no-match deny not documented"

echo "PASS $0"
