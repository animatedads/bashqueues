#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
source ./queuebash.sh
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT

paths_json="$(queue policy paths --json)"
status_json="$(queue policy status --json)"

python3 - "$paths_json" "$status_json" <<'PY'
import json, sys
paths=json.loads(sys.argv[1])
status=json.loads(sys.argv[2])
assert paths["schema"] == "queuebash.policy_paths.v1"
assert status["schema"] == "queuebash.policy_status.v1"
assert paths["system_policy_root"] == "/etc/queuebash/policies.d"
assert paths["legacy_policy_root"] == "/etc/bashqueues/policies.d"
assert paths["active_policy_root"] == "/etc/queuebash/policies.d"
assert paths["system_modified"] is False
assert status["active_policy_root"] == "/etc/queuebash/policies.d"
assert status["legacy_root_active"] is False
assert status["system_modified"] is False
counts=status["policy_counts"]
assert set(counts) == {"sandbox", "seccomp", "class_statement", "total"}
assert counts["total"] == counts["sandbox"] + counts["seccomp"] + counts["class_statement"]
print("policy paths/status JSON ok")
PY
