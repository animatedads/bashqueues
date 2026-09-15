#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*" >&2; exit 1; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

expected_version="$(sed -n 's/^QUEUEBASH_VERSION="\([^"]*\)".*/\1/p' queuebash.sh | head -1)"
[[ -n "$expected_version" ]] || fail "could not read QUEUEBASH_VERSION"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
printf '%s\n' "$expected_version" > "$QUEUEBASH_ROOT/.queuebash_bundled_install_version"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
source ./queuebash.sh
out="$(mktemp)"
queue --json help > "$out"
python3 - "$out" "$expected_version" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
expected=sys.argv[2]
assert obj["schema"] == "queuebash.command_catalog.v1", obj
assert obj["version"] == expected, obj
commands=set(obj.get("commands") or [])
required={
    "health","events","policies","policy","pids","metrics","hooks",
    "cancel","delete","pause","unpause","priority","clear","restore","resubmit",
    "clean-logs","compress-logs","backup","reevaluate","platform","workers",
    "tail","show","run","rto","governance","catalog",
}
missing=sorted(required-commands)
assert not missing, missing
assert obj.get("global_json") is True, obj
PY
