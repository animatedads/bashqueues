#!/usr/bin/env python3
"""Guard Bob2/provider-family static tests against stale exact version pins.

This test does not change provider behaviour. It verifies that provider/static
tests cleaned by the Bob2 0.18.49/0.18.50 patch line keep a
three-digit-compatible QUEUEBASH_VERSION assertion, so future accepted patch bases do
not fail solely because the release minor advanced beyond two digits.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

TARGETS = [
    "tests/apac_china_provider_contracts_static.sh",
    "tests/edge_cloud_provider_contracts_static.sh",
    "tests/eu_sovereign_provider_contracts_static.sh",
    "tests/gpu_cloud_provider_contracts_static.sh",
    "tests/remote_queue_service_provider_contract_static.sh",
    "tests/aws_provider_contracts_static.sh",
    "tests/azure_provider_contracts_static.sh",
    "tests/cloud_resource_provider_contract_static.sh",
    "tests/remote_queue_command_static.sh",
    "tests/oci_governance_provider_contract_static.sh",
    "tests/hybrid_onprem_provider_contracts_static.sh",
    "tests/provider_family_consistency_static.sh",
    "tests/provider_explainability_standard_static.sh",
    "tests/provider_primary_source_validation_static.sh",
]

future_guard = re.compile(r"\[1-9\]\[0-9\]\[0-9\]")
exact_queue_version = re.compile(r"grep\s+-q\s+['\"]QUEUEBASH_VERSION=\\?\"0\.18\.\d+\\?\"")

for rel in TARGETS:
    path = ROOT / rel
    assert path.exists(), f"missing target static test: {rel}"
    text = path.read_text(encoding="utf-8")
    assert "QUEUEBASH_VERSION" in text, f"{rel} has no version guard to verify"
    assert future_guard.search(text), f"{rel} lacks future-compatible ([5-9][0-9]|[1-9][0-9][0-9]) guard"
    assert "grep -Eq" in text, f"{rel} should use grep -Eq for version compatibility"
    assert not exact_queue_version.search(text), f"{rel} still uses exact stale QUEUEBASH_VERSION grep"

print("PASS provider_static_version_pin_policy_static")
