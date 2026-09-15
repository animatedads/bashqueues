#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

bash -n queuebash.sh
python3 -m py_compile bin/queue-ai-ask-oci
[[ -x bin/queue-ai-ask-oci ]]

self_test="$(bin/queue-ai-ask-oci --self-test)"
printf '%s\n' "$self_test" | python3 -m json.tool >/dev/null
grep -q '"provider": "oci"' <<<"$self_test"
grep -q '"live_call_performed": false' <<<"$self_test"

export QUEUEBASH_ROOT="${TMPDIR:-/tmp}/bq-oci-provider-static-$$"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

queue ask providers --json | python3 -m json.tool >/dev/null
queue ask providers --json | grep -q '"oci"'
queue ask provider explain oci --json | python3 -m json.tool >/dev/null
queue ask provider explain oci --json | grep -q '"provider":"oci"'
queue ask provider explain oci --json | grep -q '"requires_network":true'
queue ask provider explain oci --json | grep -q '"live_supported":true'

# Live provider calls must still fail closed unless explicitly enabled.
if queue ask --provider oci --live 'hello from oci provider smoke' >/tmp/bq-oci-live.out 2>/tmp/bq-oci-live.err; then
  echo "expected oci live ask to be blocked without QUEUEBASH_AI_LIVE_ENABLED" >&2
  exit 1
fi
grep -q 'live_ai_provider_not_enabled' /tmp/bq-oci-live.err

rm -rf "$QUEUEBASH_ROOT"
echo "oci_ask_provider_static_smoke: ok"
