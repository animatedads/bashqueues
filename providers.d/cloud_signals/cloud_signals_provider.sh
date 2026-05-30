#!/usr/bin/env bash
# bashqueues cloud cost and service availability signals provider
# Fixture-first provider. No live cloud API calls, no credentials, no billing access.
set -euo pipefail

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_repo_root="$(cd "$_self_dir/../.." && pwd)"
_python="${QUEUEBASH_PYTHON:-/usr/bin/python3}"
_policy="${QUEUEBASH_CLOUD_SIGNALS_POLICY:-$_repo_root/policies.d/cloud-signals/service-availability.example.json}"
_cost_catalog="${QUEUEBASH_CLOUD_SIGNALS_COST_CATALOG:-$_repo_root/policies.d/cloud-signals/cost-catalog.example.json}"

case "${1:-help}" in
  help|-h|--help)
    cat <<'USAGE'
Usage:
  cloud_signals_provider.sh platforms [--json] [--policy FILE] [--cost-catalog FILE]
  cloud_signals_provider.sh availability-check --provider NAME --region REGION --service SERVICE [--json] [--policy FILE]
  cloud_signals_provider.sh cost-check --provider NAME --region REGION --service SERVICE --estimated-hourly-usd N [--monthly-budget-usd N] [--json] [--cost-catalog FILE]
  cloud_signals_provider.sh explain --provider NAME --region REGION --service SERVICE [--estimated-hourly-usd N] [--monthly-budget-usd N] [--json] [--policy FILE] [--cost-catalog FILE]
  cloud_signals_provider.sh self-test [--json]

This provider is a fixture-first wiring layer for cost and service availability
signals. It reads local JSON policy/catalog files and emits normalized evidence.
It does not call cloud APIs, read credentials, query billing, provision resources,
or change queue dispatch behaviour.
USAGE
    exit 0
    ;;
esac

cmd="$1"; shift || true
"$_python" - "$cmd" "$_policy" "$_cost_catalog" "$@" <<'PY'
from __future__ import annotations
import argparse, json, sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

SCHEMA_PLATFORMS = "queuebash.cloud_signals.platforms.v1"
SCHEMA_AVAILABILITY = "queuebash.cloud_signals.availability.v1"
SCHEMA_COST = "queuebash.cloud_signals.cost.v1"
SCHEMA_EXPLAIN = "queuebash.cloud_signals.explain.v1"

cmd = sys.argv[1]
default_policy = sys.argv[2]
default_cost_catalog = sys.argv[3]
argv = sys.argv[4:]

MAJOR_PROVIDERS = ["oci", "aws", "azure", "gcp", "ibm"]
HOURS_PER_MONTH = 730.0


def emit(obj: Dict[str, Any], code: int = 0, json_out: bool = True) -> None:
    if json_out:
        print(json.dumps(obj, sort_keys=True, separators=(",", ":")))
    else:
        print(obj.get("decision") or obj.get("status") or json.dumps(obj, sort_keys=True))
    raise SystemExit(code)


def load_json(path: str, default: Dict[str, Any]) -> Dict[str, Any]:
    p = Path(path)
    if not p.exists():
        return default
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"ERROR: invalid JSON in {path}: {exc}")


def parser_common() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument("--json", action="store_true", dest="json_out")
    p.add_argument("--policy", default=default_policy)
    p.add_argument("--cost-catalog", default=default_cost_catalog)
    return p


def check_provider(name: str) -> None:
    if name not in MAJOR_PROVIDERS:
        raise SystemExit(f"ERROR: unsupported major provider for this wiring contract: {name}")


def availability_lookup(policy: Dict[str, Any], provider: str, region: str, service: str) -> Dict[str, Any]:
    check_provider(provider)
    platforms = policy.get("platforms", {})
    pdoc = platforms.get(provider, {})
    rdoc = (pdoc.get("regions", {}) or {}).get(region)
    if not rdoc:
        return {
            "schema": SCHEMA_AVAILABILITY,
            "decision": "review",
            "provider": provider,
            "region": region,
            "service": service,
            "status": "unknown",
            "reason": "region_not_mapped_in_local_policy",
            "live": False,
            "source": "local_policy",
        }
    sdoc = (rdoc.get("services", {}) or {}).get(service)
    if not sdoc:
        return {
            "schema": SCHEMA_AVAILABILITY,
            "decision": "review",
            "provider": provider,
            "region": region,
            "service": service,
            "status": "unknown",
            "reason": "service_not_mapped_in_local_policy",
            "live": False,
            "source": "local_policy",
        }
    status = str(sdoc.get("status", "unknown"))
    if status == "available":
        decision, reason = "allow", "service_available_in_local_policy"
    elif status == "limited":
        decision, reason = "review", "service_limited_in_local_policy"
    elif status in ("unavailable", "disabled"):
        decision, reason = "deny", "service_unavailable_in_local_policy"
    else:
        decision, reason = "review", "service_status_unknown"
    return {
        "schema": SCHEMA_AVAILABILITY,
        "decision": decision,
        "provider": provider,
        "region": region,
        "service": service,
        "status": status,
        "reason": reason,
        "compliance": rdoc.get("compliance", []),
        "notes": sdoc.get("notes", ""),
        "evidence": sdoc.get("evidence", {}),
        "live": False,
        "source": "local_policy",
    }


def cost_lookup(catalog: Dict[str, Any], provider: str, region: str, service: str, hourly: float, monthly_budget: float | None) -> Dict[str, Any]:
    check_provider(provider)
    platforms = catalog.get("platforms", {})
    pdoc = platforms.get(provider, {})
    service_doc = (pdoc.get("services", {}) or {}).get(service, {})
    default_doc = (catalog.get("defaults", {}) or {}).get(service, {})
    max_hourly = service_doc.get("max_hourly_usd", default_doc.get("max_hourly_usd"))
    monthly_estimate = round(float(hourly) * HOURS_PER_MONTH, 4)
    if monthly_budget is None:
        monthly_budget = service_doc.get("monthly_budget_usd", pdoc.get("monthly_budget_usd", catalog.get("default_monthly_budget_usd", 0)))
    monthly_budget = float(monthly_budget or 0)
    gates: List[Dict[str, Any]] = []
    decision = "allow"
    reason = "cost_within_local_policy"
    if max_hourly is not None:
        if hourly > float(max_hourly):
            gates.append({"name": "hourly_cost_ceiling", "decision": "deny", "estimated_hourly_usd": hourly, "ceiling": float(max_hourly)})
            decision, reason = "deny", "hourly_cost_ceiling_breach"
        else:
            gates.append({"name": "hourly_cost_ceiling", "decision": "allow", "estimated_hourly_usd": hourly, "ceiling": float(max_hourly)})
    else:
        gates.append({"name": "hourly_cost_ceiling", "decision": "review", "reason": "no_hourly_ceiling_in_local_policy"})
        if decision == "allow":
            decision, reason = "review", "cost_policy_incomplete"
    if monthly_budget:
        if monthly_estimate > monthly_budget:
            gates.append({"name": "monthly_budget", "decision": "deny", "estimated_monthly_usd": monthly_estimate, "budget": monthly_budget})
            decision, reason = "deny", "monthly_budget_breach"
        else:
            gates.append({"name": "monthly_budget", "decision": "allow", "estimated_monthly_usd": monthly_estimate, "budget": monthly_budget})
    else:
        gates.append({"name": "monthly_budget", "decision": "review", "reason": "no_monthly_budget_in_local_policy"})
        if decision == "allow":
            decision, reason = "review", "cost_policy_incomplete"
    return {
        "schema": SCHEMA_COST,
        "decision": decision,
        "reason": reason,
        "provider": provider,
        "region": region,
        "service": service,
        "estimated_hourly_usd": hourly,
        "estimated_monthly_usd": monthly_estimate,
        "monthly_budget_usd": monthly_budget,
        "gates": gates,
        "currency": "USD",
        "live": False,
        "source": "local_cost_catalog",
    }


def cmd_platforms(args: List[str]) -> None:
    p = parser_common(); ns = p.parse_args(args)
    policy = load_json(ns.policy, {"platforms": {}})
    catalog = load_json(ns.cost_catalog, {"platforms": {}})
    platforms = []
    for provider in MAJOR_PROVIDERS:
        pdoc = (policy.get("platforms", {}) or {}).get(provider, {})
        cdoc = (catalog.get("platforms", {}) or {}).get(provider, {})
        regions = sorted((pdoc.get("regions", {}) or {}).keys())
        services = sorted({s for r in (pdoc.get("regions", {}) or {}).values() for s in (r.get("services", {}) or {}).keys()} | set((cdoc.get("services", {}) or {}).keys()))
        platforms.append({"provider": provider, "regions": regions, "services": services, "cost_policy": bool(cdoc), "availability_policy": bool(pdoc)})
    emit({"schema": SCHEMA_PLATFORMS, "status": "ok", "platforms": platforms, "live": False}, json_out=ns.json_out)


def parse_check_args(args: List[str]) -> argparse.Namespace:
    p = parser_common()
    p.add_argument("--provider", required=True)
    p.add_argument("--region", required=True)
    p.add_argument("--service", required=True)
    p.add_argument("--estimated-hourly-usd", type=float, default=None)
    p.add_argument("--monthly-budget-usd", type=float, default=None)
    return p.parse_args(args)


def cmd_availability(args: List[str]) -> None:
    ns = parse_check_args(args)
    policy = load_json(ns.policy, {"platforms": {}})
    emit(availability_lookup(policy, ns.provider, ns.region, ns.service), code=0, json_out=ns.json_out)


def cmd_cost(args: List[str]) -> None:
    ns = parse_check_args(args)
    if ns.estimated_hourly_usd is None:
        emit({"schema": SCHEMA_COST, "decision": "review", "reason": "missing_estimated_hourly_usd", "mutated": False, "live": False}, code=0, json_out=ns.json_out)
    catalog = load_json(ns.cost_catalog, {"platforms": {}})
    emit(cost_lookup(catalog, ns.provider, ns.region, ns.service, ns.estimated_hourly_usd, ns.monthly_budget_usd), code=0, json_out=ns.json_out)


def cmd_explain(args: List[str]) -> None:
    ns = parse_check_args(args)
    policy = load_json(ns.policy, {"platforms": {}})
    catalog = load_json(ns.cost_catalog, {"platforms": {}})
    availability = availability_lookup(policy, ns.provider, ns.region, ns.service)
    cost = None
    if ns.estimated_hourly_usd is not None:
        cost = cost_lookup(catalog, ns.provider, ns.region, ns.service, ns.estimated_hourly_usd, ns.monthly_budget_usd)
    decisions = [availability.get("decision")]
    if cost:
        decisions.append(cost.get("decision"))
    if "deny" in decisions:
        decision = "deny"
    elif "review" in decisions:
        decision = "review"
    else:
        decision = "allow"
    emit({"schema": SCHEMA_EXPLAIN, "decision": decision, "provider": ns.provider, "region": ns.region, "service": ns.service, "availability": availability, "cost": cost, "live": False, "mutated": False}, code=0, json_out=ns.json_out)


def cmd_self_test(args: List[str]) -> None:
    p = parser_common(); ns = p.parse_args(args)
    policy = load_json(ns.policy, {"platforms": {}})
    catalog = load_json(ns.cost_catalog, {"platforms": {}})
    checks = []
    for provider in MAJOR_PROVIDERS:
        pdoc = (policy.get("platforms", {}) or {}).get(provider, {})
        cdoc = (catalog.get("platforms", {}) or {}).get(provider, {})
        checks.append({"provider": provider, "availability_policy": bool(pdoc), "cost_policy": bool(cdoc)})
    ok = all(c["availability_policy"] and c["cost_policy"] for c in checks)
    emit({"schema": "queuebash.cloud_signals.self_test.v1", "status": "ok" if ok else "incomplete", "checks": checks, "live": False, "mutated": False}, code=0 if ok else 1, json_out=ns.json_out)


if cmd in ("platforms", "list-platforms"):
    cmd_platforms(argv)
elif cmd in ("availability-check", "availability"):
    cmd_availability(argv)
elif cmd in ("cost-check", "cost"):
    cmd_cost(argv)
elif cmd == "explain":
    cmd_explain(argv)
elif cmd == "self-test":
    cmd_self_test(argv)
else:
    raise SystemExit(f"Usage error: unknown cloud signals command: {cmd}")
PY
