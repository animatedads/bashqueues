#!/usr/bin/env python3
"""Offline provider-family parity report for bashqueues.

This helper inspects repository docs, policies, fixtures and tests. It does not
call cloud provider APIs, require credentials, provision resources, or alter queue
state. It is intended as a governance/reporting tool for Bob2 provider-family
coverage.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

SCHEMA = "queuebash.provider_parity_report.v1"
POLICY_SCHEMA = "queuebash.provider_parity_report_policy.v1"

DEFAULT_FAMILIES: Dict[str, Dict[str, Any]] = {
    "aws": {
        "display_name": "AWS",
        "status": "first_tier_contract_coverage",
        "provider_dirs": ["providers.d/aws"],
        "docs": ["docs/AWS_PROVIDER_CONTRACTS.md"],
        "policies": ["policies.d/aws/default.env.example"],
        "fixtures": ["tests/fixtures/aws"],
        "tests": ["tests/aws_provider_contracts_static.sh", "tests/aws_provider_json_contract_static.py"],
    },
    "azure": {
        "display_name": "Azure",
        "status": "first_tier_contract_coverage",
        "provider_dirs": ["providers.d/azure"],
        "docs": ["docs/AZURE_PROVIDER_CONTRACTS.md"],
        "policies": ["policies.d/azure/default.env.example"],
        "fixtures": ["tests/fixtures/azure"],
        "tests": ["tests/azure_provider_contracts_static.sh", "tests/azure_provider_json_contract_static.py"],
    },
    "gcp": {
        "display_name": "GCP",
        "status": "first_tier_contract_coverage",
        "provider_dirs": ["providers.d/gcp"],
        "docs": ["docs/GCP_PROVIDER_CONTRACTS.md"],
        "policies": ["policies.d/gcp/default.env.example"],
        "fixtures": ["tests/fixtures/gcp"],
        "tests": ["tests/gcp_provider_contracts_static.sh", "tests/gcp_provider_json_contract_static.py"],
    },
    "oci": {
        "display_name": "OCI",
        "status": "high_standard_reference",
        "provider_dirs": ["providers.d/oci"],
        "docs": ["docs/OCI_PROVIDER_CONTRACTS.md", "docs/OCI_GOVERNANCE_PROVIDER.md"],
        "policies": ["policies.d/oci/default.env.example"],
        "fixtures": ["tests/fixtures/oci"],
        "tests": ["tests/oci_provider_contracts_static.sh", "tests/oci_provider_json_contract_static.py"],
    },
    "ibm": {
        "display_name": "IBM",
        "status": "high_standard_reference",
        "provider_dirs": ["providers.d/ibm"],
        "docs": ["docs/IBM_PROVIDER_CONTRACTS.md"],
        "policies": ["policies.d/ibm/identity.env", "policies.d/ibm/regions.tsv", "policies.d/finops/ibm.env.example"],
        "fixtures": ["tests/fixtures/ibm"],
        "tests": ["tests/ibm_provider_contracts_static.sh", "tests/ibm_provider_json_contract_static.py"],
    },
    "eu_sovereign": {
        "display_name": "EU sovereign",
        "status": "fixture_first_mapped_pending_validation",
        "provider_dirs": ["providers.d/eu_sovereign"],
        "docs": ["docs/EU_SOVEREIGN_PROVIDER_CONTRACTS.md"],
        "policies": ["policies.d/eu-sovereign/default.env.example"],
        "fixtures": ["tests/fixtures/eu_sovereign"],
        "tests": ["tests/eu_sovereign_provider_contracts_static.sh", "tests/eu_sovereign_provider_json_contract_static.py"],
    },
    "apac_china": {
        "display_name": "APAC/China",
        "status": "fixture_first_mapped_pending_validation",
        "provider_dirs": ["providers.d/apac_china"],
        "docs": ["docs/APAC_CHINA_PROVIDER_CONTRACTS.md"],
        "policies": ["policies.d/apac-china/default.env.example"],
        "fixtures": ["tests/fixtures/apac_china"],
        "tests": ["tests/apac_china_provider_contracts_static.sh", "tests/apac_china_provider_json_contract_static.py"],
    },
    "gpu_cloud": {
        "display_name": "GPU cloud",
        "status": "fixture_first_mapped_pending_validation",
        "provider_dirs": ["providers.d/gpu_cloud"],
        "docs": ["docs/GPU_CLOUD_PROVIDER_CONTRACTS.md"],
        "policies": ["policies.d/gpu-cloud/default.env.example"],
        "fixtures": ["tests/fixtures/gpu_cloud"],
        "tests": ["tests/gpu_cloud_provider_contracts_static.sh", "tests/gpu_cloud_provider_json_contract_static.py"],
    },
    "edge_cloud": {
        "display_name": "Edge cloud",
        "status": "fixture_first_mapped_pending_validation",
        "provider_dirs": ["providers.d/edge_cloud"],
        "docs": ["docs/EDGE_CLOUD_PROVIDER_CONTRACTS.md"],
        "policies": ["policies.d/edge-cloud/default.env.example"],
        "fixtures": ["tests/fixtures/edge_cloud"],
        "tests": ["tests/edge_cloud_provider_contracts_static.sh", "tests/edge_cloud_provider_json_contract_static.py"],
    },
    "hybrid_onprem": {
        "display_name": "Hybrid/on-prem",
        "status": "fixture_first_mapped_pending_validation",
        "provider_dirs": ["providers.d/hybrid_onprem"],
        "docs": ["docs/HYBRID_ONPREM_PROVIDER_CONTRACTS.md"],
        "policies": ["policies.d/hybrid-onprem/default.env.example"],
        "fixtures": ["tests/fixtures/hybrid_onprem"],
        "tests": ["tests/hybrid_onprem_provider_contracts_static.sh", "tests/hybrid_onprem_provider_json_contract_static.py"],
    },
}

REQUIRED_BUCKETS = ("docs", "provider_dirs", "policies", "fixtures", "tests")


def load_json(path: Path) -> Optional[Dict[str, Any]]:
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def load_policy(root: Path, policy_path: Optional[str]) -> Dict[str, Any]:
    if policy_path:
        candidate = Path(policy_path)
        if not candidate.is_absolute():
            candidate = root / candidate
    else:
        candidate = root / "policies.d" / "cloud-resource" / "provider-parity-report.json"
    data = load_json(candidate)
    if not data:
        return {"schema": POLICY_SCHEMA, "families": DEFAULT_FAMILIES}
    families = data.get("families")
    if not isinstance(families, dict):
        raise SystemExit(f"provider parity policy has no families object: {candidate}")
    return data


def exists_any(root: Path, paths: Iterable[str]) -> bool:
    return any((root / p).exists() for p in paths)


def count_files(root: Path, path: str) -> int:
    p = root / path
    if p.is_file():
        return 1
    if p.is_dir():
        return sum(1 for child in p.rglob("*") if child.is_file())
    return 0


def summarize_family(root: Path, family_id: str, spec: Dict[str, Any]) -> Dict[str, Any]:
    buckets: Dict[str, Dict[str, Any]] = {}
    missing: List[str] = []
    present_count = 0
    total_count = 0
    for bucket in REQUIRED_BUCKETS:
        paths = [str(x) for x in spec.get(bucket, [])]
        bucket_present = exists_any(root, paths)
        files = sum(count_files(root, path) for path in paths)
        buckets[bucket] = {"present": bucket_present, "paths": paths, "file_count": files}
        total_count += 1
        if bucket_present:
            present_count += 1
        else:
            missing.append(bucket)
    complete = not missing
    decision = "allow" if complete else "deny"
    reason = "coverage_artifacts_present" if complete else "missing_coverage_artifacts"
    return {
        "id": family_id,
        "display_name": spec.get("display_name", family_id),
        "status": spec.get("status", "mapped_pending_validation"),
        "decision": decision,
        "reason": reason,
        "complete": complete,
        "coverage_score": present_count / total_count if total_count else 0.0,
        "missing_buckets": missing,
        "buckets": buckets,
        "notes": spec.get("notes", ""),
    }


def build_report(root: Path, policy_path: Optional[str], only_family: Optional[str]) -> Dict[str, Any]:
    policy = load_policy(root, policy_path)
    families = policy.get("families", DEFAULT_FAMILIES)
    if only_family:
        if only_family not in families:
            raise SystemExit(f"unknown provider family: {only_family}")
        families = {only_family: families[only_family]}
    rows = [summarize_family(root, fid, spec) for fid, spec in sorted(families.items())]
    complete = [r for r in rows if r["complete"]]
    incomplete = [r for r in rows if not r["complete"]]
    return {
        "schema": SCHEMA,
        "provider": "provider_parity_report",
        "root": str(root),
        "policy_schema": policy.get("schema", POLICY_SCHEMA),
        "live_api_calls": False,
        "credentials_required": False,
        "cloud_mutation": False,
        "queue_dispatch_refactor": False,
        "summary": {
            "families_total": len(rows),
            "families_complete": len(complete),
            "families_incomplete": len(incomplete),
            "verdict": "complete" if not incomplete else "incomplete",
        },
        "families": rows,
    }


def print_human(report: Dict[str, Any]) -> None:
    summary = report["summary"]
    print("Provider parity report")
    print("======================")
    print(f"families: {summary['families_complete']}/{summary['families_total']} complete")
    print(f"verdict:  {summary['verdict']}")
    print("live API calls: false")
    print("credentials required: false")
    print("")
    print(f"{'family':<18} {'status':<42} {'score':<6} missing")
    print("-" * 90)
    for row in report["families"]:
        score = f"{int(row['coverage_score'] * 100)}%"
        missing = ",".join(row["missing_buckets"]) or "-"
        print(f"{row['id']:<18} {row['status']:<42} {score:<6} {missing}")


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Generate an offline provider-family parity report.")
    parser.add_argument("--root", default=".", help="Repository root to inspect")
    parser.add_argument("--policy", help="Optional provider parity report policy JSON")
    parser.add_argument("--family", help="Report one provider family id")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of human summary")
    parser.add_argument("--fail-on-missing", action="store_true", help="Exit non-zero if any family is incomplete")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    report = build_report(root, args.policy, args.family)
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print_human(report)
    if args.fail_on_missing and report["summary"]["families_incomplete"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
