#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
schema_path = root / "schemas" / "queue.control_plan.v1.schema.json"
schema = json.loads(schema_path.read_text())
assert schema["properties"]["schema"]["const"] == "queue.control_plan.v1"
for key in ["source", "plan", "analysis"]:
    assert key in schema["required"], key
plan_props = schema["properties"]["plan"]["properties"]
for key in ["classes", "restrictions", "assets", "gateways", "identities", "secrets", "job_templates", "workflows", "dependencies", "approval_gates"]:
    assert key in plan_props, key
analysis_props = schema["properties"]["analysis"]["properties"]
for key in ["warnings", "unsupported", "needs_review", "unsafe_refused", "safe_to_stage", "safe_to_apply"]:
    assert key in analysis_props, key
