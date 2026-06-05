#!/usr/bin/env python3
"""queue plan ingestion helper.

Fixture-first, no-live adapter surface for Bob24.  It scans supported plan
formats, normalises them into queue.control_plan.v1 shaped facts, and can stage
an inert build directory.  It deliberately does not execute imported source,
contact cloud APIs, read secrets, or submit jobs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

SCHEMA = "queue.control_plan.v1"
SCAN_SCHEMA = "queue.plan.scan.v1"
BUILD_SCHEMA = "queue.plan.build.v1"
VALIDATE_SCHEMA = "queue.plan.validate.v1"
POLICY_SCHEMA = "queue.plan.policy.v1"
SCRIPT_BEHAVIOUR_SCHEMA = "queue.plan.script_behaviour.v1"
DGX_REVIEW = "DGX_CLOUD_WORKFLOW_POLICY_REVIEW"
CLOUD_WORKFLOW_REVIEW = "CLOUD_WORKFLOW_POLICY_REVIEW"

TEXT_EXTENSIONS = {
    ".yaml", ".yml", ".json", ".hcl", ".nomad", ".sbatch", ".pbs", ".qsub",
    ".sge", ".bsub", ".submit", ".dag", ".service", ".timer", ".sh", ".bash", ".txt", "",
}

ADAPTERS = {
    "bashqueues-plan": {"native": True, "family": "native", "status": "reference_adapter"},
    "kubernetes": {"native": False, "family": "cloud_native", "status": "scan_and_plan"},
    "aws-batch": {"native": False, "family": "cloud_batch", "status": "scan_and_plan"},
    "azure-batch": {"native": False, "family": "cloud_batch", "status": "recognized_pending_mapper"},
    "gcp-batch": {"native": False, "family": "cloud_batch", "status": "recognized_pending_mapper"},
    "oci": {"native": False, "family": "cloud_batch", "status": "recognized_pending_mapper"},
    "ibm-code-engine": {"native": False, "family": "cloud_batch", "status": "recognized_pending_mapper"},
    "slurm": {"native": False, "family": "hpc", "status": "scan_and_plan"},
    "pbs": {"native": False, "family": "hpc", "status": "scan_and_plan"},
    "torque": {"native": False, "family": "hpc", "status": "recognized_legacy"},
    "sge": {"native": False, "family": "hpc", "status": "recognized_legacy"},
    "lsf": {"native": False, "family": "hpc", "status": "recognized_legacy"},
    "htcondor": {"native": False, "family": "hpc", "status": "scan_and_plan"},
    "flux": {"native": False, "family": "hpc", "status": "recognized_pending_mapper"},
    "nomad": {"native": False, "family": "orchestrator", "status": "recognized_pending_mapper"},
    "argo": {"native": False, "family": "workflow", "status": "recognized_pending_mapper"},
    "tekton": {"native": False, "family": "workflow", "status": "recognized_pending_mapper"},
    "airflow": {"native": False, "family": "workflow", "status": "static_scan_only"},
    "github-actions": {"native": False, "family": "workflow", "status": "recognized_pending_mapper"},
    "gitlab-ci": {"native": False, "family": "workflow", "status": "recognized_pending_mapper"},
    "jenkinsfile": {"native": False, "family": "workflow", "status": "read_only_scan_only"},
    "systemd": {"native": False, "family": "service_manager", "status": "recognized_pending_mapper"},
    "cron": {"native": False, "family": "existing_schedule_bridge", "status": "existing_bashqueues_cron_bridge"},
    "script-behaviour": {"native": False, "family": "script", "status": "static_scan_and_plan"},
    "terraform": {"native": False, "family": "iac", "status": "extract_control_intent_only"},
    "unknown": {"native": False, "family": "unknown", "status": "unsupported"},
}

DANGEROUS_PATTERNS = [
    (re.compile(r"privileged\s*:\s*true", re.I), "privileged_container"),
    (re.compile(r"hostNetwork\s*:\s*true", re.I), "host_network"),
    (re.compile(r"hostPath\s*:", re.I), "host_path_mount"),
    (re.compile(r"runAsUser\s*:\s*0\b", re.I), "root_user"),
    (re.compile(r"\bAction\s*[:=]\s*[\"']?\*", re.I), "wildcard_cloud_action"),
    (re.compile(r"\bResource\s*[:=]\s*[\"']?\*", re.I), "wildcard_cloud_resource"),
    (re.compile(r"0\.0\.0\.0/0|::/0", re.I), "public_network_exposure"),
    (re.compile(r"\bcurl\b[^\n|]*\|\s*(?:sudo\s+)?(?:sh|bash)\b", re.I), "curl_pipe_to_shell"),
    (re.compile(r"\bwget\b[^\n|]*\|\s*(?:sudo\s+)?(?:sh|bash)\b", re.I), "wget_pipe_to_shell"),
    (re.compile(r"\brm\s+-[A-Za-z]*r[A-Za-z]*f[A-Za-z]*\s+/(?:\s|$)", re.I), "destructive_root_delete"),
    (re.compile(r"\bchmod\s+-R\s+777\b", re.I), "world_writable_recursive"),
    (re.compile(r"\b(?:sudo|su|doas)\b", re.I), "privilege_escalation_command"),
    (re.compile(r"\b(?:systemctl|service)\s+(?:restart|start|stop|enable|disable)\b", re.I), "host_service_mutation"),
    (re.compile(r"\b(?:terraform|tofu)\s+apply\b|\bpulumi\s+up\b|\bkubectl\s+apply\b|\bhelm\s+upgrade\b", re.I), "control_plane_mutation"),
]

WORKFLOW_TOKENS = ["workflow", "pipeline", "dag", "runAfter", "needs:", "stages:", "jobs:"]
CLOUD_TOKENS = ["aws", "azure", "gcp", "google", "oci", "oracle", "ibm", "cloud", "kubernetes", "eks", "aks", "gke", "oke"]


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()


def read_text(path: Path, max_bytes: int = 1024 * 1024) -> str:
    data = path.read_bytes()[:max_bytes]
    return data.decode("utf-8", errors="replace")


def iter_input_files(path: Path) -> List[Path]:
    if path.is_file():
        return [path]
    if path.is_dir():
        out: List[Path] = []
        for p in sorted(path.rglob("*")):
            if p.is_file() and p.suffix in TEXT_EXTENSIONS:
                out.append(p)
        return out
    raise SystemExit(f"queue plan: path not found: {path}")


def detect_json_adapter(path: Path, text: str) -> Optional[Tuple[str, List[str]]]:
    try:
        obj = json.loads(text)
    except Exception:
        return None
    raw = text.lower()
    objects: List[str] = []
    if isinstance(obj, dict):
        schema = str(obj.get("schema", ""))
        if schema in {"queue.plan.v1", SCHEMA}:
            return "bashqueues-plan", [schema]
        if "AWSTemplateFormatVersion" in obj or "aws::batch::" in raw:
            return "aws-batch", ["CloudFormation", "AWS::Batch"]
        if "$schema" in obj and "deploymenttemplate" in raw:
            return "azure-batch", ["ARM"]
        if "taskGroups" in obj or "allocationPolicy" in obj:
            return "gcp-batch", ["GoogleCloudBatchJob"]
        if "jobInfrastructureConfigurationDetails" in obj or "jobConfigurationDetails" in obj:
            return "oci", ["OCIDataScienceJob"]
        if "run" in obj and "application" in raw and "dataflow" in raw:
            return "oci", ["OCIDataFlowRun"]
        if "codeengine" in raw or "run_env_variables" in raw:
            return "ibm-code-engine", ["IBMCodeEngineJob"]
        kind = obj.get("kind")
        api = obj.get("apiVersion")
        if kind and api:
            return detect_kubernetes_kind(str(kind), str(api), text)
        objects = [str(k) for k in obj.keys()][:8]
    return "unknown", objects


def detect_kubernetes_kind(kind: str, api: str, text: str) -> Tuple[str, List[str]]:
    if "argoproj.io" in api.lower() or kind in {"Workflow", "WorkflowTemplate", "CronWorkflow"}:
        return "argo", [kind]
    if "tekton.dev" in api.lower() or kind in {"Task", "Pipeline", "PipelineRun"}:
        return "tekton", [kind]
    return "kubernetes", [kind]


def yaml_kinds(text: str) -> List[Tuple[str, str]]:
    out: List[Tuple[str, str]] = []
    docs = re.split(r"^---\s*$", text, flags=re.M)
    for doc in docs:
        km = re.search(r"(?m)^kind:\s*([A-Za-z0-9_.-]+)\s*$", doc)
        am = re.search(r"(?m)^apiVersion:\s*([A-Za-z0-9_.\-/]+)\s*$", doc)
        if km and am:
            out.append((km.group(1), am.group(1)))
    return out



def looks_like_shell_script(path: Path, text: str) -> bool:
    """Conservative shell-script recognition for static script-behaviour planning."""
    ext = path.suffix.lower()
    first = text.splitlines()[0].strip() if text.splitlines() else ""
    if ext in {".sh", ".bash"}:
        return True
    if first.startswith("#!") and any(tok in first for tok in ["/sh", "bash", "env sh", "env bash"]):
        return True
    return False


def classify_script_behaviour(text: str) -> Dict[str, Any]:
    """Return static, non-executing observations from a shell-like operational script."""
    low = text.lower()
    evidence: List[Dict[str, str]] = []
    classes: List[str] = []
    assets: List[Dict[str, str]] = []
    identities: List[Dict[str, str]] = []
    secrets: List[Dict[str, str]] = []
    dependencies: List[Dict[str, str]] = []
    review: List[Dict[str, str]] = []
    unsafe: List[Dict[str, str]] = []

    def ev(kind: str, token: str, inference: str) -> None:
        evidence.append({"kind": kind, "token": token, "inference": inference})

    def add_class(name: str, reason: str) -> None:
        if name not in classes:
            classes.append(name)
            ev("class_hint", name, reason)

    if re.search(r"\b(pg_dump|mysqldump|mariadb-dump|mongodump|redis-cli\s+--rdb|sqlite3\b)", low):
        add_class("BACKUP_JOB", "database dump or backup command detected")
        assets.append({"type": "database", "reason": "database dump/client command detected"})
        secrets.append({"type": "database_credential_reference", "reason": "database command usually requires credential binding; do not read secrets"})
    if re.search(r"\b(psql|mysql|migrate|liquibase|flyway|alembic)\b", low):
        add_class("DATABASE_MIGRATION", "database client or migration tool detected")
        assets.append({"type": "database", "reason": "database client or migration command detected"})
    if re.search(r"\baws\s+s3\s+cp\b|\bgcloud\s+storage\s+cp\b|\baz\s+storage\b|\boci\b.*\bos\b", low):
        add_class("BACKUP_JOB", "object-storage transfer detected")
        assets.append({"type": "object_storage", "reason": "cloud object-storage command detected"})
        identities.append({"type": "cloud_identity", "reason": "cloud CLI detected; identity must be policy-gated"})
    if re.search(r"\b(aws|az|gcloud|oci|ibmcloud)\b", low):
        assets.append({"type": "cloud_provider", "reason": "cloud CLI token detected"})
        identities.append({"type": "cloud_identity", "reason": "cloud CLI token detected; no live calls during scan"})
    if re.search(r"\b(kubectl\s+apply|helm\s+upgrade|terraform\s+apply|tofu\s+apply|pulumi\s+up)\b", low):
        add_class("DEPLOYMENT_ORCHESTRATION", "control-plane mutation command detected")
        review.append({"type": "needs_review", "reason": "control_plane_mutation", "evidence": "kubectl/helm/terraform/tofu/pulumi mutation token"})
    if re.search(r"\b(pytest|bats|npm\s+test|go\s+test|make\s+test)\b", low):
        add_class("TEST_RUNNER", "test command detected")
    if re.search(r"\b(systemctl|service|logrotate|vacuumdb|chmod|chown)\b", low):
        add_class("MAINTENANCE_JOB", "host maintenance or service-management token detected")
    if re.search(r"\b(curl|wget|ssh|scp|rsync)\b", low):
        assets.append({"type": "network_egress", "reason": "network client command detected"})
    for m in re.finditer(r"(?m)^\s*(?:mkdir\s+-p|install\s+-d)\s+([^\n#;]+)", text):
        assets.append({"type": "filesystem_writable_path", "reason": "directory creation command", "evidence": m.group(1).strip()[:120]})
    if "set -euo pipefail" in low or "set -e" in low:
        ev("failure_policy", "set -e", "script declares fail-fast shell behaviour")
    if re.search(r"(?m)^\s*trap\b", text):
        ev("cleanup_policy", "trap", "script declares cleanup or signal handling")
    if re.search(r"(?m)^\s*for\s+\w+\s+in\s+[^`$;]+;?\s+do", text):
        ev("fanout_hint", "for-in", "bounded literal loop may become fanout candidate")

    for pat, reason in DANGEROUS_PATTERNS:
        if pat.search(text):
            item = {"type": "unsafe_refused" if reason in {"curl_pipe_to_shell", "wget_pipe_to_shell", "destructive_root_delete", "world_writable_recursive"} else "needs_review", "reason": reason, "evidence": pat.pattern}
            if item["type"] == "unsafe_refused":
                unsafe.append(item)
            else:
                review.append(item)

    if re.search(r"\beval\b|`[^`]+`|\$\([^)]*\)", text):
        review.append({"type": "needs_review", "reason": "dynamic_shell_evaluation", "evidence": "eval/backticks/command-substitution token"})
    if not classes:
        add_class("SCRIPT_BEHAVIOUR", "generic shell behaviour plan; insufficient evidence for stronger class")

    dependencies.append({"from": "restriction/script_static_review", "to": "class/" + classes[0], "reason": "script-derived plans require review before execution"})
    return {
        "schema": SCRIPT_BEHAVIOUR_SCHEMA,
        "classes": classes,
        "evidence": evidence,
        "assets": assets,
        "identities": identities,
        "secrets": secrets,
        "dependencies": dependencies,
        "needs_review": review,
        "unsafe_refused": unsafe,
        "safe_to_apply": False,
        "execution_boundary": "static scan only; script is not executed, sourced, or expanded",
    }

def detect_adapter(path: Path, text: str) -> Tuple[str, List[str], str]:
    name = path.name
    lower = text.lower()
    ext = path.suffix.lower()
    j = detect_json_adapter(path, text)
    if j:
        return j[0], j[1], "high" if j[0] != "unknown" else "low"
    if re.search(r"(?m)^\s*schema:\s*(queue\.plan\.v1|queue\.control_plan\.v1)\b", text):
        return "bashqueues-plan", ["queue.plan.v1"], "high"
    if looks_like_shell_script(path, text):
        behaviour = classify_script_behaviour(text)
        return "script-behaviour", behaviour.get("classes", ["SCRIPT_BEHAVIOUR"]), "medium"
    kinds = yaml_kinds(text)
    if kinds:
        adapters = [detect_kubernetes_kind(kind, api, text)[0] for kind, api in kinds]
        adapter = "kubernetes"
        if "argo" in adapters:
            adapter = "argo"
        elif "tekton" in adapters:
            adapter = "tekton"
        objects = [kind for kind, _api in kinds]
        if "jobqueue" in lower and "jobdefinition" in lower and "aws::batch" in lower:
            return "aws-batch", objects or ["CloudFormation"], "high"
        return adapter, objects, "high"
    if "aws::batch::" in lower or "jobdefinition" in lower and "jobqueue" in lower:
        return "aws-batch", ["AWSBatch"], "high"
    if "microsoft.batch" in lower or "batchaccounts" in lower or "poolinformation" in lower or ext == ".bicep":
        return "azure-batch", ["AzureBatchOrARM"], "medium"
    if "batch.googleapis.com" in lower or "taskgroups:" in lower or "allocationpolicy:" in lower:
        return "gcp-batch", ["GoogleCloudBatchJob"], "medium"
    if "oci" in lower and ("datascience" in lower or "dataflow" in lower or "compartmentid" in lower):
        return "oci", ["OCIPlan"], "medium"
    if "codeengine" in lower or "ibmcloud" in lower:
        return "ibm-code-engine", ["IBMCodeEngineJob"], "medium"
    if re.search(r"(?m)^\s*#SBATCH\b", text) or ext == ".sbatch":
        return "slurm", re.findall(r"(?m)^\s*#SBATCH\s+([^\n]+)", text)[:12], "high"
    if re.search(r"(?m)^\s*#PBS\b", text) or ext in {".pbs", ".qsub"}:
        return ("torque" if "torque" in lower else "pbs"), re.findall(r"(?m)^\s*#PBS\s+([^\n]+)", text)[:12], "high"
    if re.search(r"(?m)^\s*#\$\b", text) or ext == ".sge":
        return "sge", re.findall(r"(?m)^\s*#\$\s+([^\n]+)", text)[:12], "medium"
    if re.search(r"(?m)^\s*#BSUB\b", text) or ext == ".bsub":
        return "lsf", re.findall(r"(?m)^\s*#BSUB\s+([^\n]+)", text)[:12], "medium"
    if re.search(r"(?mi)^\s*(executable|arguments|request_cpus|queue)\s*=", text) or ext == ".submit":
        return "htcondor", re.findall(r"(?mi)^\s*([a-z_]+)\s*=", text)[:12], "high"
    if re.search(r"(?m)^\s*(JOB|PARENT|CHILD)\s+", text) or ext == ".dag":
        return "htcondor", ["DAGMan"], "medium"
    if "version:" in lower and "resources:" in lower and "tasks:" in lower:
        return "flux", ["FluxJobspec"], "medium"
    if re.search(r"(?m)^\s*job\s+\"", text) or ext == ".nomad":
        return "nomad", ["NomadJob"], "medium"
    if name == ".gitlab-ci.yml" or "gitlab-ci" in str(path):
        return "gitlab-ci", ["GitLabCI"], "high"
    if ".github" in str(path) or "github-actions" in str(path):
        return "github-actions", ["GitHubActions"], "medium"
    if name.lower() == "jenkinsfile":
        return "jenkinsfile", ["Jenkinsfile"], "medium"
    if ext == ".py" and "airflow" in lower and "dag" in lower:
        return "airflow", ["AirflowDAG"], "medium"
    if ext in {".service", ".timer"} or re.search(r"(?m)^\s*\[(unit|service|timer)\]", text, re.I):
        return "systemd", ["systemd" + ext], "medium"
    if "resource \"" in text or "provider \"" in text or ext in {".tf", ".tofu"}:
        return "terraform", ["TerraformOrOpenTofu"], "medium"
    if looks_like_cron(text):
        return "cron", ["crontab"], "medium"
    return "unknown", [], "low"


def looks_like_cron(text: str) -> bool:
    entries = 0
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith("#") or "=" in s and not s.startswith("@"):
            continue
        if s.startswith("@") and len(s.split()) >= 2:
            entries += 1
        elif re.match(r"^([\d*/,-]+\s+){4}[\d*/,-]+\s+\S+", s):
            entries += 1
    return entries > 0


def infer_class_name(adapter: str, objects: List[str], path: Path, text: str) -> str:
    base = (objects[0] if objects else path.stem).upper()
    base = re.sub(r"[^A-Z0-9]+", "_", base).strip("_") or "PLAN"
    if "nvidia.com/gpu" in text.lower() or "dgx" in text.lower() or "gpu" in base.lower():
        return "DGX_GPU_WORKFLOW"
    prefix = {
        "kubernetes": "K8S", "aws-batch": "AWS_BATCH", "azure-batch": "AZURE_BATCH",
        "gcp-batch": "GCP_BATCH", "oci": "OCI", "ibm-code-engine": "IBM_CODE_ENGINE",
        "slurm": "SLURM", "pbs": "PBS", "torque": "TORQUE", "sge": "SGE", "lsf": "LSF",
        "htcondor": "HTCONDOR", "flux": "FLUX", "nomad": "NOMAD", "argo": "ARGO",
        "tekton": "TEKTON", "github-actions": "GITHUB_ACTIONS", "gitlab-ci": "GITLAB_CI",
        "systemd": "SYSTEMD", "cron": "CRON", "script-behaviour": "SCRIPT", "bashqueues-plan": "NATIVE",
    }.get(adapter, "PLAN")
    return f"{prefix}_{base}"[:80]


def policy_hooks(adapter: str, text: str) -> List[Dict[str, Any]]:
    hooks: List[Dict[str, Any]] = []
    low = text.lower()
    if any(tok in low for tok in ["dgx", "nvidia.com/gpu", "gpu"]):
        hooks.append({
            "policy": DGX_REVIEW,
            "reason": "DGX/GPU cloud or workflow plan detected; require explicit DGX/cloud/workflow policy review before apply",
            "applies_to": ["cloud", "workflow", "gpu", "cost", "placement", "lifecycle"],
            "policy_family": "gpu-cloud",
            "policy_files": [
                "policies.d/gpu-cloud/default.env.example",
                "policies.d/gpu-cloud/finops.example.env",
                "policies.d/gpu-cloud/network.example.tsv",
                "policies.d/gpu-cloud/object-storage.example.env",
                "policies.d/gpu-cloud/regions.tsv",
            ],
            "lifecycle_boundary": "plan-only; no DGX/cloud lifecycle mutation from queue plan",
        })
    if any(tok in low for tok in CLOUD_TOKENS) and any(tok in low for tok in WORKFLOW_TOKENS):
        hooks.append({
            "policy": CLOUD_WORKFLOW_REVIEW,
            "reason": "cloud workflow plan detected; preserve provider, identity, network and approval policy gates",
            "applies_to": ["cloud", "workflow", "identity", "network", "lifecycle"],
            "policy_family": "cloud-workflow",
            "policy_files": [
                "docs/CLOUD_PROVISIONING_CONTRACT.md",
                "docs/CLOUD_PROVISIONING_LIFECYCLE_DRY_RUN.md",
                "docs/PLAN_DGX_POLICY_HOOKS.md",
            ],
            "lifecycle_boundary": "dry-run handoff only; live cloud lifecycle remains out of queue plan",
        })
    return hooks


def analyse_file(path: Path, root: Path) -> Dict[str, Any]:
    text = read_text(path)
    adapter, objects, confidence = detect_adapter(path, text)
    adapter_meta = ADAPTERS.get(adapter, ADAPTERS["unknown"])
    dangers = []
    for pat, reason in DANGEROUS_PATTERNS:
        if pat.search(text):
            dangers.append({"reason": reason, "path": str(path)})
    hooks = policy_hooks(adapter, text)
    script_behaviour = classify_script_behaviour(text) if adapter == "script-behaviour" else None
    warnings = []
    needs_review = []
    unsafe = []
    if adapter == "unknown":
        warnings.append({"type": "unsupported_source", "path": str(path), "reason": "no supported adapter matched"})
    if adapter == "cron":
        warnings.append({"type": "cron_existing_subsystem", "path": str(path), "reason": "cron must bridge to existing bashqueues cron support; do not create a parallel scheduler"})
    if adapter == "script-behaviour":
        warnings.append({"type": "script_static_only", "path": str(path), "reason": "script is treated as operational intent only; do not execute, source, expand, or submit it"})
        needs_review.append({"type": "needs_review", "path": str(path), "reason": "script_static_review_required"})
    if hooks:
        needs_review.extend({"type": "policy_hook", **hook, "path": str(path)} for hook in hooks)
    if script_behaviour:
        needs_review.extend({**nr, "path": str(path)} for nr in script_behaviour.get("needs_review", []))
        unsafe.extend({**ur, "path": str(path)} for ur in script_behaviour.get("unsafe_refused", []))
    if adapter != "script-behaviour":
        for d in dangers:
            if d["reason"] in {"privileged_container", "wildcard_cloud_action", "wildcard_cloud_resource"}:
                unsafe.append({"type": "unsafe_refused", **d})
            else:
                needs_review.append({"type": "needs_review", **d})
    rel = str(path.relative_to(root)) if path.is_relative_to(root) else str(path)
    class_name = infer_class_name(adapter, objects, path, text)
    obj = {
        "path": rel,
        "digest": sha256_text(text),
        "adapter": adapter,
        "adapter_status": adapter_meta["status"],
        "family": adapter_meta["family"],
        "native": bool(adapter_meta["native"]),
        "format": path.suffix.lstrip(".") or "text",
        "confidence": confidence,
        "objects": objects,
        "class_candidate": class_name,
        "warnings": warnings,
        "needs_review": needs_review,
        "unsafe_refused": unsafe,
        "script_behaviour": script_behaviour,
    }
    return obj



def collect_policy_requirements(scanned: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Return stable, de-duplicated policy requirements implied by scanned plan facts."""
    seen = set()
    out: List[Dict[str, Any]] = []
    for s in scanned:
        for nr in s.get("needs_review", []):
            if nr.get("type") != "policy_hook":
                continue
            name = str(nr.get("policy", ""))
            if not name or name in seen:
                continue
            seen.add(name)
            out.append({
                "name": name,
                "required": True,
                "source_ref": nr.get("path", s.get("path")),
                "reason": nr.get("reason", "policy hook required"),
                "applies_to": nr.get("applies_to", []),
                "policy_family": nr.get("policy_family", "queue-plan"),
                "policy_files": nr.get("policy_files", []),
                "lifecycle_boundary": nr.get("lifecycle_boundary", "plan-only; no live mutation"),
            })
    return out


def build_control_plan(path: Path) -> Dict[str, Any]:
    files = iter_input_files(path)
    root = path if path.is_dir() else path.parent
    scanned = [analyse_file(f, root) for f in files]
    adapters = sorted({s["adapter"] for s in scanned})
    warnings = [w for s in scanned for w in s["warnings"]]
    needs_review = [w for s in scanned for w in s["needs_review"]]
    unsafe = [w for s in scanned for w in s["unsafe_refused"]]
    unsupported = [s for s in scanned if s["adapter"] == "unknown"]
    policy_requirements = collect_policy_requirements(scanned)
    classes = []
    restrictions = []
    job_templates = []
    dependencies = []
    approval_gates = []
    gateways = []
    assets = []
    identities = []
    secrets = []
    workflows = []
    for s in scanned:
        cname = s["class_candidate"]
        classes.append({"name": cname, "source_ref": s["path"], "adapter": s["adapter"], "status": "candidate"})
        sb = s.get("script_behaviour")
        if sb:
            for hint in sb.get("classes", []):
                hname = re.sub(r"[^A-Z0-9]+", "_", str(hint).upper()).strip("_") or "SCRIPT_BEHAVIOUR"
                classes.append({"name": hname, "source_ref": s["path"], "adapter": "script-behaviour", "status": "candidate_from_script_evidence"})
            for asset in sb.get("assets", []):
                assets.append({**asset, "source_ref": s["path"], "adapter": "script-behaviour"})
            for ident in sb.get("identities", []):
                identities.append({**ident, "source_ref": s["path"], "adapter": "script-behaviour"})
            for sec in sb.get("secrets", []):
                secrets.append({**sec, "source_ref": s["path"], "adapter": "script-behaviour"})
            for dep in sb.get("dependencies", []):
                dependencies.append({**dep, "source_ref": s["path"], "adapter": "script-behaviour"})
        restrictions.append({
            "name": f"{cname}_RESTRICTIONS", "class": cname, "source_ref": s["path"],
            "mode": "fail_closed", "requires_review": bool(s["needs_review"] or s["unsafe_refused"]),
        })
        if s["adapter"] in {"kubernetes", "aws-batch", "azure-batch", "gcp-batch", "oci", "ibm-code-engine", "slurm", "pbs", "torque", "sge", "lsf", "htcondor", "flux", "nomad", "systemd", "cron", "script-behaviour", "bashqueues-plan"}:
            job_templates.append({"name": f"{cname}_TEMPLATE", "class": cname, "source_ref": s["path"], "execution": "not_emitted_by_scan"})
        if s["adapter"] in {"argo", "tekton", "github-actions", "gitlab-ci", "airflow", "jenkinsfile", "nomad", "script-behaviour"}:
            workflows.append({"name": f"{cname}_WORKFLOW", "source_ref": s["path"], "status": "dependency_graph_candidate"})
        if s["adapter"] == "kubernetes" and any(o in {"Gateway", "HTTPRoute", "Ingress", "Service"} for o in s["objects"]):
            gateways.append({"name": f"{cname}_GATEWAY", "source_ref": s["path"], "public_exposure": "needs_review"})
        for nr in s["needs_review"]:
            if nr.get("type") == "policy_hook":
                approval_gates.append({"name": nr["policy"], "source_ref": s["path"], "reason": nr["reason"], "required": True})
        dependencies.append({"from": f"restriction/{cname}_RESTRICTIONS", "to": f"class/{cname}", "reason": "restrictions must exist before jobs may run"})
    return {
        "schema": SCHEMA,
        "source": {
            "adapter": adapters[0] if len(adapters) == 1 else "multi",
            "adapters": adapters,
            "format": "directory" if path.is_dir() else (path.suffix.lstrip(".") or "text"),
            "path": str(path),
            "file_count": len(scanned),
            "native": any(s["native"] for s in scanned),
            "confidence": "high" if scanned and all(s["confidence"] == "high" for s in scanned) else ("medium" if scanned else "unknown"),
        },
        "plan": {
            "classes": classes,
            "restrictions": restrictions,
            "assets": assets,
            "gateways": gateways,
            "identities": identities,
            "secrets": secrets,
            "job_templates": job_templates,
            "workflows": workflows,
            "dependencies": dependencies,
            "approval_gates": approval_gates,
            "policy_requirements": policy_requirements,
        },
        "analysis": {
            "objects": scanned,
            "warnings": warnings,
            "unsupported": unsupported,
            "needs_review": needs_review,
            "unsafe_refused": unsafe,
            "policy_requirements": policy_requirements,
            "safe_to_stage": len(unsafe) == 0,
            "safe_to_apply": False,
            "apply_reason": "queue plan build is staging-only; live apply remains gated and is not implemented here",
            "cron_boundary": "existing bashqueues cron support is the execution substrate for cron-like schedules",
        },
    }


def emit_json(obj: Dict[str, Any]) -> None:
    print(json.dumps(obj, sort_keys=True, separators=(",", ":")))


def human_scan(plan: Dict[str, Any]) -> None:
    print("queue plan scan")
    print(f"source: {plan['source']['path']}")
    print("adapters: " + (", ".join(plan["source"]["adapters"]) or "none"))
    print(f"files: {plan['source']['file_count']}")
    print(f"safe_to_stage: {str(plan['analysis']['safe_to_stage']).lower()}")
    if plan["analysis"]["needs_review"]:
        print(f"needs_review: {len(plan['analysis']['needs_review'])}")
    if plan["analysis"]["unsafe_refused"]:
        print(f"unsafe_refused: {len(plan['analysis']['unsafe_refused'])}")
    for obj in plan["analysis"]["objects"][:20]:
        print(f"  {obj['adapter']}\t{obj['confidence']}\t{obj['path']}\t{','.join(obj['objects'])}")


def human_explain(plan: Dict[str, Any]) -> None:
    print("queue plan explain")
    print(f"source: {plan['source']['path']}")
    print("operating model:")
    for cls in plan["plan"]["classes"]:
        print(f"  class candidate: {cls['name']} ({cls['adapter']})")
    if plan["plan"]["approval_gates"]:
        print("approval gates:")
        for gate in plan["plan"]["approval_gates"]:
            print(f"  {gate['name']}: {gate['reason']}")
    script_objs = [o for o in plan["analysis"].get("objects", []) if o.get("adapter") == "script-behaviour"]
    if script_objs:
        print("script behaviour:")
        for obj in script_objs[:10]:
            sb = obj.get("script_behaviour") or {}
            print(f"  {obj['path']}: static scan only; classes={','.join(sb.get('classes', []))}")
    if plan["plan"].get("policy_requirements"):
        print("policy requirements:")
        for req in plan["plan"]["policy_requirements"]:
            files = ", ".join(req.get("policy_files", [])[:3])
            suffix = f" [{files}]" if files else ""
            print(f"  {req['name']} -> {req.get('policy_family', 'queue-plan')}{suffix}")
    print("dependency order:")
    print("  1. classify source adapter(s)")
    print("  2. create restrictions and policy gates")
    print("  3. create class candidates")
    print("  4. stage job/workflow/gateway templates")
    print("  5. require review for privileged, public, cloud workflow, DGX/GPU or unknown controls")
    print("cron boundary: use existing bashqueues cron support; do not create a parallel scheduler")


def write_build(plan: Dict[str, Any], outdir: Path, json_mode: bool) -> None:
    outdir.mkdir(parents=True, exist_ok=True)
    for sub in ["source", "emitted/classes.d", "emitted/policies.d", "emitted/assets.d", "emitted/gateways.d", "emitted/jobs.d"]:
        (outdir / sub).mkdir(parents=True, exist_ok=True)
    (outdir / "normalized.json").write_text(json.dumps(plan, indent=2, sort_keys=True) + "\n")
    (outdir / "warnings.json").write_text(json.dumps(plan["analysis"], indent=2, sort_keys=True) + "\n")
    report = [
        "# queue plan build report",
        "",
        f"Source: `{plan['source']['path']}`",
        f"Adapters: {', '.join(plan['source']['adapters']) or 'none'}",
        f"Files: {plan['source']['file_count']}",
        f"Safe to stage: {plan['analysis']['safe_to_stage']}",
        "Safe to apply: False",
        "",
        "Cron boundary: existing bashqueues cron support remains authoritative for cron-like execution.",
        "DGX boundary: DGX/GPU cloud or workflow plans require explicit policy review.",
        "Script boundary: scripts are statically classified as intent only; they are never executed, sourced, expanded, or submitted by queue plan.",
        "",
        "Policy requirements:",
    ]
    for req in plan["plan"].get("policy_requirements", []):
        report.append(f"- {req['name']} ({req.get('policy_family', 'queue-plan')}): {req.get('reason', 'policy required')}")
    (outdir / "report.md").write_text("\n".join(report) + "\n")
    result = {"schema": BUILD_SCHEMA, "status": "ok", "output": str(outdir), "normalized": str(outdir / "normalized.json"), "safe_to_stage": plan["analysis"]["safe_to_stage"], "safe_to_apply": False}
    if json_mode:
        emit_json(result)
    else:
        print(f"queue plan build: {outdir}")
        print(f"normalized: {outdir / 'normalized.json'}")
        print("safe_to_apply: false")


def validate_plan(path: Path, json_mode: bool) -> int:
    norm = path / "normalized.json" if path.is_dir() else path
    if not norm.exists():
        out = {"schema": VALIDATE_SCHEMA, "status": "failed", "reason": "normalized.json not found", "path": str(path)}
        emit_json(out) if json_mode else print(f"queue plan validate: failed: {out['reason']}")
        return 1
    try:
        plan = json.loads(norm.read_text())
    except Exception as exc:
        out = {"schema": VALIDATE_SCHEMA, "status": "failed", "reason": f"invalid json: {exc}", "path": str(norm)}
        emit_json(out) if json_mode else print(f"queue plan validate: failed: {out['reason']}")
        return 1
    ok = plan.get("schema") == SCHEMA and "plan" in plan and "analysis" in plan
    out = {"schema": VALIDATE_SCHEMA, "status": "ok" if ok else "failed", "path": str(norm), "control_schema": plan.get("schema"), "safe_to_stage": bool(plan.get("analysis", {}).get("safe_to_stage")), "safe_to_apply": bool(plan.get("analysis", {}).get("safe_to_apply"))}
    emit_json(out) if json_mode else print(f"queue plan validate: {out['status']} {norm}")
    return 0 if ok else 1


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(prog="queue-plan-ingest.py")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ["scan", "explain", "policy"]:
        p = sub.add_parser(name)
        p.add_argument("path")
        p.add_argument("--json", "-j", action="store_true")
    b = sub.add_parser("build")
    b.add_argument("path")
    b.add_argument("--output", "-o", required=True)
    b.add_argument("--json", "-j", action="store_true")
    v = sub.add_parser("validate")
    v.add_argument("path")
    v.add_argument("--json", "-j", action="store_true")
    a = parser.parse_args(argv)
    if a.command == "validate":
        return validate_plan(Path(a.path), a.json)
    plan = build_control_plan(Path(a.path))
    if a.command == "policy":
        out = {"schema": POLICY_SCHEMA, "status": "ok", "source": plan["source"], "policy_requirements": plan["plan"].get("policy_requirements", []), "approval_gates": plan["plan"].get("approval_gates", []), "safe_to_apply": False}
        if a.json:
            emit_json(out)
        else:
            print("queue plan policy")
            if not out["policy_requirements"]:
                print("policy_requirements: none")
            for req in out["policy_requirements"]:
                print(f"  {req['name']} ({req.get('policy_family', 'queue-plan')}): {req['reason']}")
        return 0
    if a.command == "scan":
        out = {"schema": SCAN_SCHEMA, "status": "recognized" if plan["source"]["adapters"] != ["unknown"] else "unsupported", "source": plan["source"], "detected": plan["analysis"]["objects"], "analysis": {k: plan["analysis"][k] for k in ["warnings", "unsupported", "needs_review", "unsafe_refused", "safe_to_stage", "safe_to_apply", "cron_boundary"]}}
        emit_json(out) if a.json else human_scan(plan)
        return 0 if out["status"] != "unsupported" else 1
    if a.command == "explain":
        emit_json(plan) if a.json else human_explain(plan)
        return 0
    if a.command == "build":
        write_build(plan, Path(a.output), a.json)
        return 0
    parser.error("unknown command")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
