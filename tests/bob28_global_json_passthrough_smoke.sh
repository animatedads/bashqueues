#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${TMPDIR:-/tmp}/queuebash-bob28-json-$$"
rm -rf "$QUEUEBASH_ROOT"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT

# shellcheck disable=SC1091
source ./queuebash.sh

queue --json version | python3 -m json.tool >/dev/null
queue --json help | python3 -m json.tool >/dev/null
queue --json list | python3 -m json.tool >/dev/null

submit_json="$(queue --json submit bob28-global-json -- bash -lc 'echo ok')"
printf '%s\n' "$submit_json" | python3 -m json.tool >/dev/null
printf '%s\n' "$submit_json" | python3 -c 'import json, sys; payload=json.load(sys.stdin); assert payload["schema"] == "queuebash.submit_result.v1", payload; assert payload["name"] == "bob28-global-json", payload; assert "--json" not in payload.get("command_line", ""), payload'
