#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="$repo/bin/queue-dev-runner.py"
setup="$repo/bin/queue-dev-runner-setup-locked-user"
doc="$repo/docs/DEV_REMOTE_RUNNER.md"

[[ -f "$runner" ]] || { echo "missing runner" >&2; exit 1; }
[[ -x "$setup" ]] || { echo "missing locked user setup helper" >&2; exit 1; }
[[ -f "$doc" ]] || { echo "missing doc" >&2; exit 1; }
python3 -m py_compile "$runner"

if grep -q 'from __future__ import annotations' "$runner"; then
  echo "Python 3.7 future annotations import is not allowed; target hosts may run Python 3.6" >&2
  exit 1
fi
if grep -q 'http.server.ThreadingHTTPServer' "$runner"; then
  echo "Python 3.7-only http.server.ThreadingHTTPServer is not allowed" >&2
  exit 1
fi

grep -q 'socketserver.ThreadingMixIn\|ThreadingMixIn' "$runner"
grep -q 'HTTPServer' "$runner"
grep -q '127.0.0.1' "$runner"
grep -q -- '--public' "$runner"
grep -q 'queuebash.dev_remote_runner.v1' "$runner"
grep -q 'mint_bootstrap' "$runner"
grep -q 'BOOTSTRAP_CODE' "$runner"
grep -q 'APPROVED_TESTS' "$runner"
grep -q 'safe_join' "$runner"
grep -q 'symlink escape' "$runner"
grep -q 'max_upload_bytes' "$runner"
grep -q 'queue dev patch' "$runner"
grep -q 'queue dev splice' "$runner"
grep -q 'queue dev test' "$runner"
grep -q '_handle_dev_test' "$runner"
grep -q 'visible_console' "$runner"
grep -Eq -- 'sudo.*-u|runuser' "$runner"
grep -Eq -- '--no-create-execution-user' "$runner"
grep -Eq -- '--create-execution-user' "$runner"
grep -Eq -- '--execution-user' "$runner"
grep -Eq -- 'lockeduser' "$runner"

grep -q 'list_session_processes' "$runner"
grep -q 'kill_session_process' "$runner"
grep -q 'PROCESS_REGISTER' "$runner"
grep -q 'PROCESS_KILL' "$runner"
grep -q 'not_session_process' "$runner"

# No generic HTTP endpoint should be named run/exec/shell/command/cmd.
if grep -Eq 'op == "(run|exec|shell|command|cmd)"|operation == "(run|exec|shell|command|cmd)"|"/run"' "$runner"; then
  echo "generic command endpoint found" >&2
  exit 1
fi
if grep -Eq 'add_argument\("--(command|cmd|shell|exec|run)"' "$runner"; then
  echo "generic command argument found" >&2
  exit 1
fi

grep -qi 'not.*shell\|not.*general' "$doc"
grep -q 'No arbitrary command' "$doc"
grep -q 'lockeduser' "$doc"
grep -q 'visible on screen' "$doc"
grep -q 'ps' "$doc"
grep -q 'kill' "$doc"
grep -q 'queuebash.dev_remote_runner.v1' "$doc"
grep -q 'useradd --create-home --shell /usr/sbin/nologin' "$setup"
grep -q 'passwd -l' "$setup"
grep -q 'sudo|wheel|admin' "$setup"

echo "PASS dev_remote_runner_static"
