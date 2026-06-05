#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$root"
source ./queuebash.sh

out="$(queue health --json)"
printf '%s\n' "$out" > /tmp/qh_out.json
python3 - <<'PY'
import json
with open("/tmp/qh_out.json") as f:
    data=json.load(f)
assert data["schema"] == "queuebash.health.v1", data
assert data["queue_root"], data
assert data["version"] == "0.18.124", data
assert isinstance(data["ok"], bool), data
assert data["status"] in {"ok", "degraded", "unhealthy"}, data
assert data["fix"] is False, data
assert data["deep"] is False, data
assert isinstance(data["summary"], dict), data
assert isinstance(data["summary"].get("errors"), int), data
assert isinstance(data["summary"].get("warnings"), int), data
assert isinstance(data["summary"].get("fixes"), int), data
assert isinstance(data["checks"], list), data
assert data["checks"], data
PY

fixout="$(queue health --json --fix)"
printf '%s\n' "$fixout" > /tmp/qh_fix.json
python3 - <<'PY'
import json
with open("/tmp/qh_fix.json") as f:
    data=json.load(f)
assert data["schema"] == "queuebash.health.v1", data
assert data["fix"] is True, data
assert isinstance(data["checks"], list), data
PY

if queue health --json --bogus >/tmp/qh_bad.json 2>/tmp/qh_bad.err; then
  echo "expected queue health --json --bogus to fail" >&2
  exit 1
fi
python3 - <<'PY'
import json
with open('/tmp/qh_bad.json') as f:
    data=json.load(f)
assert data["schema"] == "queuebash.health.v1", data
assert data["ok"] is False, data
assert data["status"] == "usage_error", data
assert data["error"]["code"] == "unexpected_argument", data
PY
