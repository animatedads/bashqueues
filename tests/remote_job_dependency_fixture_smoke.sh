#!/usr/bin/env bash
set -euo pipefail

export QUEUEBASH_REMOTE_DEPENDENCY_FIXTURE_DIR="tests/fixtures/remote_dependency"

python3 - <<'PYSMOKE'
import importlib.util
import json
from pathlib import Path

helper = Path("providers.d/remote_dependency/remote_dependency_fixture.py")
spec = importlib.util.spec_from_file_location("remote_dependency_fixture", helper)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
fixtures = mod.load_fixtures()

def resolve(job):
    req = {
        "schema": "queuebash.remote_dependency.request.v1",
        "local_qid": "local-test",
        "remote": {"service": "oracle-prod", "job": job, "required_state": "done"},
        "policy": {"freshness_seconds": 999999999, "timeout_seconds": 3600, "failure_policy": "block"},
    }
    result = mod.match_fixture(req, fixtures)
    assert result["schema"] == "queuebash.remote_dependency.v1", result
    assert result.get("redacted") is True, result
    return result

cases = {
    "nightly_export": ("satisfied", "allow"),
    "running_job": ("waiting", "block"),
    "denied_job": ("waiting", "block"),
    "bad_sig_job": ("waiting", "block"),
    "stale_job": ("waiting", "block"),
    "ambiguous_job": ("waiting", "block"),
    "unreachable_job": ("waiting", "block"),
    "failed_job": ("waiting", "block"),
}
for job, expected in cases.items():
    got = resolve(job)
    assert (got["status"], got["decision"]) == expected, (job, got)
assert resolve("denied_job")["checks"]["acl"] == "deny"
assert resolve("bad_sig_job")["checks"]["signature"] == "invalid"
assert resolve("stale_job")["checks"]["freshness"] == "stale"
assert resolve("ambiguous_job")["checks"]["ambiguity"] == "ambiguous"
print("remote dependency fixture cases passed")
PYSMOKE

if grep -R -E '(^|[^[:alnum:]_])(ssh|curl|wget|nc)([^[:alnum:]_]|$)' providers.d/remote_dependency >/dev/null; then
  echo "forbidden remote polling primitive found" >&2
  exit 1
fi

echo "remote job dependency fixture smoke checks passed"
