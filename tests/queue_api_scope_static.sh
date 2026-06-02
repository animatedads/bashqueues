#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "queue_api_scope_static: $*" >&2; exit 1; }

for f in policies.d/app-scope/installer.env.example policies.d/app-scope/qms.env.example; do
  [[ -f "$f" ]] || fail "missing $f"
  grep -q 'QUEUEBASH_APP_SCOPE_NAME=' "$f" || fail "$f missing scope name"
  grep -q 'QUEUEBASH_APP_ALLOW_OPS=' "$f" || fail "$f missing allow ops"
  grep -q 'QUEUEBASH_APP_DENY_OPS=' "$f" || fail "$f missing deny ops"
  grep -q 'QUEUEBASH_APP_AUDIT=1' "$f" || fail "$f missing audit enablement"
  grep -q 'secret.read' "$f" || fail "$f missing secret.read denial"
  grep -q 'policy.edit' "$f" || fail "$f missing policy.edit denial"
  grep -q 'dev.patch' "$f" || fail "$f missing dev.patch denial"
done

grep -q 'safe read' docs/QUEUE_API_EMBEDDED.md || fail "embedded docs missing safe read category"
grep -q 'controlled write' docs/QUEUE_API_EMBEDDED.md || fail "embedded docs missing controlled write category"
grep -q 'admin write' docs/QUEUE_API_EMBEDDED.md || fail "embedded docs missing admin write category"
grep -q 'dev/internal' docs/QUEUE_API_EMBEDDED.md || fail "embedded docs missing dev/internal category"

printf 'queue_api_scope_static: ok\n'
