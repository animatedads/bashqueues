#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

[[ -f queuebash.sh ]] || fail "run from repository root"
grep -Eq 'QUEUEBASH_VERSION="0\.18\.(4[0-9]|([5-9][0-9]|[1-9][0-9][0-9]))"' queuebash.sh || fail 'queuebash version not current enough for dev splice compatibility'
[[ -f docs/DEV_SPLICE_TOOL.md ]] || fail 'missing dev splice doc'
[[ -f tests/dev_splice_tool_smoke.sh ]] || fail 'missing dev splice smoke test'
grep -q 'trailing newlines are preserved exactly' docs/DEV_SPLICE_TOOL.md || fail 'docs do not mention exact file-content preservation'
grep -q -- '--replace/--replace-file requires explicit --with/--with-file' queuebash.sh || fail 'replace without with guard missing'

grep -q '_queue_dev_splice()' queuebash.sh || fail 'missing _queue_dev_splice function'
grep -q 'splice) _queue_dev_splice' queuebash.sh || fail 'dev dispatcher missing splice subcommand'
grep -q 'queue dev splice' queuebash.sh || fail 'dev help missing splice'
grep -q 'queuebash.dev_splice_response.v1' queuebash.sh || fail 'splice JSON schema missing in implementation'
grep -q 'queuebash.dev_splice_response.v1' docs/DEV_SPLICE_TOOL.md || fail 'splice JSON schema missing in docs'
grep -q -- '--dry-run' queuebash.sh || fail 'dry-run support missing'
grep -q -- '--if-missing' queuebash.sh || fail 'if-missing support missing'
grep -q 'os.replace(tmp, path)' queuebash.sh || fail 'atomic replace pattern missing'
grep -q 'os.chmod(tmp' queuebash.sh || fail 'permission preservation missing'

splice_body="$(sed -n '/^_queue_dev_splice()/,/^_queue_dev_command()/p' queuebash.sh)"
if printf '%s
' "$splice_body" | grep -q 'cat "\$after_file"\|cat "\$before_file"\|cat "\$replace_file"\|cat "\$insert_file"\|cat "\$with_file"'; then
  fail 'file-based splice inputs must not be read through shell command substitution'
fi

if printf '%s\n' "$splice_body" | grep -Eq 'eval[[:space:]]|(^|[^[:alpha:]])source[[:space:]].*insert|bash[[:space:]]+-c.*insert'; then
  fail 'splice implementation appears to execute inserted content'
fi

! [[ -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
echo 'PASS dev_splice_tool_static'
