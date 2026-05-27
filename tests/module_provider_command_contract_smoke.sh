#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }
cd "$(dirname "$0")/.."

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
source ./queuebash.sh
_queue_init

_queue_module_command help provider | grep -q 'Provider modules' || fail 'provider help missing'
path="$(_queue_module_command configure provider gemini --path)"
[[ "$path" == "$QUEUEBASH_ROOT/policy/providers.d/gemini.env" ]] || fail "unexpected provider path: $path"
_queue_module_command configure provider gemini --set QUEUEBASH_PROVIDER_KIND=ai --set QUEUEBASH_AI_PROVIDER=gemini >/dev/null
_queue_module_command configure provider gemini --show | grep -q 'QUEUEBASH_PROVIDER_KIND=ai' || fail 'provider setting missing'
_queue_module_command list --json | grep -q '"kind":"provider"' || fail 'provider missing from module JSON list'
_queue_module_command policy provider gemini | grep -q 'provider policy contract' || fail 'provider policy output missing'
if _queue_module_command acl set provider gemini ai.ask BQ_AI_Users >/tmp/module_acl.out 2>&1; then
    fail 'module acl unexpectedly changed policy'
fi
grep -q 'queue acl set module provider:gemini ai.ask BQ_AI_Users' /tmp/module_acl.out || fail 'acl handoff output missing'

echo PASS
