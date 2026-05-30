#!/usr/bin/env bash
# bashqueues cloud provisioning contract provider
# Contract/dry-run only. No live cloud API calls, no provisioning, no destruction.
set -euo pipefail

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_repo_root="$(cd "$_self_dir/../.." && pwd)"
_python="${QUEUEBASH_PYTHON:-/usr/bin/python3}"
_templates="${QUEUEBASH_CLOUD_PROVISION_TEMPLATES:-$_repo_root/policies.d/cloud-provision/templates.example.json}"
_policy="${QUEUEBASH_CLOUD_PROVISION_APPROVAL_POLICY:-$_repo_root/policies.d/cloud-provision/approval-policy.example.json}"

case "${1:-help}" in
  help|-h|--help)
    cat <<'USAGE'
Usage:
  cloud_provision.sh templates [--json] [--templates FILE]
  cloud_provision.sh plan TEMPLATE [--provider NAME] [--region REGION] [--class CLASS] [--classification LABEL] [--legal-framework NAME] [--workload KIND] [--estimated-cost N] [--json] [--templates FILE] [--policy FILE]
  cloud_provision.sh validate PLAN.json [--json] [--policy FILE]
  cloud_provision.sh explain PLAN.json|TEMPLATE [--json] [--templates FILE] [--policy FILE]
  cloud_provision.sh dry-run PLAN.json|TEMPLATE [--json] [--templates FILE] [--policy FILE]
  cloud_provision.sh lifecycle-plan PLAN.json|TEMPLATE [--action start|stop|status] [--json] [--templates FILE] [--policy FILE]
  cloud_provision.sh registry-preview PLAN.json|TEMPLATE [--json] [--templates FILE] [--policy FILE]
  cloud_provision.sh registry-handoff PLAN.json|TEMPLATE [--state planned|approved|provisioning|observed|claimable|retired|failed] [--registry DIR] [--json] [--templates FILE] [--policy FILE]
  cloud_provision.sh handoff-explain PLAN.json|TEMPLATE [--state planned|approved|provisioning|observed|claimable|retired|failed] [--json] [--templates FILE] [--policy FILE]
  cloud_provision.sh approval-request PLAN.json|TEMPLATE --change-ticket ID --reason TEXT --authority ROLE --audit-sink NAME [--data-protection-review] [--export-review] [--cost-approval] [--json] [--templates FILE] [--policy FILE]
  cloud_provision.sh live-gate PLAN.json|TEMPLATE --approval APPROVAL.json --live-enabled [--json] [--templates FILE] [--policy FILE]
  cloud_provision.sh self-test [--json]

This is a contract-first provisioning planner. It emits normalized JSON,
consults local policy/template files, and remains non-mutating. Provider
credentials and QUEUEBASH_CLOUD_INFRA_LIVE are intentionally ignored here;
future live apply must be implemented behind a separate explicit gate.
Approval and live-gate commands in this package are contract checks only; they do
not apply, provision, destroy, or call live cloud APIs.
Registry handoff writes only local cloud_resource records; it does not create,
start, stop, modify, or destroy provider resources.
USAGE
    exit 0
    ;;
esac

cmd="$1"; shift || true
export QUEUEBASH_CLOUD_INFRA_HELPER_DEFAULT="$_repo_root/providers.d/cloud_infra/cloud_infra.sh"
export QUEUEBASH_CLOUD_RESOURCE_PROVIDER_DEFAULT="$_repo_root/providers.d/cloud_resource/cloud_resource_provider.sh"
"$_python" - "$cmd" "$_templates" "$_policy" "$@" <<'PY'
import argparse, json, os, subprocess, sys, time, uuid
from pathlib import Path

SCHEMA_TEMPLATES = "queuebash.cloud_provision.templates.v1"
SCHEMA_PLAN = "queuebash.cloud_provision.plan.v1"
SCHEMA_DECISION = "queuebash.cloud_provision.decision.v1"
SCHEMA_EVENT = "queuebash.cloud_provision.event.v1"
SCHEMA_LIFECYCLE = "queuebash.cloud_provision.lifecycle_plan.v1"
SCHEMA_REGISTRY_PREVIEW = "queuebash.cloud_provision.registry_preview.v1"
SCHEMA_REGISTRY_HANDOFF = "queuebash.cloud_provision.registry_handoff.v1"
SCHEMA_HANDOFF_EXPLAIN = "queuebash.cloud_provision.handoff_explain.v1"
SCHEMA_APPROVAL = "queuebash.cloud_provision.approval_gate.v1"
SCHEMA_LIVE_GATE = "queuebash.cloud_provision.live_gate.v1"

cmd = sys.argv[1]
default_templates = sys.argv[2]
default_policy = sys.argv[3]
argv = sys.argv[4:]

ALLOWED_PROVIDERS = {"oci", "aws", "azure", "gcp", "ibm", "eu-sovereign", "apac-china", "gpu-cloud"}


def load_json(path, default):
    p = Path(path)
    if not p.exists():
        return default
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"ERROR: invalid JSON in {path}: {exc}")


def emit(obj, code=0, json_out=True):
    if json_out:
        print(json.dumps(obj, sort_keys=True))
    else:
        print(obj.get("decision") or obj.get("status") or json.dumps(obj, sort_keys=True))
    raise SystemExit(code)


def common_parser(add_template=True, add_policy=True):
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument("--json", action="store_true", dest="json_out")
    if add_template:
        p.add_argument("--templates", default=default_templates)
    if add_policy:
        p.add_argument("--policy", default=default_policy)
    return p


def template_items(doc):
    items = doc.get("templates", [])
    if isinstance(items, dict):
        items = list(items.values())
    return items


def find_template(doc, name):
    for item in template_items(doc):
        if item.get("name") == name or item.get("id") == name:
            return item
    return None


def policy_rules(doc):
    return doc.get("rules", {}) if isinstance(doc, dict) else {}


def as_list(v):
    if v is None:
        return []
    if isinstance(v, list):
        return v
    return [v]


def build_plan(template, ns, policy):
    provider = ns.provider or template.get("provider")
    region = ns.region or template.get("region")
    klass = ns.class_name or template.get("class") or template.get("queue_class")
    classification = ns.classification or template.get("classification") or template.get("data_classification")
    legal_framework = ns.legal_framework or template.get("legal_framework")
    workload = ns.workload or template.get("workload") or template.get("workload_type", "generic")
    cost_est = float(ns.estimated_cost if ns.estimated_cost is not None else template.get("estimated_monthly_cost", 0))
    gates = []
    rules = policy_rules(policy)
    allowed_regions = set(as_list(rules.get("allowed_regions", {}).get(provider)))
    denied_regions = set(as_list(rules.get("denied_regions", {}).get(provider)))
    allowed_legal = set(as_list(rules.get("allowed_legal_frameworks", {}).get(provider)))
    provider_cost = float((rules.get("monthly_cost_ceiling", {}) or {}).get(provider, rules.get("default_monthly_cost_ceiling", 0) or 0))
    template_live = bool(template.get("allow_live", False))
    mutation_requested = bool(template.get("mutation_requested", False))

    def gate(name, decision, reason, **extra):
        rec = {"name": name, "decision": decision, "reason": reason}
        rec.update(extra)
        gates.append(rec)

    if provider in ALLOWED_PROVIDERS:
        gate("provider_allowed", "allow", "provider_known")
    else:
        gate("provider_allowed", "deny", "provider_unknown")
    if region:
        if region in denied_regions:
            gate("region_allowed", "deny", "region_denied_by_policy", region=region)
        elif allowed_regions and region not in allowed_regions:
            gate("region_allowed", "deny", "region_not_in_allowlist", region=region)
        else:
            gate("region_allowed", "allow", "region_present", region=region)
    else:
        gate("region_allowed", "deny", "missing_region")
    if legal_framework:
        if allowed_legal and legal_framework not in allowed_legal:
            gate("legal_framework_allowed", "deny", "legal_framework_not_in_allowlist", legal_framework=legal_framework)
        else:
            gate("legal_framework_allowed", "allow", "legal_framework_present", legal_framework=legal_framework)
    else:
        gate("legal_framework_allowed", "deny", "missing_legal_framework")
    if classification:
        gate("data_classification", "allow", "classification_present", classification=classification)
    else:
        gate("data_classification", "review", "classification_missing")
    if "itar" in str(workload).lower() or "itar" in as_list(template.get("compliance")):
        if bool(template.get("itar_allowed", False)):
            gate("export_control", "allow", "itar_template_allowed")
        else:
            gate("export_control", "deny", "itar_workload_on_non_itar_template")
    else:
        gate("export_control", "allow", "no_itar_marker")
    if provider_cost and cost_est > provider_cost:
        gate("cost_ceiling", "deny", "cost_ceiling_breach", estimated_monthly_cost=cost_est, ceiling=provider_cost)
    else:
        gate("cost_ceiling", "allow", "cost_within_ceiling", estimated_monthly_cost=cost_est, ceiling=provider_cost)
    if template_live or mutation_requested:
        gate("live_mutation", "deny", "contract_package_is_plan_only")
    else:
        gate("live_mutation", "allow", "no_live_mutation_requested")
    gate("audit_evidence", "allow", "normalized_plan_is_audit_evidence")

    denies = [g for g in gates if g["decision"] == "deny"]
    reviews = [g for g in gates if g["decision"] == "review"]
    if denies:
        decision = "deny"
        reason = denies[0]["reason"]
    elif reviews:
        decision = "review"
        reason = reviews[0]["reason"]
    else:
        decision = "allow"
        reason = "provision_plan_passed_policy_gates"

    plan_id = f"cp-{int(time.time())}-{uuid.uuid4().hex[:8]}"
    cloud_infra_service = template.get("cloud_infra_service") or template.get("service_id") or template.get("cloud_service")
    resource_preview = {
        "schema": "queuebash.cloud_resource.v1",
        "resource_id": f"planned-{template.get('name', 'template')}-{uuid.uuid4().hex[:8]}",
        "provider": provider,
        "resource_type": template.get("resource_type", "vm"),
        "region": region,
        "lifecycle_state": "planned",
        "status": "planned",
        "capacity": template.get("capacity", {}),
        "labels": sorted(set(as_list(template.get("labels")) + ["planned", "cloud_provision"])),
        "compliance": as_list(template.get("compliance")),
        "allowed_classes": as_list(klass) if klass else [],
        "provenance": {"source": "cloud_provision", "template": template.get("name"), "cloud_infra_service": cloud_infra_service},
        "registry_handoff_state": "planned",
    }
    return {
        "schema": SCHEMA_PLAN,
        "plan_id": plan_id,
        "decision": decision,
        "reason": reason,
        "provider": provider,
        "operation": "plan",
        "template": template.get("name"),
        "resource_type": template.get("resource_type", "vm"),
        "region": region,
        "class": klass,
        "workload": workload,
        "data_protection": {
            "classification": classification,
            "legal_framework": legal_framework,
            "customer_data": bool(template.get("customer_data", False)),
        },
        "export_control": {"itar_allowed": bool(template.get("itar_allowed", False)), "workload": workload},
        "cost_estimate": {"estimated_monthly_cost": cost_est, "currency": template.get("currency", "USD")},
        "policy_gates": gates,
        "resource_record_preview": resource_preview,
        "cloud_infra_service": cloud_infra_service,
        "registry_handoff": {"mode": "preview-only", "state": "planned", "resource_schema": "queuebash.cloud_resource.v1"},
        "live_mutation": False,
        "mutated": False,
        "fail_closed": decision == "deny",
        "evidence": {"templates_source": ns.templates, "policy_source": ns.policy, "generated_epoch": int(time.time())},
    }


def load_plan_or_make(token, templates_path, policy_path, overrides=None):
    p = Path(token)
    if p.exists() and p.is_file():
        return load_json(str(p), {})
    templates = load_json(templates_path, {"templates": []})
    policy = load_json(policy_path, {"rules": {}})
    t = find_template(templates, token)
    if not t:
        emit({"schema": SCHEMA_DECISION, "decision": "deny", "reason": "template_not_found", "template": token, "fail_closed": True}, 4)
    ns = overrides or argparse.Namespace(provider=None, region=None, class_name=None, classification=None, legal_framework=None, workload=None, estimated_cost=None, templates=templates_path, policy=policy_path)
    return build_plan(t, ns, policy)


def _subprocess_json(args, timeout=15):
    try:
        cp = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout, check=False)
    except Exception as exc:
        return {"schema": "queuebash.cloud_provision.lifecycle_action.v1", "decision": "deny", "reason": "helper_call_failed", "error": str(exc), "mutated": False, "fail_closed": True}
    try:
        payload = json.loads(cp.stdout.strip() or "{}")
    except Exception:
        payload = {"schema": "queuebash.cloud_provision.lifecycle_action.v1", "decision": "deny", "reason": "helper_returned_non_json", "stdout": cp.stdout[-500:], "stderr": cp.stderr[-500:], "mutated": False, "fail_closed": True}
    payload.setdefault("returncode", cp.returncode)
    payload.setdefault("mutated", False)
    payload.setdefault("live", False)
    if cp.stderr:
        payload.setdefault("stderr_tail", cp.stderr[-500:])
    return payload


def lifecycle_for_plan(plan, action="start"):
    service = plan.get("cloud_infra_service") or (plan.get("resource_record_preview") or {}).get("provenance", {}).get("cloud_infra_service")
    if plan.get("decision") == "deny":
        return {"schema": SCHEMA_LIFECYCLE, "decision": "deny", "reason": "provision_plan_denied", "plan": plan, "cloud_infra_service": service, "cloud_infra_action": None, "live": False, "mutated": False, "fail_closed": True}
    if not service:
        return {"schema": SCHEMA_LIFECYCLE, "decision": "review", "reason": "missing_cloud_infra_service_mapping", "plan": plan, "cloud_infra_service": None, "cloud_infra_action": None, "live": False, "mutated": False, "fail_closed": False}
    helper = os.environ.get("QUEUEBASH_CLOUD_INFRA_HELPER") or os.environ.get("QUEUEBASH_CLOUD_INFRA_HELPER_DEFAULT") or "providers.d/cloud_infra/cloud_infra.sh"
    infra = _subprocess_json([helper, "plan", service, action])
    infra_decision = infra.get("decision")
    if infra.get("mutated") is True or infra.get("live") is True:
        decision, reason, fail_closed = "deny", "cloud_infra_reported_live_or_mutation", True
    elif infra_decision in ("dry_run", "allow"):
        decision, reason, fail_closed = "dry_run", "lifecycle_dry_run_ready", False
    elif infra_decision == "deny" and infra.get("reason") == "platform_helper_contract_placeholder_only":
        decision, reason, fail_closed = "review", "lifecycle_helper_contract_placeholder", False
    else:
        decision, reason, fail_closed = "review", infra.get("reason", "lifecycle_helper_review"), False
    return {"schema": SCHEMA_LIFECYCLE, "decision": decision, "reason": reason, "provider": plan.get("provider"), "template": plan.get("template"), "operation": "lifecycle-plan", "requested_action": action, "plan_id": plan.get("plan_id"), "cloud_infra_service": service, "cloud_infra_action": infra, "resource_record_preview": plan.get("resource_record_preview"), "live": False, "mutated": False, "fail_closed": fail_closed}



HANDOFF_STATES = {"planned", "approved", "provisioning", "observed", "claimable", "retired", "failed"}


def _resource_for_handoff(plan, state="planned"):
    if state not in HANDOFF_STATES:
        raise ValueError(f"unsupported handoff state: {state}")
    rr = dict(plan.get("resource_record_preview") or {})
    rr.setdefault("schema", "queuebash.cloud_resource.v1")
    rr.setdefault("provider", plan.get("provider"))
    rr.setdefault("resource_type", plan.get("resource_type", "vm"))
    rr.setdefault("region", plan.get("region"))
    rr.setdefault("capacity", {})
    rr.setdefault("labels", [])
    rr.setdefault("compliance", [])
    rr.setdefault("allowed_classes", [plan.get("class")] if plan.get("class") else [])
    rr.setdefault("provenance", {})
    rr["provenance"] = dict(rr.get("provenance") or {})
    rr["provenance"].update({
        "source": "cloud_provision",
        "cloud_provision_plan_id": plan.get("plan_id"),
        "cloud_provision_template": plan.get("template"),
        "handoff_mode": "registry-write",
        "cloud_mutation": False,
    })
    labels = set(as_list(rr.get("labels")))
    labels.update(["cloud_provision", f"handoff:{state}"])
    if state in {"planned", "approved", "provisioning"}:
        labels.add("not-claimable")
    if state == "claimable":
        labels.add("claimable")
    rr["labels"] = sorted(labels)
    rr["registry_handoff_state"] = state
    rr["claimable"] = state == "claimable"
    rr["last_seen_epoch"] = int(time.time())
    if state == "claimable":
        rr["lifecycle_state"] = "ready"
        rr["status"] = "available"
    elif state == "observed":
        rr["lifecycle_state"] = "observed"
        rr["status"] = "observed"
    elif state == "retired":
        rr["lifecycle_state"] = "retired"
        rr["status"] = "retired"
    elif state == "failed":
        rr["lifecycle_state"] = "failed"
        rr["status"] = "failed"
    else:
        rr["lifecycle_state"] = state
        rr["status"] = "planned"
    return rr


def explain_handoff_for_plan(plan, state="planned"):
    gates = []
    def gate(name, decision, reason):
        gates.append({"name": name, "decision": decision, "reason": reason})
    if plan.get("decision") == "deny":
        gate("plan_decision", "deny", plan.get("reason", "plan_denied"))
    elif plan.get("decision") in ("allow", "review"):
        gate("plan_decision", "allow", f"plan_{plan.get('decision')}_handoff_allowed")
    else:
        gate("plan_decision", "deny", "unknown_plan_decision")
    if state in HANDOFF_STATES:
        gate("handoff_state", "allow", "supported_handoff_state")
    else:
        gate("handoff_state", "deny", "unsupported_handoff_state")
    if state == "claimable":
        gate("claimable_state", "review", "claimable_records_are_allowed_only_by_explicit_state_request")
    else:
        gate("claimable_state", "allow", "non_claimable_default_handoff")
    gate("live_mutation", "allow", "registry_handoff_writes_local_registry_only")
    denies = [g for g in gates if g["decision"] == "deny"]
    reviews = [g for g in gates if g["decision"] == "review"]
    decision = "deny" if denies else ("review" if reviews else "allow")
    reason = (denies or reviews or [{"reason": "handoff_allowed"}])[0]["reason"]
    return {"schema": SCHEMA_HANDOFF_EXPLAIN, "decision": decision, "reason": reason, "plan_id": plan.get("plan_id"), "template": plan.get("template"), "provider": plan.get("provider"), "state": state, "gates": gates, "mutated": False, "live": False, "registry_write": False, "fail_closed": decision == "deny"}


def registry_handoff_for_plan(plan, state="planned", registry=None):
    exp = explain_handoff_for_plan(plan, state)
    if exp.get("decision") == "deny":
        return {"schema": SCHEMA_REGISTRY_HANDOFF, "decision": "deny", "reason": exp.get("reason"), "explain": exp, "registry_write": False, "mutated": False, "live": False, "fail_closed": True}
    rr = _resource_for_handoff(plan, state)
    helper = os.environ.get("QUEUEBASH_CLOUD_RESOURCE_PROVIDER") or os.environ.get("QUEUEBASH_CLOUD_RESOURCE_PROVIDER_DEFAULT") or "providers.d/cloud_resource/cloud_resource_provider.sh"
    import tempfile
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as tf:
        json.dump(rr, tf, sort_keys=True)
        tf.write("\n")
        tmpname = tf.name
    try:
        init_args = [helper, "init"]
        add_args = [helper, "add", "--file", tmpname, "--json"]
        if registry:
            init_args += ["--registry", registry]
            add_args += ["--registry", registry]
        init_payload = _subprocess_json(init_args)
        add_payload = _subprocess_json(add_args)
    finally:
        try:
            Path(tmpname).unlink()
        except OSError:
            pass
    ok = add_payload.get("decision") == "allow" or add_payload.get("status") in ("ok", "added") or add_payload.get("schema") == "queuebash.cloud_resource.v1"
    return {"schema": SCHEMA_REGISTRY_HANDOFF, "decision": "allow" if ok else "deny", "reason": "resource_record_handed_to_cloud_resource_registry" if ok else add_payload.get("reason", "resource_registry_handoff_failed"), "plan_id": plan.get("plan_id"), "template": plan.get("template"), "provider": plan.get("provider"), "state": state, "registry": registry or "default", "resource_record": rr, "cloud_resource_init": init_payload, "cloud_resource_add": add_payload, "registry_write": ok, "mutated": False, "live": False, "cloud_mutation": False, "fail_closed": not ok}

def registry_preview_for_plan(plan):
    rr = dict(plan.get("resource_record_preview") or {})
    rr.setdefault("schema", "queuebash.cloud_resource.v1")
    rr.setdefault("lifecycle_state", "planned")
    rr.setdefault("status", "planned")
    rr.setdefault("provenance", {})
    rr["provenance"] = dict(rr.get("provenance") or {})
    rr["provenance"].update({"cloud_provision_plan_id": plan.get("plan_id"), "cloud_provision_template": plan.get("template"), "handoff_mode": "preview-only"})
    return {"schema": SCHEMA_REGISTRY_PREVIEW, "decision": plan.get("decision"), "reason": "registry_handoff_preview", "plan_id": plan.get("plan_id"), "template": plan.get("template"), "provider": plan.get("provider"), "registry_write": False, "mutated": False, "live": False, "resource_record": rr, "fail_closed": plan.get("decision") == "deny"}


def approval_rules(doc):
    rules = policy_rules(doc)
    return rules.get("approval", {}) if isinstance(rules.get("approval", {}), dict) else {}


def live_gate_rules(doc):
    rules = policy_rules(doc)
    return rules.get("live_gate", {}) if isinstance(rules.get("live_gate", {}), dict) else {}


def approval_for_plan(plan, ns, policy):
    rules = approval_rules(policy)
    gates = []

    def gate(name, decision, reason, **extra):
        rec = {"name": name, "decision": decision, "reason": reason}
        rec.update(extra)
        gates.append(rec)

    plan_decision = plan.get("decision")
    if plan_decision == "deny":
        gate("plan_decision", "deny", plan.get("reason", "plan_denied"))
    else:
        gate("plan_decision", "allow", f"plan_{plan_decision or 'unknown'}_can_enter_approval")

    if rules.get("change_ticket_required", True) and not ns.change_ticket:
        gate("change_ticket", "deny", "missing_change_ticket")
    else:
        gate("change_ticket", "allow", "change_ticket_present", change_ticket=ns.change_ticket)

    if rules.get("reason_required", True) and (not ns.reason or len(ns.reason.strip()) < 8):
        gate("reason", "deny", "missing_or_short_reason")
    else:
        gate("reason", "allow", "reason_present")

    allowed_authorities = set(as_list(rules.get("allowed_authorities")))
    if allowed_authorities and ns.authority not in allowed_authorities:
        gate("authority", "deny", "authority_not_allowed", authority=ns.authority, allowed_authorities=sorted(allowed_authorities))
    elif not ns.authority:
        gate("authority", "deny", "missing_authority")
    else:
        gate("authority", "allow", "authority_allowed", authority=ns.authority)

    accepted_sinks = set(as_list(rules.get("accepted_audit_sinks")))
    if rules.get("audit_sink_required", True) and not ns.audit_sink:
        gate("audit_sink", "deny", "missing_audit_sink")
    elif accepted_sinks and ns.audit_sink not in accepted_sinks:
        gate("audit_sink", "deny", "audit_sink_not_allowed", audit_sink=ns.audit_sink, accepted_audit_sinks=sorted(accepted_sinks))
    else:
        gate("audit_sink", "allow", "audit_sink_present", audit_sink=ns.audit_sink)

    dp = plan.get("data_protection", {}) if isinstance(plan.get("data_protection"), dict) else {}
    customer_data = bool(dp.get("customer_data")) or str(dp.get("classification", "")).lower() in {"customer-data", "personal-data", "restricted"}
    if customer_data and rules.get("customer_data_requires_data_protection_review", True) and not ns.data_protection_review:
        gate("data_protection_review", "deny", "customer_data_requires_data_protection_review")
    else:
        gate("data_protection_review", "allow", "data_protection_review_satisfied" if customer_data else "not_customer_data")

    export = plan.get("export_control", {}) if isinstance(plan.get("export_control"), dict) else {}
    needs_export_review = "itar" in str(export.get("workload", "")).lower() or "ITAR" in str(dp.get("legal_framework", "")).upper()
    if needs_export_review and rules.get("export_control_requires_export_review", True) and not ns.export_review:
        gate("export_control_review", "deny", "export_control_requires_export_review")
    else:
        gate("export_control_review", "allow", "export_review_satisfied" if needs_export_review else "not_export_controlled")

    cost = plan.get("cost_estimate", {}) if isinstance(plan.get("cost_estimate"), dict) else {}
    threshold = float(rules.get("cost_approval_threshold", 0) or 0)
    estimated = float(cost.get("estimated_monthly_cost", 0) or 0)
    if threshold and estimated > threshold and not ns.cost_approval:
        gate("cost_approval", "deny", "cost_above_threshold_requires_approval", estimated_monthly_cost=estimated, threshold=threshold)
    else:
        gate("cost_approval", "allow", "cost_approval_satisfied", estimated_monthly_cost=estimated, threshold=threshold)

    gate("live_mutation", "allow", "approval_request_is_non_mutating")
    denies = [g for g in gates if g["decision"] == "deny"]
    reviews = [g for g in gates if g["decision"] == "review"]
    decision = "deny" if denies else ("review" if reviews else "allow")
    reason = (denies or reviews or [{"reason": "approval_gate_passed"}])[0]["reason"]
    return {
        "schema": SCHEMA_APPROVAL,
        "decision": decision,
        "reason": reason,
        "plan_id": plan.get("plan_id"),
        "template": plan.get("template"),
        "provider": plan.get("provider"),
        "change_ticket": ns.change_ticket,
        "authority": ns.authority,
        "audit_sink": ns.audit_sink,
        "gates": gates,
        "live": False,
        "mutated": False,
        "cloud_mutation": False,
        "fail_closed": decision == "deny",
    }


def live_gate_for_plan(plan, approval, ns, policy):
    rules = live_gate_rules(policy)
    gates = []

    def gate(name, decision, reason, **extra):
        rec = {"name": name, "decision": decision, "reason": reason}
        rec.update(extra)
        gates.append(rec)

    if rules.get("requires_explicit_live_enabled_flag", True) and not ns.live_enabled:
        gate("explicit_live_enabled", "deny", "missing_explicit_live_enabled_flag")
    else:
        gate("explicit_live_enabled", "allow", "explicit_live_enabled_flag_present")

    if plan.get("decision") == "deny":
        gate("plan_decision", "deny", plan.get("reason", "plan_denied"))
    else:
        gate("plan_decision", "allow", f"plan_{plan.get('decision')}_accepted_for_live_gate_review")

    if rules.get("requires_approval_decision_allow", True) and approval.get("decision") != "allow":
        gate("approval_decision", "deny", "approval_not_allow", approval_decision=approval.get("decision"))
    else:
        gate("approval_decision", "allow", "approval_allow")

    if rules.get("requires_template_allow_live", False) and not bool(plan.get("template_allow_live", False)):
        gate("template_live_allowlist", "deny", "template_not_live_allowlisted")
    else:
        gate("template_live_allowlist", "allow", "template_live_allowlist_not_required_in_contract_package")

    if rules.get("provider_credentials_are_not_authority", True):
        gate("provider_credentials", "allow", "provider_credentials_are_not_treated_as_authority")

    if rules.get("requires_queue_dispatch_isolation", True):
        gate("queue_dispatch_isolation", "allow", "live_gate_not_connected_to_queue_dispatch")

    if rules.get("contract_only", True) or not rules.get("live_apply_implemented", False):
        gate("live_apply_implementation", "review", "contract_only_no_live_apply_implemented")

    denies = [g for g in gates if g["decision"] == "deny"]
    reviews = [g for g in gates if g["decision"] == "review"]
    decision = "deny" if denies else ("review" if reviews else "allow")
    reason = (denies or reviews or [{"reason": "live_gate_passed"}])[0]["reason"]
    return {
        "schema": SCHEMA_LIVE_GATE,
        "decision": decision,
        "reason": reason,
        "plan_id": plan.get("plan_id"),
        "template": plan.get("template"),
        "provider": plan.get("provider"),
        "approval_decision": approval.get("decision"),
        "gates": gates,
        "live_apply_available": False,
        "live": False,
        "mutated": False,
        "cloud_mutation": False,
        "queue_dispatch_path": False,
        "fail_closed": decision == "deny",
    }


if cmd == "templates":
    p = common_parser(add_policy=False)
    ns = p.parse_args(argv)
    doc = load_json(ns.templates, {"schema": SCHEMA_TEMPLATES, "templates": []})
    out = {"schema": SCHEMA_TEMPLATES, "templates": template_items(doc), "template_count": len(template_items(doc)), "source": ns.templates}
    emit(out, json_out=True)

elif cmd == "plan":
    p = common_parser()
    p.add_argument("template")
    p.add_argument("--provider")
    p.add_argument("--region")
    p.add_argument("--class", dest="class_name")
    p.add_argument("--classification")
    p.add_argument("--legal-framework", dest="legal_framework")
    p.add_argument("--workload")
    p.add_argument("--estimated-cost", type=float, dest="estimated_cost")
    ns = p.parse_args(argv)
    templates = load_json(ns.templates, {"templates": []})
    policy = load_json(ns.policy, {"rules": {}})
    t = find_template(templates, ns.template)
    if not t:
        emit({"schema": SCHEMA_PLAN, "decision": "deny", "reason": "template_not_found", "template": ns.template, "fail_closed": True}, 4)
    emit(build_plan(t, ns, policy), code=0 if True else 1)

elif cmd == "validate":
    p = common_parser(add_template=False)
    p.add_argument("plan")
    ns = p.parse_args(argv)
    plan = load_json(ns.plan, {})
    gates = plan.get("policy_gates", [])
    denies = [g for g in gates if g.get("decision") == "deny"]
    reviews = [g for g in gates if g.get("decision") == "review"]
    decision = "deny" if denies else ("review" if reviews else "allow")
    emit({"schema": SCHEMA_DECISION, "decision": decision, "reason": (denies or reviews or [{"reason":"plan_valid"}])[0].get("reason"), "plan_id": plan.get("plan_id"), "fail_closed": decision == "deny", "mutated": False})

elif cmd in ("explain", "dry-run"):
    p = common_parser()
    p.add_argument("plan_or_template")
    ns = p.parse_args(argv)
    plan = load_plan_or_make(ns.plan_or_template, ns.templates, ns.policy)
    if cmd == "dry-run":
        emit({"schema": SCHEMA_DECISION, "decision": "dry_run" if plan.get("decision") in ("allow", "review") else "deny", "reason": "dry_run_no_mutation" if plan.get("decision") in ("allow", "review") else plan.get("reason"), "plan": plan, "live": False, "mutated": False, "fail_closed": plan.get("decision") == "deny"}, code=0 if plan.get("decision") in ("allow", "review") else 4)
    else:
        emit({"schema": SCHEMA_DECISION, "decision": plan.get("decision"), "reason": plan.get("reason"), "plan": plan, "explanation": "cloud_provision is contract/dry-run only; it validates provider, region, legal/data-protection, export-control, cost, and mutation gates before any future lifecycle helper handoff.", "mutated": False, "fail_closed": plan.get("decision") == "deny"}, code=0)

elif cmd == "lifecycle-plan":
    p = common_parser()
    p.add_argument("plan_or_template")
    p.add_argument("--action", choices=["start", "stop", "status"], default="start")
    ns = p.parse_args(argv)
    plan = load_plan_or_make(ns.plan_or_template, ns.templates, ns.policy)
    emit(lifecycle_for_plan(plan, ns.action), code=0 if plan.get("decision") != "deny" else 4)

elif cmd == "registry-preview":
    p = common_parser()
    p.add_argument("plan_or_template")
    ns = p.parse_args(argv)
    plan = load_plan_or_make(ns.plan_or_template, ns.templates, ns.policy)
    emit(registry_preview_for_plan(plan), code=0 if plan.get("decision") != "deny" else 4)

elif cmd == "handoff-explain":
    p = common_parser()
    p.add_argument("plan_or_template")
    p.add_argument("--state", choices=sorted(HANDOFF_STATES), default="planned")
    ns = p.parse_args(argv)
    plan = load_plan_or_make(ns.plan_or_template, ns.templates, ns.policy)
    out = explain_handoff_for_plan(plan, ns.state)
    emit(out, code=0 if out.get("decision") != "deny" else 4)

elif cmd == "registry-handoff":
    p = common_parser()
    p.add_argument("plan_or_template")
    p.add_argument("--state", choices=sorted(HANDOFF_STATES), default="planned")
    p.add_argument("--registry")
    ns = p.parse_args(argv)
    plan = load_plan_or_make(ns.plan_or_template, ns.templates, ns.policy)
    out = registry_handoff_for_plan(plan, ns.state, ns.registry)
    emit(out, code=0 if out.get("decision") == "allow" else 4)


elif cmd == "approval-request":
    p = common_parser()
    p.add_argument("plan_or_template")
    p.add_argument("--change-ticket", dest="change_ticket")
    p.add_argument("--reason")
    p.add_argument("--authority")
    p.add_argument("--audit-sink", dest="audit_sink")
    p.add_argument("--data-protection-review", action="store_true", dest="data_protection_review")
    p.add_argument("--export-review", action="store_true", dest="export_review")
    p.add_argument("--cost-approval", action="store_true", dest="cost_approval")
    ns = p.parse_args(argv)
    policy = load_json(ns.policy, {"rules": {}})
    plan = load_plan_or_make(ns.plan_or_template, ns.templates, ns.policy)
    out = approval_for_plan(plan, ns, policy)
    emit(out, code=0 if out.get("decision") == "allow" else 4)

elif cmd == "live-gate":
    p = common_parser()
    p.add_argument("plan_or_template")
    p.add_argument("--approval", required=True)
    p.add_argument("--live-enabled", action="store_true", dest="live_enabled")
    ns = p.parse_args(argv)
    policy = load_json(ns.policy, {"rules": {}})
    plan = load_plan_or_make(ns.plan_or_template, ns.templates, ns.policy)
    approval = load_json(ns.approval, {})
    out = live_gate_for_plan(plan, approval, ns, policy)
    emit(out, code=0 if out.get("decision") in ("allow", "review") else 4)

elif cmd == "self-test":
    p = common_parser()
    ns = p.parse_args(argv)
    templates = load_json(ns.templates, {"templates": []})
    policy = load_json(ns.policy, {"rules": {}})
    wanted = ["aws-ec2-gdpr", "oci-vm-gdpr", "azure-vm-gdpr", "gcp-compute-gdpr", "ibm-vpc-gdpr"]
    results = []
    for name in wanted:
        t = find_template(templates, name)
        if not t:
            results.append({"template": name, "decision": "deny", "reason": "missing_template"})
            continue
        ns2 = argparse.Namespace(provider=None, region=None, class_name=None, classification=None, legal_framework=None, workload=None, estimated_cost=None, templates=ns.templates, policy=ns.policy)
        pl = build_plan(t, ns2, policy)
        results.append({"template": name, "decision": pl["decision"], "reason": pl["reason"], "provider": pl["provider"], "mutated": pl["mutated"]})
    denial_checks = []
    for name in ["bad-missing-region", "bad-missing-legal", "bad-itar-on-generic", "bad-cost-breach"]:
        t = find_template(templates, name)
        ns2 = argparse.Namespace(provider=None, region=None, class_name=None, classification=None, legal_framework=None, workload=None, estimated_cost=None, templates=ns.templates, policy=ns.policy)
        pl = build_plan(t, ns2, policy) if t else {"decision":"deny","reason":"missing_template"}
        denial_checks.append({"template": name, "decision": pl["decision"], "reason": pl["reason"]})
    lifecycle_checks = []
    for name in wanted:
        t = find_template(templates, name)
        if not t:
            continue
        ns2 = argparse.Namespace(provider=None, region=None, class_name=None, classification=None, legal_framework=None, workload=None, estimated_cost=None, templates=ns.templates, policy=ns.policy)
        pl = build_plan(t, ns2, policy)
        lc = lifecycle_for_plan(pl, "start")
        lifecycle_checks.append({"template": name, "decision": lc.get("decision"), "reason": lc.get("reason"), "mutated": lc.get("mutated"), "live": lc.get("live")})
    ok = all(r["decision"] in ("allow", "review") and r["mutated"] is False for r in results) and all(r["decision"] == "deny" for r in denial_checks) and all(r["decision"] in ("dry_run", "review") and r["mutated"] is False and r["live"] is False for r in lifecycle_checks)
    emit({"schema": SCHEMA_DECISION, "decision": "allow" if ok else "deny", "reason": "self_test_passed" if ok else "self_test_failed", "provider_plans": results, "denial_checks": denial_checks, "lifecycle_checks": lifecycle_checks, "mutated": False, "fail_closed": not ok}, code=0 if ok else 5)

else:
    emit({"schema": SCHEMA_DECISION, "decision": "deny", "reason": "unsupported_command", "command": cmd, "fail_closed": True}, 2)
PY
