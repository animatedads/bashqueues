#!/usr/bin/env python3
import ast
import pathlib

repo = pathlib.Path(__file__).resolve().parents[1]
runner = repo / "bin" / "queue-dev-runner.py"
text = runner.read_text()
module = ast.parse(text)
try:
    ast.parse(text, feature_version=(3, 6))
except TypeError:
    pass

assert 'SCHEMA = "queuebash.dev_remote_runner.v1"' in text
assert "APPROVED_TESTS" in text
assert "lockeduser" in text
assert "--execution-user" in text
assert "--create-execution-user" in text
assert "BOOTSTRAP_CODE" in text
assert "mint_bootstrap" in text
assert "from __future__ import annotations" not in text
assert "ThreadingMixIn" in text
assert "HTTPServer" in text
assert "ThreadingHTTPServer" not in text
for op in ["create_session", "upload", "patch-function", "splice", "test", "dev-test", "ps", "kill", "close"]:
    assert op in text, "missing operation %s" % op
for required in ["_handle_dev_test", "queue dev test", "list_session_processes", "kill_session_process", "not_session_process", "PROCESS_REGISTER", "PROCESS_KILL"]:
    assert required in text, "missing process-scope guard %s" % required
for required in ['data.get("session_id")', 'data.get("auth_code")', 'op == "upload" and "multipart/form-data" in ctype']:
    assert required in text, "missing body-auth/direct-upload guard %s" % required
for forbidden in ['"/run"', "run_shell", "exec_shell", "command_endpoint", "generic_command"]:
    assert forbidden not in text, "forbidden generic execution surface: %s" % forbidden

# Only named handler methods may dispatch session operations.
handler_names = {n.name for n in ast.walk(module) if isinstance(n, ast.FunctionDef)}
for fn in ["_handle_upload", "_handle_test", "_handle_dev_test", "_handle_patch_function", "_handle_splice", "_handle_ps", "_handle_kill"]:
    assert fn in handler_names, "missing handler %s" % fn

print("PASS dev_remote_runner_json_contract_static")
