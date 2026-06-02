#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "queue_api_protocol_static: $*" >&2; exit 1; }

[[ -f docs/QUEUE_API_EMBEDDED.md ]] || fail "missing docs/QUEUE_API_EMBEDDED.md"
[[ -f docs/QUEUE_API_PROTOCOL.md ]] || fail "missing docs/QUEUE_API_PROTOCOL.md"

grep -q 'queue api serve --stdio' docs/QUEUE_API_EMBEDDED.md || fail "embedded docs missing stdio serve command"
grep -q 'The CLI is for humans' docs/QUEUE_API_EMBEDDED.md || fail "embedded docs missing architectural rule"
grep -q 'queuebash.api.request.v1' docs/QUEUE_API_PROTOCOL.md || fail "protocol docs missing request schema"
grep -q 'queuebash.api.response.v1' docs/QUEUE_API_PROTOCOL.md || fail "protocol docs missing response schema"
grep -q 'unknown_operation' docs/QUEUE_API_PROTOCOL.md || fail "protocol docs missing fail-closed error code"
grep -q 'operation_denied' docs/QUEUE_API_PROTOCOL.md || fail "protocol docs missing denied error code"
grep -q 'admin/dev operations fail closed' docs/QUEUE_API_EMBEDDED.md || fail "embedded docs missing fail-closed admin/dev rule"

# Contract-first only: this patch must not claim to ship a runtime broker.
if grep -q '^ *api)' queuebash.sh; then
  fail "queuebash.sh already exposes runtime queue api dispatcher; this contract patch should not"
fi

printf 'queue_api_protocol_static: ok\n'
