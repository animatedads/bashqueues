#!/usr/bin/env python3
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
registry = ROOT / "tests" / "fixtures" / "cloud_infra" / "registry.json"
cmd = [str(ROOT / "providers.d" / "cloud_infra" / "cloud_infra.sh")]

def run(*args):
    out = subprocess.check_output(cmd + list(args), cwd=ROOT, env={
        "QUEUEBASH_CLOUD_INFRA_REGISTRY": str(registry),
        "QUEUEBASH_CLOUD_INFRA_LIVE": "0",
        "PATH": "/usr/bin:/bin",
    }, text=True)
    return json.loads(out)

lst = run("list")
assert lst["schema"] == "queuebash.cloud_infra.list.v1"
assert lst["registry_checked"] is True
assert isinstance(lst["services"], list)
assert {"id", "provider", "helper", "enabled", "allowed_actions", "region"}.issubset(lst["services"][0])

plan = run("plan", "oci-free-london", "start")
required = {"schema", "provider", "helper", "service_id", "action", "decision", "reason", "registry_checked", "live", "mutated", "fail_closed"}
assert required.issubset(plan), sorted(required - set(plan))
assert plan["schema"] == "queuebash.cloud_infra.action.v1"
assert plan["provider"] == "oci"
assert plan["decision"] == "dry_run"
assert plan["live"] is False
assert plan["mutated"] is False
assert plan["registry_checked"] is True
assert plan["legal"]["sovereignty"] == "uk"

start = run("start", "oci-free-london")
assert start["schema"] == "queuebash.cloud_infra.action.v1"
assert start["decision"] == "dry_run"
assert start["fail_closed"] is False

print("cloud_infra_json_contract_static: PASS")
