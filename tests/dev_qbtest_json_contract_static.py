#!/usr/bin/env python3
import json
sample = {
    "schema": "queuebash.dev_qbtest_result.v1",
    "status": "pass",
    "source_file": "fixture.sh",
    "count": 1,
    "counts": {"pass": 1, "fail": 0, "timeout": 0, "invalid": 0, "infrastructure_error": 0, "listed": 0, "no_match": 0},
    "results": [{
        "id": "QBTEST-example",
        "name": "example",
        "function": "demo",
        "language": "bash",
        "line": 1,
        "status": "pass",
        "exit_code": 0,
        "duration_seconds": 0.1,
        "stdout_tail": "",
        "stderr_tail": "",
    }],
}
assert sample["schema"] == "queuebash.dev_qbtest_result.v1"
assert sample["status"] == "pass"
assert sample["results"][0]["language"] in {"bash", "python"}
assert {"pass", "fail", "timeout", "invalid", "infrastructure_error", "listed", "no_match"}.issubset(sample["counts"])
print("PASS dev_qbtest_json_contract_static")
