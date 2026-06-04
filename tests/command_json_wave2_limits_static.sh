#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "[FAIL] $*" >&2; exit 1; }

grep -q 'queuebash.limits.v1' queuebash.sh || fail 'limits JSON schema missing'
grep -q 'queue limits --json emits queuebash.limits.v1' queuebash.sh || fail 'limits JSON help text missing'
grep -q 'probe_requested' queuebash.sh || fail 'limits JSON probe metadata missing'
grep -q 'QUEUEBASH_SYSTEMD_PROBE_TIMEOUT' queuebash.sh || fail 'bounded systemd probe timeout missing'

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT
QUEUEBASH_ROOT="$(mktemp -d)"
# shellcheck disable=SC1091
source ./queuebash.sh >/dev/null 2>&1

out="$(queue limits --json 2>/dev/null || true)"
python3 - "$out" <<'PY'
import json, sys
obj=json.loads(sys.argv[1])
assert obj["schema"] == "queuebash.limits.v1"
assert "queue_root" in obj
assert "systemd_run" in obj
assert "xdg_runtime_dir" in obj
assert isinstance(obj.get("supported"), bool)
assert obj.get("enforcement") in {"record-only", "systemd-run --user --pipe --wait --collect"}
assert isinstance(obj.get("probe_requested"), bool)
PY

human="$(queue limits 2>/dev/null || true)"
printf '%s\n' "$human" | grep -q '^systemd-run:' || fail 'human limits output lost systemd-run line'
printf '%s\n' "$human" | grep -q '^XDG_RUNTIME_DIR:' || fail 'human limits output lost XDG_RUNTIME_DIR line'

echo '[PASS] command JSON wave2 limits contract is wired'
