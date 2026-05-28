#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
# shellcheck disable=SC1091
source ./queuebash.sh

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT
export QUEUEBASH_ROOT="$tmproot"
mkdir -p "$tmproot/policy/acl"
cat > "$tmproot/policy/acl/file_acl.tsv" <<'TSV'
hc3	job.submit	*	allow	local submit
hc3	dev.patch	*	deny	no dev patch
*	ai.ask	*	allow	AI ask allowed
TSV

allow_json="$(QUEUEBASH_ACL_PROVIDER=file QUEUEBASH_FILE_ACL_POLICY="$tmproot/policy/acl/file_acl.tsv" queue acl check hc3 job.submit '*' --json)"
printf '%s\n' "$allow_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.acl_decision.v1"; assert d["provider"]=="file"; assert d["decision"]=="allow"; assert d["fail_closed"] is False'

denied=0
QUEUEBASH_ACL_PROVIDER=file QUEUEBASH_FILE_ACL_POLICY="$tmproot/policy/acl/file_acl.tsv" queue acl check hc3 dev.patch '*' --json >/tmp/file_acl_deny.json || denied=$?
[[ "$denied" -eq 1 ]] || { echo "expected deny exit 1, got $denied" >&2; exit 1; }
python3 -c 'import json; d=json.load(open("/tmp/file_acl_deny.json")); assert d["decision"]=="deny"; assert d["fail_closed"] is True'

nomatch=0
QUEUEBASH_ACL_PROVIDER=file QUEUEBASH_FILE_ACL_POLICY="$tmproot/policy/acl/file_acl.tsv" queue acl check hc3 job.cancel '*' --json >/tmp/file_acl_nomatch.json || nomatch=$?
[[ "$nomatch" -eq 1 ]] || { echo "expected no-match deny exit 1, got $nomatch" >&2; exit 1; }
python3 -c 'import json; d=json.load(open("/tmp/file_acl_nomatch.json")); assert d["decision"]=="deny"; assert d["reason"]=="no_matching_file_acl_rule"'

cat > "$tmproot/policy/acl/bad.tsv" <<'TSV'
hc3	job.submit	*	allow
TSV
bad=0
QUEUEBASH_ACL_PROVIDER=file QUEUEBASH_FILE_ACL_POLICY="$tmproot/policy/acl/bad.tsv" queue acl check hc3 job.submit '*' --json >/tmp/file_acl_bad.json || bad=$?
[[ "$bad" -eq 3 ]] || { echo "expected malformed exit 3, got $bad" >&2; exit 1; }
python3 -c 'import json; d=json.load(open("/tmp/file_acl_bad.json")); assert d["decision"]=="error"; assert d["reason"]=="file_acl_policy_malformed"; assert d["fail_closed"] is True'

QUEUEBASH_ACL_PROVIDER=file QUEUEBASH_FILE_ACL_POLICY="$tmproot/policy/acl/file_acl.tsv" queue acl set module provider:file ai.context.queue_status hc3 '*' --reason 'queue status allowed' >/tmp/file_acl_set.txt
grep -Fq $'hc3\tai.context.queue_status\t*\tallow\tqueue status allowed' "$tmproot/policy/acl/file_acl.tsv"
QUEUEBASH_ACL_PROVIDER=file QUEUEBASH_FILE_ACL_POLICY="$tmproot/policy/acl/file_acl.tsv" queue acl remove module provider:file ai.context.queue_status hc3 '*' >/tmp/file_acl_remove.txt
! grep -Fq $'hc3\tai.context.queue_status\t*\tallow\tqueue status allowed' "$tmproot/policy/acl/file_acl.tsv"

printf 'PASS %s\n' "$0"
