#!/usr/bin/env python3
"""Deterministic path-lock fixture evaluator for bashqueues tests.

This helper does not open or mutate target paths. It evaluates structured
profile/observation fixtures so the path-lock contract can be tested before a
runtime safe-open enforcer exists.
"""
from __future__ import annotations

import json
import sys
from pathlib import PurePosixPath
from typing import Any, Dict, List

SCHEMA = "queuebash.path_lock.decision.v1"


def _load(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as fh:
        obj = json.load(fh)
    if not isinstance(obj, dict):
        raise SystemExit("path-lock fixture must be a JSON object")
    return obj


def _is_beneath(path: str, root: str) -> bool:
    try:
        p = PurePosixPath(path)
        r = PurePosixPath(root)
        return p == r or r in p.parents
    except Exception:
        return False


def evaluate(obj: Dict[str, Any]) -> Dict[str, Any]:
    grant = obj.get("grant") or obj.get("profile") or {}
    observed = obj.get("observed") or {}
    expected = obj.get("expected") or {}
    operation = observed.get("operation") or grant.get("write_policy") or "existing-file-only"
    high_risk = bool(obj.get("class", {}).get("high_risk") or grant.get("high_risk"))

    reasons: List[str] = []

    if grant.get("symlink_policy", "deny") == "deny" and observed.get("symlink_seen"):
        reasons.append("symlink_denied")
    if grant.get("magiclink_policy", "deny") == "deny" and observed.get("magiclink_seen"):
        reasons.append("magiclink_denied")
    if observed.get("path_escape") or ".." in str(observed.get("requested_path", "")).split("/"):
        reasons.append("path_escape_denied")
    if observed.get("mount_crossing") and not grant.get("allow_mount_crossing", False):
        reasons.append("mount_crossing_denied")

    parent_expected = grant.get("parent_dev_inode")
    parent_observed = observed.get("parent_dev_inode")
    if parent_expected and parent_observed and parent_expected != parent_observed:
        reasons.append("parent_identity_mismatch")

    if operation in ("existing-file-only", "append-only"):
        final_expected = grant.get("final_dev_inode")
        final_observed = observed.get("final_dev_inode")
        if final_expected and final_observed and final_expected != final_observed:
            reasons.append("final_identity_mismatch")
        if observed.get("file_type") and observed.get("file_type") != "regular-file":
            reasons.append("file_type_denied")

    if operation == "create-only-under-owned-dir":
        root = grant.get("approved_root") or grant.get("parent_canonical_path")
        requested = observed.get("requested_path") or ""
        if root and not _is_beneath(requested, root):
            reasons.append("create_outside_approved_root")
        if not observed.get("private_workspace", False):
            reasons.append("private_workspace_required")

    if operation == "replace-atomic":
        if observed.get("rename_cross_directory"):
            reasons.append("replace_cross_directory_denied")
        if observed.get("temp_parent_dev_inode") and parent_expected and observed.get("temp_parent_dev_inode") != parent_expected:
            reasons.append("replace_temp_parent_mismatch")

    if high_risk and observed.get("shared_tmp_target"):
        reasons.append("shared_tmp_high_risk_denied")

    allowed = not reasons
    if "allowed" in expected and bool(expected["allowed"]) != allowed:
        reasons.append("fixture_expected_outcome_mismatch")
        allowed = False

    return {
        "schema": SCHEMA,
        "status": "allowed" if allowed else "blocked",
        "allowed": allowed,
        "operation": operation,
        "canonical_path": grant.get("canonical_path") or observed.get("canonical_path"),
        "parent_dev_inode": parent_observed or parent_expected,
        "final_dev_inode": observed.get("final_dev_inode") or grant.get("final_dev_inode"),
        "reasons": reasons,
        "redacted": True,
        "secret_value_included": False,
    }


def main(argv: List[str]) -> int:
    if len(argv) != 3 or argv[1] != "evaluate":
        print("Usage: path_lock_fixture.py evaluate FIXTURE.json", file=sys.stderr)
        return 2
    print(json.dumps(evaluate(_load(argv[2])), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
