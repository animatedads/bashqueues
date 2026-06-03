#!/usr/bin/env python3
"""Fixture-only remote dependency resolver for bashqueues tests.

This helper resolves queuebash.remote_dependency.request.v1 against JSON fixtures.
It is intentionally read-only and performs no network, SSH, shell, or mutation.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
from pathlib import Path
from typing import Any, Dict, Iterable, List

RESULT_SCHEMA = "queuebash.remote_dependency.v1"
REQUEST_SCHEMA = "queuebash.remote_dependency.request.v1"


def utc_now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_time(value: str) -> _dt.datetime:
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    return _dt.datetime.fromisoformat(value)


def load_json_arg(value: str) -> Dict[str, Any]:
    path = Path(value)
    if path.exists():
        return json.loads(path.read_text())
    return json.loads(value)


def fixture_dirs() -> Iterable[Path]:
    env = os.environ.get("QUEUEBASH_REMOTE_DEPENDENCY_FIXTURE_DIR", "")
    if env:
        yield Path(env).resolve()
        return
    here = Path(__file__).resolve().parents[2]
    yield (here / "tests" / "fixtures" / "remote_dependency").resolve()
    yield (Path.cwd() / "tests" / "fixtures" / "remote_dependency").resolve()


def load_fixtures() -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    seen = set()
    for directory in fixture_dirs():
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.json")):
            path = path.resolve()
            if path in seen:
                continue
            seen.add(path)
            data = json.loads(path.read_text())
            if isinstance(data, dict) and data.get("schema") == RESULT_SCHEMA:
                rows.append(data)
            elif isinstance(data, dict) and isinstance(data.get("items"), list):
                rows.extend(x for x in data["items"] if isinstance(x, dict) and x.get("schema") == RESULT_SCHEMA)
    return rows


def base_result(request: Dict[str, Any]) -> Dict[str, Any]:
    remote = request.get("remote", {}) if isinstance(request.get("remote"), dict) else {}
    policy = request.get("policy", {}) if isinstance(request.get("policy"), dict) else {}
    return {
        "schema": RESULT_SCHEMA,
        "status": "waiting",
        "decision": "block",
        "local_qid": request.get("local_qid", ""),
        "provider": "fixture",
        "remote": {
            "service": remote.get("service", ""),
            "job": remote.get("job", ""),
            "required_state": remote.get("required_state", "done"),
            "observed_state": "unknown",
            "last_checked": utc_now(),
        },
        "checks": {
            "service_reachable": "unknown",
            "trusted_service": "unknown",
            "acl": "unknown",
            "signature": "unknown",
            "freshness": "unknown",
            "ambiguity": "unknown",
        },
        "policy": {
            "failure_policy": policy.get("failure_policy", "block"),
            "freshness_seconds": int(policy.get("freshness_seconds", 300)),
            "timeout_seconds": int(policy.get("timeout_seconds", 3600)),
        },
        "reason": "not_resolved",
        "next_action": "retry_later",
        "redacted": True,
    }


def match_fixture(request: Dict[str, Any], fixtures: List[Dict[str, Any]]) -> Dict[str, Any]:
    remote = request.get("remote", {}) if isinstance(request.get("remote"), dict) else {}
    service = remote.get("service")
    job = remote.get("job")
    required = remote.get("required_state", "done")
    matches = []
    for item in fixtures:
        iremote = item.get("remote", {}) if isinstance(item.get("remote"), dict) else {}
        if iremote.get("service") == service and iremote.get("job") == job and iremote.get("required_state", required) == required:
            matches.append(item)
    if not matches:
        result = base_result(request)
        result.update(reason="remote_status_not_found")
        result["checks"].update(service_reachable="unknown", trusted_service="unknown", acl="unknown", signature="unknown", freshness="unknown", ambiguity="missing")
        return result
    if len(matches) > 1:
        result = base_result(request)
        result.update(reason="ambiguous_remote_job", next_action="manual_review")
        result["checks"].update(service_reachable="yes", trusted_service="yes", acl="allow", signature="valid", freshness="fresh", ambiguity="ambiguous")
        return result
    result = json.loads(json.dumps(matches[0]))
    result.setdefault("schema", RESULT_SCHEMA)
    result.setdefault("provider", "fixture")
    result.setdefault("local_qid", request.get("local_qid", ""))
    result.setdefault("policy", base_result(request)["policy"])
    result.setdefault("redacted", True)
    return evaluate(result, request)


def evaluate(result: Dict[str, Any], request: Dict[str, Any]) -> Dict[str, Any]:
    remote = result.setdefault("remote", {})
    checks = result.setdefault("checks", {})
    policy = result.setdefault("policy", base_result(request)["policy"])
    required = remote.get("required_state", request.get("remote", {}).get("required_state", "done"))
    observed = remote.get("observed_state", "unknown")
    freshness_seconds = int(policy.get("freshness_seconds", request.get("policy", {}).get("freshness_seconds", 300)))
    blocking = []
    if checks.get("service_reachable") != "yes":
        blocking.append("service_unreachable")
    if checks.get("trusted_service") != "yes":
        blocking.append("untrusted_service")
    if checks.get("acl") != "allow":
        blocking.append("acl_denied")
    if checks.get("signature") != "valid":
        blocking.append("signature_invalid")
    if checks.get("ambiguity") != "unique":
        blocking.append("ambiguous_or_missing_remote_job")
    last_checked = remote.get("last_checked")
    try:
        age = (_dt.datetime.now(_dt.timezone.utc) - parse_time(str(last_checked))).total_seconds()
        checks["freshness"] = "fresh" if age <= freshness_seconds else "stale"
    except Exception:
        checks["freshness"] = "invalid"
    if checks.get("freshness") != "fresh":
        blocking.append("stale_remote_status")
    if observed != required:
        blocking.append("observed_state_mismatch")
    if not blocking:
        result.update(status="satisfied", decision="allow", reason="required_state_observed", next_action="release_local_job")
    else:
        fail_policy = policy.get("failure_policy", "block")
        hard_failure_states = {"failed", "cancelled", "deleted", "interrupted"}
        if observed in hard_failure_states and fail_policy == "fail":
            result.update(status="failed", decision="fail", reason="remote_job_failed", next_action="fail_local_job")
        else:
            result.update(status="waiting", decision="block", reason=blocking[0], next_action="retry_later")
    result["redacted"] = True
    return result


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["resolve", "explain"])
    ap.add_argument("request_json")
    ap.add_argument("--json", action="store_true")
    ns = ap.parse_args()
    request = load_json_arg(ns.request_json)
    if request.get("schema") != REQUEST_SCHEMA:
        raise SystemExit(f"expected {REQUEST_SCHEMA}")
    result = match_fixture(request, load_fixtures())
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0 if result.get("schema") == RESULT_SCHEMA else 1


if __name__ == "__main__":
    raise SystemExit(main())
