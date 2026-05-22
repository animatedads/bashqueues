#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp"

queue submit testls -- echo one >/dev/null
queue submit testls -- echo two >/dev/null
queue submit failer -- definitely_not_a_command_12345 >/dev/null

queue priority testls 100 >/dev/null
queue --dryrun pause testls >/dev/null
queue pause testls >/dev/null
queue unpause testls >/dev/null

queue run --workers 2 >/dev/null || true

queue resubmit failer >/dev/null
queue --dryrun cancel failer >/dev/null || true
queue stats >/dev/null
queue events --tail 10 >/dev/null

echo "bashqueues selftest: OK"
