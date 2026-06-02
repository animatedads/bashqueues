#!/usr/bin/env python3
"""Static JSON contract checks for IBM Cloud provider fixtures."""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIXTURE_DIR = os.path.join(ROOT, "tests", "fixtures", "ibm")

EXPECTED = {
    "detect.json": {
        "schema": "queuebash.ibm.detect.v1",
        "required_fields": ["schema", "provider", "detected", "account_id", "region",
                            "decision", "reason", "fail_closed"],
        "provider": "ibm",
        "detected": True,
    },
    "identity.json": {
        "schema": "queuebash.ibm.identity.v1",
        "required_fields": ["schema", "provider", "check", "auth_method",
                            "decision", "reason", "fail_closed"],
        "provider": "ibm",
        "fail_closed": True,
    },
    "region.json": {
        "schema": "queuebash.ibm.region.v1",
        "required_fields": ["schema", "provider", "check", "region",
                            "sovereignty_zone", "legal_frameworks",
                            "data_residency_decision", "decision", "fail_closed"],
        "provider": "ibm",
    },
    "resource.json": {
        "schema": "queuebash.ibm.resource.v1",
        "required_fields": ["schema", "provider", "check", "resource_id",
                            "state", "decision", "fail_closed"],
        "provider": "ibm",
    },
    "network.json": {
        "schema": "queuebash.ibm.network.v1",
        "required_fields": ["schema", "provider", "check", "vpc_id",
                            "private_endpoint_only", "decision", "fail_closed"],
        "provider": "ibm",
    },
    "finops.json": {
        "schema": "queuebash.ibm.finops.v1",
        "required_fields": ["schema", "provider", "check", "budget_remaining",
                            "anomaly_detected", "cache_age_seconds",
                            "decision", "fail_closed"],
        "provider": "ibm",
    },
    "legal.json": {
        "schema": "queuebash.ibm.legal.v1",
        "required_fields": ["schema", "provider", "check", "region",
                            "frameworks_applicable", "validation_status",
                            "decision", "fail_closed"],
        "provider": "ibm",
    },
}

FORBIDDEN_FIELDS = {"token", "api_key", "ibmcloud_api_key", "secret", "password",
                    "access_key", "par_url", "signed_url"}

failures = []

for filename, spec in EXPECTED.items():
    path = os.path.join(FIXTURE_DIR, filename)
    if not os.path.exists(path):
        failures.append(f"MISSING {filename}")
        continue
    with open(path, encoding="utf-8") as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            failures.append(f"INVALID JSON {filename}: {e}")
            continue

    if data.get("schema") != spec["schema"]:
        failures.append(f"{filename}: schema={data.get('schema')!r} want {spec['schema']!r}")
    if data.get("provider") != spec.get("provider", "ibm"):
        failures.append(f"{filename}: provider={data.get('provider')!r}")
    if "detected" in spec and data.get("detected") is not spec["detected"]:
        failures.append(f"{filename}: detected={data.get('detected')!r}")
    if "fail_closed" in spec and data.get("fail_closed") is not spec["fail_closed"]:
        failures.append(f"{filename}: fail_closed={data.get('fail_closed')!r}")

    for field in spec.get("required_fields", []):
        if field not in data:
            failures.append(f"{filename}: missing required field '{field}'")

    if "decision" in data and data["decision"] not in ("allow", "deny", "unknown", "available"):
        failures.append(f"{filename}: invalid decision={data['decision']!r}")

    for key in data:
        if key.lower() in FORBIDDEN_FIELDS:
            failures.append(f"{filename}: forbidden field '{key}' in output")

    if filename == "region.json":
        if not isinstance(data.get("legal_frameworks"), list):
            failures.append(f"{filename}: legal_frameworks must be a list")
    if filename == "finops.json":
        if not isinstance(data.get("anomaly_detected"), bool):
            failures.append(f"{filename}: anomaly_detected must be bool")

if failures:
    for f in failures:
        print(f"FAIL {f}", file=sys.stderr)
    sys.exit(1)

print("PASS ibm_provider_json_contract_static")
