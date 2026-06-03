#!/usr/bin/env python3
import json
from pathlib import Path
required_result_keys = {"schema", "status", "decision", "remote", "checks", "policy", "reason", "next_action", "redacted"}
allowed_status = {"waiting", "satisfied", "failed"}
allowed_decision = {"block", "allow", "fail"}
for path in sorted(Path("schemas/remote_dependency").glob("*.json")) + sorted(Path("tests/fixtures/remote_dependency").glob("*.json")):
    data = json.loads(path.read_text())
    schema = data.get("schema")
    assert schema in {"queuebash.remote_dependency.request.v1", "queuebash.remote_dependency.v1"}, f"{path}: unexpected schema {schema}"
    if schema == "queuebash.remote_dependency.request.v1":
        assert "remote" in data and "policy" in data, f"{path}: request missing remote/policy"
        assert data["remote"].get("service"), f"{path}: request missing service"
        assert data["remote"].get("job"), f"{path}: request missing job"
        assert data["remote"].get("required_state"), f"{path}: request missing required_state"
    else:
        missing = required_result_keys - set(data)
        assert not missing, f"{path}: missing result keys {sorted(missing)}"
        assert data["status"] in allowed_status, f"{path}: invalid status"
        assert data["decision"] in allowed_decision, f"{path}: invalid decision"
        assert data["redacted"] is True, f"{path}: result must be redacted"
        for key in ["service", "job", "required_state", "observed_state", "last_checked"]:
            assert data["remote"].get(key), f"{path}: remote missing {key}"
        for key in ["service_reachable", "trusted_service", "acl", "signature", "freshness", "ambiguity"]:
            assert data["checks"].get(key), f"{path}: checks missing {key}"
        assert "secret" not in json.dumps(data).lower(), f"{path}: must not carry secret material"
print("remote job dependency JSON contract checks passed")
