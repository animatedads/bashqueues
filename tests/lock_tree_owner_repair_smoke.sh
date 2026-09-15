#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh >/dev/null
queue version >/dev/null
[[ -d "$root/locks/state" ]]
[[ -w "$root/locks/state" ]]
lock="$(_queue_state_lock_acquire smoke-lock "$root" 1)"
[[ -d "$lock" ]]
_queue_state_lock_release "$lock"
[[ ! -e "$lock" ]]
