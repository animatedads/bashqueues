#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"

grep -q 'dependencies: str = ""' queuemgr_panel.py || fail "TaskDraft missing dependencies field"
grep -q 'inherit_env_from: str = ""' queuemgr_panel.py || fail "TaskDraft missing inherit-env field"
grep -q 'on_success: str = ""' queuemgr_panel.py || fail "TaskDraft missing on-success hook field"
grep -q 'on_failure: str = ""' queuemgr_panel.py || fail "TaskDraft missing on-failure hook field"
grep -q 'on_retry_failure: str = ""' queuemgr_panel.py || fail "TaskDraft missing on-retry-failure hook field"

grep -q '"--after-success"' queuemgr_panel.py || fail "Task submit args do not emit --after-success"
grep -q '"--inherit-env-from"' queuemgr_panel.py || fail "Task submit args do not emit --inherit-env-from"
grep -q '"--on-success"' queuemgr_panel.py || fail "Task submit args do not emit --on-success"
grep -q '"--on-failure"' queuemgr_panel.py || fail "Task submit args do not emit --on-failure"
grep -q '"--on-retry-failure"' queuemgr_panel.py || fail "Task submit args do not emit --on-retry-failure"

grep -q 'DEPENDS_AFTER_SUCCESS=(' queuebash.sh || fail "draft create does not persist dependencies"
grep -q 'INHERIT_ENV_FROM=(' queuebash.sh || fail "draft create does not persist inherited-env dependencies"
grep -q 'ON_SUCCESS=(' queuebash.sh || fail "draft create does not persist success hook"
grep -q 'ON_FAILURE=(' queuebash.sh || fail "draft create does not persist failure hook"
grep -q 'ON_RETRY_FAILURE=(' queuebash.sh || fail "draft create does not persist retry hook"

grep -q 'Task Creator/job editor fields for dependencies and hooks' CHANGELOG.md || fail "CHANGELOG missing hook/dependency entry"
grep -q 'Task Creator also exposes operational dependency and hook fields' README.md || fail "README missing Task Creator hook/dependency docs"
grep -q 'Task Creator includes the safety-critical job orchestration fields' docs/QUEUEMGR.md || fail "QUEUEMGR docs missing hook/dependency docs"

python3 - <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("qpanel", "queuemgr_panel.py")
mod = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)
d = mod.TaskDraft(
    name="hooked",
    command="echo main",
    dependencies="abc123, setup_job",
    inherit_env_from="env_job",
    on_success="bash -c 'echo ok'",
    on_failure="bash -c 'echo bad'",
    on_retry_failure="bash -c 'echo retry'",
)
args = d.submit_args()
for token in ["--after-success", "--inherit-env-from", "--on-success", "--on-failure", "--on-retry-failure"]:
    assert token in args, (token, args)
assert args.index("--on-retry-failure") < args.index("--on-success") < args.index("--on-failure"), args
print("[PASS] TaskDraft emits dependency/hook submit args")
PY

pass "Task Creator supports hooks/dependencies and drafts preserve them"
