#!/usr/bin/env python3
"""Deterministic class inference helper for bashqueues.

This helper is deliberately offline and non-mutating by default.  It computes
stable command fingerprints and can recommend a class from fixture/history/pin
files.  Submit-path enforcement is intentionally out of scope for this first
contract implementation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple

FINGERPRINT_SCHEMA = "queuebash.class_inference.fingerprint.v1"
RECOMMEND_SCHEMA = "queuebash.class_inference.recommendation.v1"
EXPLAIN_SCHEMA = "queuebash.class_inference.explain.v1"
POLICY_SCHEMA = "queuebash.class_inference.policy.v1"
TEST_SCHEMA = "queuebash.class_classifier.test_result.v1"

PATH_RE = re.compile(r"(^|/|\./|\.\./)[^\s]+")
UUID_RE = re.compile(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b")
HASH_RE = re.compile(r"\b[0-9a-fA-F]{32,128}\b")
DATE_RE = re.compile(r"\b\d{4}-\d{2}-\d{2}(?:[T_ ]\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:?\d{2})?)?\b")
RANGE_RE = re.compile(r"^\d+[-:]\d+$")
NUM_RE = re.compile(r"^-?\d+(?:\.\d+)?(?:[kKmMgGtTpP]?[bB]?)?$")
URL_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*://")
SECRET_WORDS = ("token", "secret", "password", "apikey", "api_key", "credential")


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def classify_token(tok: str) -> str:
    low = tok.lower()
    if any(w in low for w in SECRET_WORDS):
        return "<secret-key>"
    if URL_RE.match(tok):
        return "<url>"
    if UUID_RE.search(tok):
        return UUID_RE.sub("<uuid>", tok)
    if HASH_RE.fullmatch(tok):
        return "<hash>"
    if DATE_RE.fullmatch(tok):
        return "<date>"
    if RANGE_RE.fullmatch(tok):
        return "<range>"
    if NUM_RE.fullmatch(tok):
        return "<num>"
    if tok.startswith("-"):
        return tok
    if "/" in tok or tok.startswith(".") or re.search(r"\.[A-Za-z0-9]{1,8}$", tok):
        suffix = Path(tok).suffix.lower()
        if suffix:
            return f"<path{suffix}>"
        return "<path>"
    # Keep structural argument words but remove unstable embedded values, e.g.
    # scale=1920:1080 -> scale=<range>, batch42 -> batch<num>.
    tok = re.sub(r"\b\d+[-:]\d+\b", "<range>", tok)
    tok = re.sub(r"\b\d+(?:\.\d+)?\b", "<num>", tok)
    return tok


def fingerprint(argv: List[str], cwd: str | None = None, requested_class: str | None = None, job: Dict[str, Any] | None = None) -> Dict[str, Any]:
    job = job or {}
    if not argv:
        raise SystemExit("queue class-infer fingerprint: command required after --")
    argv0 = Path(argv[0]).name
    script = ""
    if len(argv) > 1 and (argv[1].endswith((".py", ".sh", ".pl", ".rb", ".js")) or "/" in argv[1]):
        script = Path(argv[1]).name
    shape_tokens = [classify_token(t) for t in argv]
    exact = "\0".join(argv)
    shape = " ".join(shape_tokens)
    family_parts = [argv0]
    if script:
        family_parts.append(script)
    else:
        family_parts.extend(t for t in shape_tokens[1:3] if not t.startswith("<secret"))
    cwd_family = ""
    if cwd:
        p = Path(cwd)
        parts = p.parts
        cwd_family = "/".join(parts[:3]) if len(parts) >= 3 else str(p)
    result = {
        "schema": FINGERPRINT_SCHEMA,
        "generated_at": now_iso(),
        "argv0": argv0,
        "script": script,
        "argc": len(argv),
        "command_display": " ".join(shlex.quote(x) for x in argv),
        "arg_shape": shape,
        "family": " ".join(family_parts),
        "cwd_family": cwd_family,
        "requested_class": requested_class or "",
        "command_raw_hash": sha256_text(exact),
        "command_shape_hash": sha256_text(shape),
        "command_family_hash": sha256_text(" ".join(family_parts)),
        "job_name": str(job.get("job_name", "")),
        "user": str(job.get("user", "")),
        "group": str(job.get("group", "")),
        "paths": _seq(job.get("paths") or job.get("file_paths") or job.get("paths_touched")),
        "secrets": _seq(job.get("secrets") or job.get("secret_refs")),
        "assets": _seq(job.get("assets") or job.get("requested_assets")),
        "network": bool(job.get("network") or job.get("outbound_network")),
        "feature_keys": [],
        "normalizer": {
            "numbers": "<num>",
            "dates": "<date>",
            "paths": "<path.ext>",
            "urls": "<url>",
            "uuids": "<uuid>",
            "hashes": "<hash>",
            "ranges": "<range>",
            "secret_bearing_names": "<secret-key>",
        },
    }
    result["feature_keys"] = job_feature_keys(job, result)
    result["feature_hash"] = sha256_text("\n".join(result["feature_keys"]))
    return result


def read_json(path: str | None, default: Any) -> Any:
    if not path:
        return default
    p = Path(path)
    if not p.exists():
        return default
    return json.loads(p.read_text(encoding="utf-8"))


def read_jsonl(path: str | None) -> List[Dict[str, Any]]:
    if not path:
        return []
    p = Path(path)
    if not p.exists():
        return []
    rows = []
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        rows.append(json.loads(line))
    return rows


def read_job(path: str | None) -> Dict[str, Any]:
    if not path:
        return {}
    data = read_json(path, {})
    if not isinstance(data, dict):
        raise SystemExit(f"queue class-infer: job fixture must be a JSON object: {path}")
    return data


def command_from_job(job: Dict[str, Any], fallback: List[str]) -> List[str]:
    cmd = job.get("command") or job.get("argv") or fallback
    if isinstance(cmd, list):
        return [str(x) for x in cmd]
    if isinstance(cmd, str) and cmd.strip():
        return shlex.split(cmd)
    return fallback


def requested_class_from_job(job: Dict[str, Any], fallback: str | None) -> str:
    return str(job.get("submitted_class") or job.get("requested_class") or fallback or "")


def bucket_duration(value: Any) -> str:
    try:
        sec = float(value)
    except Exception:
        return ""
    if sec < 60:
        return "duration:<1m"
    if sec < 600:
        return "duration:<10m"
    if sec < 1800:
        return "duration:<30m"
    if sec < 3600:
        return "duration:<1h"
    return "duration:>=1h"


def _seq(value: Any) -> List[str]:
    if value is None:
        return []
    if isinstance(value, (list, tuple, set)):
        return [str(x) for x in value if str(x)]
    return [str(value)] if str(value) else []


def job_feature_keys(job: Dict[str, Any], fp: Dict[str, Any] | None = None) -> List[str]:
    keys: List[str] = []
    if fp:
        if fp.get("argv0"):
            keys.append("argv0:" + str(fp.get("argv0")))
        if fp.get("script"):
            keys.append("script:" + str(fp.get("script")))
        if fp.get("cwd_family"):
            keys.append("cwd_family:" + str(fp.get("cwd_family")))
        if fp.get("command_shape_hash"):
            keys.append("shape:" + str(fp.get("command_shape_hash")))
        if fp.get("command_family_hash"):
            keys.append("family:" + str(fp.get("command_family_hash")))
    for field in ("user", "group", "project"):
        if job.get(field):
            keys.append(f"{field}:" + str(job[field]))
    for env_key in _seq(job.get("env_keys") or job.get("environment_keys")):
        keys.append("env_key:" + env_key)
    for path in _seq(job.get("paths") or job.get("file_paths") or job.get("paths_touched")):
        parts = Path(path).parts
        # Keep stable prefixes rather than full mutable filenames.
        if len(parts) >= 3:
            keys.append("path_prefix:" + "/".join(parts[:3]))
        keys.append("path:" + str(path))
    for sec in _seq(job.get("secrets") or job.get("secret_refs")):
        keys.append("secret:" + sec)
    for asset in _seq(job.get("assets") or job.get("requested_assets")):
        keys.append("asset:" + asset)
    for cloud in _seq(job.get("cloud_resources") or job.get("resources")):
        keys.append("cloud_resource:" + cloud)
    if bool(job.get("network")) or bool(job.get("outbound_network")):
        keys.append("network:outbound")
    dur = bucket_duration(job.get("duration_sec") or job.get("runtime_sec") or "")
    if dur:
        keys.append(dur)
    # Preserve order for explainability but remove duplicates.
    seen = set()
    out = []
    for key in keys:
        if key not in seen:
            seen.add(key)
            out.append(key)
    return out


def history_feature_keys(row: Dict[str, Any]) -> List[str]:
    if isinstance(row.get("feature_keys"), list):
        return [str(x) for x in row.get("feature_keys") if str(x)]
    nested = row.get("features") if isinstance(row.get("features"), dict) else row
    fp_like = {
        "argv0": nested.get("argv0") or row.get("argv0"),
        "script": nested.get("script") or row.get("script"),
        "cwd_family": nested.get("cwd_family") or row.get("cwd_family"),
        "command_shape_hash": nested.get("command_shape_hash") or row.get("command_shape_hash") or row.get("fingerprint"),
        "command_family_hash": nested.get("command_family_hash") or row.get("command_family_hash"),
    }
    return job_feature_keys(nested, fp_like)


def similarity(candidate: Iterable[str], observed: Iterable[str]) -> Tuple[float, List[str]]:
    cand = set(candidate)
    obs = set(observed)
    if not cand or not obs:
        return 0.0, []
    inter = sorted(cand & obs)
    score = len(inter) / max(1, min(len(cand), len(obs)))
    return score, inter


def default_policy() -> Dict[str, Any]:
    return {
        "schema": POLICY_SCHEMA,
        "mode": "suggest",
        "min_observations": 3,
        "confidence_threshold": 0.80,
        "block_security_downgrade": False,
        "policy_references": [],
        "corporate_policy_refs": [],
        "regulatory_refs": [],
        "validation_status": "mapped_pending_validation",
    }


def policy_refs(policy: Dict[str, Any]) -> Dict[str, Any]:
    # Keep policy references separate and explicit so reports can link brokerage
    # decisions to corporate/regulatory policy without claiming compliance.
    refs = []
    refs.extend(policy.get("policy_references") or [])
    refs.extend(policy.get("corporate_policy_refs") or [])
    refs.extend(policy.get("regulatory_refs") or [])
    return {
        "policy_references": refs,
        "corporate_policy_refs": policy.get("corporate_policy_refs") or [],
        "regulatory_refs": policy.get("regulatory_refs") or [],
        "validation_status": policy.get("validation_status", "mapped_pending_validation"),
    }


def load_policy(path: str | None) -> Dict[str, Any]:
    pol = default_policy()
    user = read_json(path, {})
    if isinstance(user, dict):
        pol.update(user)
    return pol


def find_pin(fp: Dict[str, Any], pins: Iterable[Dict[str, Any]]) -> Dict[str, Any] | None:
    for p in pins:
        if p.get("command_shape_hash") == fp["command_shape_hash"] or p.get("fingerprint") == fp["command_shape_hash"]:
            return p
    return None


def trusted_history_row(row: Dict[str, Any]) -> bool:
    if row.get("trusted") is False:
        return bool(row.get("valid_exception"))
    outcome = str(row.get("outcome", "accepted"))
    if outcome in {"blocked", "failed", "anomaly", "policy_override"} and not row.get("valid_exception"):
        return False
    return True




def history_trust_summary(history: Iterable[Dict[str, Any]]) -> Dict[str, Any]:
    total = trusted = excluded = valid_exceptions = 0
    excluded_reasons: Dict[str, int] = defaultdict(int)
    for row in history:
        total += 1
        if row.get("valid_exception"):
            valid_exceptions += 1
        if trusted_history_row(row):
            trusted += 1
            continue
        excluded += 1
        outcome = str(row.get("outcome", "")) or "unspecified"
        if row.get("trusted") is False and not row.get("valid_exception"):
            excluded_reasons["trusted_false"] += 1
        elif outcome in {"blocked", "failed", "anomaly", "policy_override"}:
            excluded_reasons["unaccepted_outcome:" + outcome] += 1
        else:
            excluded_reasons["untrusted"] += 1
    return {
        "total_rows": total,
        "trusted_rows": trusted,
        "excluded_rows": excluded,
        "valid_exception_rows": valid_exceptions,
        "excluded_reasons": dict(sorted(excluded_reasons.items())),
    }

def weighted_history(fp: Dict[str, Any], history: Iterable[Dict[str, Any]]) -> Tuple[Dict[str, float], int, Dict[str, List[str]]]:
    classes: Dict[str, float] = defaultdict(float)
    match_reasons: Dict[str, List[str]] = defaultdict(list)
    observations = 0
    fp_features = fp.get("feature_keys") or []
    for row in history:
        if not trusted_history_row(row):
            continue
        cls = row.get("class") or row.get("usual_class") or row.get("used_class") or row.get("requested_class")
        if not cls:
            continue
        row_shape = row.get("command_shape_hash") or row.get("fingerprint")
        weight = float(row.get("learning_weight", 1.0))
        matched = False
        if row_shape and row_shape == fp.get("command_shape_hash"):
            classes[str(cls)] += weight * 3.0
            match_reasons[str(cls)].append("same command shape seen in trusted history")
            matched = True
        row_features = history_feature_keys(row)
        score, overlap = similarity(fp_features, row_features)
        if score >= 0.70:
            classes[str(cls)] += weight * score
            observations += 1
            shown = ", ".join(overlap[:5])
            match_reasons[str(cls)].append(f"feature overlap {score:.2f}: {shown}")
            matched = True
        elif matched:
            observations += 1
    return dict(classes), observations, {k: v[:6] for k, v in match_reasons.items()}


def recommend_loaded_job(job: Dict[str, Any], args: argparse.Namespace) -> Dict[str, Any]:
    cmd = command_from_job(job, getattr(args, "command", []))
    requested_arg = requested_class_from_job(job, getattr(args, "requested_class", ""))
    fp = fingerprint(cmd, getattr(args, "cwd", os.getcwd()), requested_arg, job)
    policy = load_policy(getattr(args, "policy", ""))
    pins = read_jsonl(getattr(args, "pins", ""))
    history = read_jsonl(getattr(args, "history", ""))
    trust_summary = history_trust_summary(history)
    pin = find_pin(fp, pins)
    classes, obs, history_reasons = weighted_history(fp, history)
    source = "none"
    rec_class = ""
    confidence = 0.0
    reasons: List[str] = []
    if pin:
        rec_class = str(pin.get("class", ""))
        confidence = 1.0 if rec_class else 0.0
        source = "pin"
        reasons.append("class pinned for command shape")
    elif classes:
        total = sum(classes.values())
        rec_class, top = max(classes.items(), key=lambda kv: kv[1])
        confidence = top / total if total else 0.0
        source = "history"
        reasons.append(f"dominant trusted historical class {rec_class} weight={top:.2f}/{total:.2f}")
        reasons.extend(history_reasons.get(rec_class, []))
    else:
        reasons.append("no matching pin or historical observations")
    requested = requested_arg or fp.get("requested_class") or ""
    mismatch = "none"
    if requested and rec_class and requested != rec_class:
        mismatch = "class_mismatch"
    min_obs = int(policy.get("min_observations", 3))
    threshold = float(policy.get("confidence_threshold", 0.8))
    action = policy.get("mode", "suggest")
    if source == "history" and (obs < min_obs or confidence < threshold):
        action = "observe"
    if not rec_class:
        action = "observe"
    decision = "ok"
    recommended_action = "allow"
    if not rec_class:
        decision = "insufficient_history"
        recommended_action = "defer_to_class_policy"
    elif mismatch != "none":
        decision = "class_downgrade_suspected" if requested else "class_mismatch"
        if float(confidence) >= threshold and bool(policy.get("block_security_downgrade", False)):
            recommended_action = "block_pending_authorisation"
        else:
            recommended_action = "warn_or_require_review"
    elif source == "history" and (obs < min_obs or confidence < threshold):
        decision = "insufficient_history"
        recommended_action = "defer_to_class_policy"
    elif source in {"history", "pin"}:
        decision = "ok"
        recommended_action = "allow"
    if decision != "ok" and not reasons:
        reasons.append("decision requires explanation before enforcement")
    refs = policy_refs(policy)
    result = {
        "schema": RECOMMEND_SCHEMA,
        "generated_at": now_iso(),
        "fingerprint": fp,
        "requested_class": requested,
        "recommended_class": rec_class,
        "confidence": round(confidence, 4),
        "observations": obs,
        "recommendation_source": source,
        "mismatch": mismatch,
        "decision": decision,
        "recommended_action": recommended_action,
        "policy_action": action,
        "reasons": reasons,
        "policy_linkage": refs,
        "trusted_history": trust_summary,
        "audit_event_preview": {
            "event": "queuebash.class_inference.v1",
            "requested_class": requested,
            "recommended_class": rec_class,
            "confidence": round(confidence, 4),
            "observations": obs,
            "mismatch": mismatch,
            "policy_action": action,
            "decision": decision,
            "recommended_action": recommended_action,
            "fingerprint": fp["command_shape_hash"],
            "policy_references": refs["policy_references"],
            "trusted_history": trust_summary,
        },
        "non_mutating": True,
        "submit_integration": "not_enabled_in_this_package",
    }
    if pin:
        result["pin"] = {k: pin.get(k) for k in ("class", "authority", "reason", "policy_references", "regulatory_refs", "corporate_policy_refs") if k in pin}
    return result


def recommend(args: argparse.Namespace) -> Dict[str, Any]:
    return recommend_loaded_job(read_job(getattr(args, "job", "")), args)


def iter_fixture_rows(path: Path) -> Iterable[Dict[str, Any]]:
    if path.suffix == ".jsonl":
        for row in read_jsonl(str(path)):
            yield row
    elif path.suffix == ".json":
        data = read_json(str(path), {})
        if isinstance(data, list):
            for row in data:
                if isinstance(row, dict):
                    yield row
        elif isinstance(data, dict):
            yield data


def fixture_files(fixtures: Path, selected: List[str] | None = None) -> List[Path]:
    names = selected or [
        "jobs_normal.jsonl",
        "jobs_downgrade.jsonl",
        "jobs_near_miss.jsonl",
        "jobs_cold_start.jsonl",
        "jobs_adversarial_rename.jsonl",
        "jobs_drift.jsonl",
        "jobs_trusted_history_guard.jsonl",
    ]
    out: List[Path] = []
    for name in names:
        p = fixtures / name
        if p.exists():
            out.append(p)
    return out


def check_expected(result: Dict[str, Any], expected: Dict[str, Any]) -> Tuple[bool, List[str]]:
    failures: List[str] = []
    for key in ("decision", "recommended_action", "recommended_class"):
        if key in expected and result.get(key) != expected.get(key):
            failures.append(f"expected {key}={expected.get(key)!r} got {result.get(key)!r}")
    for key in ("decision", "recommended_action", "recommended_class"):
        not_key = "not_" + key
        if not_key in expected and result.get(key) == expected.get(not_key):
            failures.append(f"expected {key} != {expected.get(not_key)!r}")
    if "confidence_min" in expected:
        try:
            if float(result.get("confidence", 0.0)) < float(expected["confidence_min"]):
                failures.append(f"expected confidence >= {expected['confidence_min']} got {result.get('confidence')}")
        except Exception:
            failures.append("confidence is not numeric")
    if "confidence_max" in expected:
        try:
            if float(result.get("confidence", 0.0)) > float(expected["confidence_max"]):
                failures.append(f"expected confidence <= {expected['confidence_max']} got {result.get('confidence')}")
        except Exception:
            failures.append("confidence is not numeric")
    return not failures, failures


def run_fixture_tests(args: argparse.Namespace) -> Dict[str, Any]:
    fixtures = Path(args.fixtures)
    if not fixtures.exists():
        raise SystemExit(f"queue class-infer test: fixtures directory not found: {fixtures}")
    history = args.history or str(fixtures / "history_normal.jsonl")
    policy = args.policy or str(fixtures / "policy_block_on_downgrade.json")
    pins = args.pins or ""
    files = fixture_files(fixtures, args.file or None)
    case_results: List[Dict[str, Any]] = []
    total = passed = 0
    expected_blocks = actual_blocks = 0
    near_miss_cases = unexpected_blocks = 0
    reasons_required = reasons_present = 0
    history_total_rows = history_trusted_rows = history_excluded_rows = history_valid_exception_rows = 0
    for path in files:
        category = path.stem.replace("jobs_", "")
        if category == "near_miss":
            near_miss_cases += sum(1 for _ in iter_fixture_rows(path))
        for index, job in enumerate(iter_fixture_rows(path), start=1):
            total += 1
            expected = job.get("expected") if isinstance(job.get("expected"), dict) else {}
            case_history = history
            if job.get("history"):
                case_history_path = Path(str(job.get("history")))
                case_history = str(case_history_path if case_history_path.is_absolute() else fixtures / case_history_path)
            case_policy = policy
            if job.get("policy"):
                case_policy_path = Path(str(job.get("policy")))
                case_policy = str(case_policy_path if case_policy_path.is_absolute() else fixtures / case_policy_path)
            ns = argparse.Namespace(
                command=[], cwd=args.cwd, requested_class="", history=case_history, pins=pins, policy=case_policy, job=""
            )
            result = recommend_loaded_job(job, ns)
            ok, failures = check_expected(result, expected)
            if expected.get("recommended_action") == "block_pending_authorisation":
                expected_blocks += 1
            if result.get("recommended_action") == "block_pending_authorisation":
                actual_blocks += 1
                if category == "near_miss":
                    unexpected_blocks += 1
            requires_reason = result.get("decision") != "ok" or result.get("recommended_action") != "allow"
            if requires_reason:
                reasons_required += 1
                if result.get("reasons"):
                    reasons_present += 1
                else:
                    ok = False
                    failures.append("non-ok/non-allow result has no explainability reasons")
            trust = result.get("trusted_history", {}) if isinstance(result.get("trusted_history"), dict) else {}
            history_total_rows += int(trust.get("total_rows", 0) or 0)
            history_trusted_rows += int(trust.get("trusted_rows", 0) or 0)
            history_excluded_rows += int(trust.get("excluded_rows", 0) or 0)
            history_valid_exception_rows += int(trust.get("valid_exception_rows", 0) or 0)
            if ok:
                passed += 1
            case = {
                "file": str(path),
                "category": category,
                "index": index,
                "job_name": job.get("job_name", ""),
                "submitted_class": result.get("requested_class", ""),
                "recommended_class": result.get("recommended_class", ""),
                "decision": result.get("decision", ""),
                "recommended_action": result.get("recommended_action", ""),
                "confidence": result.get("confidence", 0.0),
                "reason_count": len(result.get("reasons", [])),
                "trusted_history": trust,
                "status": "pass" if ok else "fail",
            }
            if failures:
                case["failures"] = failures
            if args.include_case_results:
                case["result"] = result
            case_results.append(case)
    failed = total - passed
    return {
        "schema": TEST_SCHEMA,
        "generated_at": now_iso(),
        "status": "pass" if failed == 0 else "fail",
        "cases": total,
        "passed": passed,
        "failed": failed,
        "fixtures": str(fixtures),
        "history": history,
        "policy": policy,
        "files": [str(p) for p in files],
        "downgrade_detection": {
            "expected_blocks": expected_blocks,
            "actual_blocks": actual_blocks,
        },
        "false_positive_guard": {
            "near_miss_cases": near_miss_cases,
            "unexpected_blocks": unexpected_blocks,
        },
        "reason_coverage": {
            "cases_requiring_reasons": reasons_required,
            "cases_with_reasons": reasons_present,
        },
        "trusted_history_guard": {
            "total_rows_seen": history_total_rows,
            "trusted_rows_seen": history_trusted_rows,
            "excluded_rows_seen": history_excluded_rows,
            "valid_exception_rows_seen": history_valid_exception_rows,
        },
        "case_results": case_results,
        "non_mutating": True,
    }


def human_test_report(obj: Dict[str, Any]) -> str:
    lines = [
        f"Class classifier fixture test: {obj.get('status')}",
        f"  cases:  {obj.get('cases')}",
        f"  passed: {obj.get('passed')}",
        f"  failed: {obj.get('failed')}",
        f"  expected downgrade blocks: {obj.get('downgrade_detection', {}).get('expected_blocks')}",
        f"  actual downgrade blocks:   {obj.get('downgrade_detection', {}).get('actual_blocks')}",
        f"  near-miss cases:           {obj.get('false_positive_guard', {}).get('near_miss_cases')}",
        f"  unexpected near-miss block:{obj.get('false_positive_guard', {}).get('unexpected_blocks')}",
    ]
    for case in obj.get("case_results", []):
        if case.get("status") != "pass":
            lines.append(f"  FAIL {case.get('file')}#{case.get('index')} {case.get('job_name')}: {'; '.join(case.get('failures', []))}")
    return "\n".join(lines)


def human_report(obj: Dict[str, Any]) -> str:
    if obj["schema"] == FINGERPRINT_SCHEMA:
        return "\n".join([
            "Class fingerprint",
            f"  argv0:  {obj['argv0']}",
            f"  shape:  {obj['arg_shape']}",
            f"  hash:   {obj['command_shape_hash']}",
            f"  family: {obj['family']}",
        ])
    refs = obj.get("policy_linkage", {})
    lines = [
        "Class recommendation",
        f"  requested:    {obj.get('requested_class') or '(none)'}",
        f"  recommended:  {obj.get('recommended_class') or '(none)'}",
        f"  confidence:   {obj.get('confidence')}",
        f"  observations: {obj.get('observations')}",
        f"  source:       {obj.get('recommendation_source')}",
        f"  mismatch:     {obj.get('mismatch')}",
        f"  action:       {obj.get('policy_action')}",
        "  reasons:",
    ]
    lines.extend(f"    - {r}" for r in obj.get("reasons", []))
    if refs.get("policy_references"):
        lines.append("  policy references:")
        for ref in refs.get("policy_references", []):
            if isinstance(ref, dict):
                lines.append(f"    - {ref.get('id','')} {ref.get('title','')} [{ref.get('status','')}] {ref.get('url','')}")
            else:
                lines.append(f"    - {ref}")
    lines.append(f"  validation:   {refs.get('validation_status', 'mapped_pending_validation')}")
    return "\n".join(lines)


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(prog="queue-class-infer", description="Deterministic class fingerprint/recommendation helper")
    sub = parser.add_subparsers(dest="cmd", required=True)
    pf = sub.add_parser("fingerprint")
    pf.add_argument("--json", action="store_true")
    pf.add_argument("--cwd", default=os.getcwd())
    pf.add_argument("--requested-class", "--class", dest="requested_class", default="")
    pf.add_argument("--job", default="")
    pf.add_argument("command", nargs=argparse.REMAINDER)
    pr = sub.add_parser("recommend")
    pr.add_argument("--json", action="store_true")
    pr.add_argument("--cwd", default=os.getcwd())
    pr.add_argument("--requested-class", "--class", dest="requested_class", default="")
    pr.add_argument("--history", default="")
    pr.add_argument("--pins", default="")
    pr.add_argument("--policy", default="")
    pr.add_argument("--job", default="")
    pr.add_argument("command", nargs=argparse.REMAINDER)
    pe = sub.add_parser("explain")
    pe.add_argument("--json", action="store_true")
    pe.add_argument("--cwd", default=os.getcwd())
    pe.add_argument("--history", default="")
    pe.add_argument("--pins", default="")
    pe.add_argument("--policy", default="")
    pe.add_argument("--requested-class", "--class", dest="requested_class", default="")
    pe.add_argument("--job", default="")
    pe.add_argument("command", nargs=argparse.REMAINDER)
    pt = sub.add_parser("test", help="run fixture-based class downgrade/anomaly classifier tests")
    pt.add_argument("--json", action="store_true")
    pt.add_argument("--fixtures", required=True)
    pt.add_argument("--history", default="")
    pt.add_argument("--pins", default="")
    pt.add_argument("--policy", default="")
    pt.add_argument("--cwd", default=os.getcwd())
    pt.add_argument("--file", action="append", help="fixture filename relative to --fixtures; may be repeated")
    pt.add_argument("--include-case-results", action="store_true")
    pt.set_defaults(command=[])
    ns = parser.parse_args(argv)
    if getattr(ns, "command", None) and ns.command and ns.command[0] == "--":
        ns.command = ns.command[1:]
    if ns.cmd == "fingerprint":
        job = read_job(getattr(ns, "job", ""))
        cmd = command_from_job(job, ns.command)
        requested_arg = requested_class_from_job(job, ns.requested_class)
        obj = fingerprint(cmd, ns.cwd, requested_arg, job)
    elif ns.cmd == "test":
        obj = run_fixture_tests(ns)
    else:
        obj = recommend(ns)
        if ns.cmd == "explain":
            obj = {"schema": EXPLAIN_SCHEMA, "recommendation": obj, "explain_text": human_report(obj)}
    if getattr(ns, "json", False):
        print(json.dumps(obj, sort_keys=True, indent=2))
    else:
        if ns.cmd == "explain":
            print(obj["explain_text"])
        elif ns.cmd == "test":
            print(human_test_report(obj))
        else:
            print(human_report(obj))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
