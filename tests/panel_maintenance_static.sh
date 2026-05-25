#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
panel="$repo_root/queuemgr_panel.py"
class_file="$repo_root/classes/QUEUE_MAINTENANCE.env"
qdoc="$repo_root/docs/QUEUEMGR.md"
readme="$repo_root/README.md"
classes_doc="$repo_root/docs/CLASSES.md"
changelog="$repo_root/CHANGELOG.md"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

python3 -m py_compile "$panel" || fail "panel does not compile"

grep -q 'class MaintenanceRecipe' "$panel" || fail "missing MaintenanceRecipe model"
grep -q 'MAINTENANCE_RECIPES' "$panel" || fail "missing maintenance recipes"
grep -q 'ViewState("maintenance", "Maintenance"' "$panel" || fail "Maintenance view not registered"
grep -q 'def load_maintenance' "$panel" || fail "missing maintenance loader"
grep -q 'def detail_maintenance' "$panel" || fail "missing maintenance detail"
grep -q 'def maintenance_submit_args' "$panel" || fail "missing queued maintenance submit builder"
grep -q 'def maintenance_action' "$panel" || fail "missing maintenance action handler"
grep -q 'self.prompt_choice("Maintenance action"' "$panel" || fail "maintenance action does not use shared choice resolver"
grep -q '"direct"' "$panel" || fail "maintenance direct run action missing"
grep -q '"queue"' "$panel" || fail "maintenance queue action missing"
grep -q '"--class", recipe.default_class' "$panel" || fail "maintenance submit does not use recipe class"
grep -q 'QUEUE_MAINTENANCE' "$panel" || fail "panel does not reference QUEUE_MAINTENANCE"
grep -q 'queue_payload_command' "$panel" || fail "maintenance payload queue command helper missing"
grep -q 'PANEL_QUEUE_USER' "$panel" || fail "selected queue owner is not considered by panel"

test -f "$class_file" || fail "QUEUE_MAINTENANCE class file missing"
grep -q 'CLASS_ALLOW_PARALLEL=0' "$class_file" || fail "maintenance class not serialized"
grep -q 'CLASS_MAX_CONCURRENT=1' "$class_file" || fail "maintenance class concurrency not bounded"
grep -q 'queue_class_exclusive_claim "queue:maintenance"' "$class_file" || fail "maintenance class missing exclusive claim"
grep -q 'CLASS_DEFAULT_TIMEOUT=1h' "$class_file" || fail "maintenance class missing timeout"
grep -q 'CLASS_DEFAULT_MAX_LOG_SIZE_BYTES=10485760' "$class_file" || fail "maintenance class missing log cap"

grep -q 'Maintenance panel' "$qdoc" || fail "QueueManager docs missing Maintenance panel"
grep -q 'direct.*urgent recovery\|urgent recovery' "$qdoc" || fail "QueueManager docs missing direct urgent-recovery wording"
grep -q 'Panel Maintenance view' "$readme" || fail "README missing panel maintenance docs"
grep -q 'QUEUE_MAINTENANCE' "$classes_doc" || fail "class docs missing QUEUE_MAINTENANCE"
grep -q '0.16.14' "$changelog" || fail "CHANGELOG missing 0.16.14"

pass "panel Maintenance view queues housekeeping by default and supports direct urgent run"
pass "QUEUE_MAINTENANCE class and docs are present"
