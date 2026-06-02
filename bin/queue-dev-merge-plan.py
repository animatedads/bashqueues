#!/usr/bin/env python3
"""Read-only, bounded merge-plan reporter for queue dev patchsets.

This tool inspects patchset zips without applying them. It discovers patchset
roots, reads manifests directly from the zip central directory, expands simple
container zips that hold multiple patchset zips, normalises known manifest
shapes into one internal model, extracts only small requested members in memory,
compares file/function scope, reports release identity overlaps, scratchpad
merge shapes, delivery-evidence cleanup candidates, and produces a proposed
merge/validation plan for Bob the Merger.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import re
import sys
import zipfile
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

SCHEMA = "queuebash.dev_merge_plan.v1"
DEFAULT_MAX_BYTES = 5 * 1024 * 1024

BASH_FUNCTION_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{")
PY_FUNCTION_RE = re.compile(r"^(?:async\s+)?def\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
ASSIGN_RE = re.compile(r"\b([A-Z][A-Z0-9_]{2,})\b")
CALL_RE = re.compile(r"\b(_queue_[A-Za-z0-9_]+|queue_[A-Za-z0-9_]+)\b")
VERSION_RE = re.compile(r"\b([0-9]+\.[0-9]+\.[0-9]+)\b")


class ZipSource:
    def __init__(self, name: str, zip_bytes: bytes, origin_path: Optional[Path] = None, container_member: Optional[str] = None):
        self.name = name
        self.zip_bytes = zip_bytes
        self.origin_path = origin_path
        self.container_member = container_member

    @property
    def size(self) -> int:
        return len(self.zip_bytes)

    def open(self) -> zipfile.ZipFile:
        return zipfile.ZipFile(io.BytesIO(self.zip_bytes))


def sha256(data: bytes) -> str:
    return "sha256:" + hashlib.sha256(data).hexdigest()


def load_json_bytes(data: bytes, source: str) -> Dict[str, Any]:
    try:
        return json.loads(data.decode("utf-8"))
    except Exception as exc:
        raise SystemExit(f"queue dev merge-plan: cannot parse JSON {source}: {exc}")


def discover_patchset_roots(z: zipfile.ZipFile) -> List[str]:
    names = set(z.namelist())
    candidates = [n for n in names if n.endswith("manifest.json") and not n.endswith("backup_manifest.json")]
    ranked: List[Tuple[int, str]] = []
    for manifest in candidates:
        root = manifest[: -len("manifest.json")]
        score = 0
        for d in ("files/", "baseline/", "diffs/", "scripts/", "patches/"):
            if any(n.startswith(root + d) for n in names):
                score += 2
        if root == "":
            score += 1
        ranked.append((score, root))
    # Keep all manifest roots, with the best direct patchset root first. Some
    # synthetic/nightmare fixtures deliberately contain several patchsets.
    ranked.sort(key=lambda x: (-x[0], x[1]))
    return [r for _score, r in ranked]


def zip_read_limited(z: zipfile.ZipFile, member: str, max_bytes: int) -> Optional[bytes]:
    try:
        info = z.getinfo(member)
    except KeyError:
        return None
    if info.file_size > max_bytes:
        return None
    return z.read(info)


def classify_path(path: str, change_type: str) -> str:
    if path == "queuebash.sh":
        return "queuebash_function_update"
    if path in {"README.md", "CHANGELOG.md"}:
        return "release_identity_update"
    if path == ".queuebash/dev/scratchpad.json":
        return "scratchpad_item_merge"
    if path.startswith("docs/") or path.endswith(".md"):
        return "docs_update"
    if path.startswith("tests/"):
        return "test_update"
    if path.startswith("providers.d/"):
        return "provider_update"
    if path.startswith("policies.d/"):
        return "policy_update"
    if re.search(r"(^|/)(validation|cleanup|merge_manifest|notes).*(\.log|\.json|\.md)$", path):
        return "delivery_evidence"
    if change_type in {"new_file", "add_file", "created_file", "add", "create"}:
        return "add_file"
    if change_type in {"delete", "deleted_file", "remove"}:
        return "delete_file"
    return "unknown"


def extract_release_claim(text: str, path: str) -> Optional[Dict[str, str]]:
    if path == "README.md":
        m = re.search(r"^##\s+([0-9]+\.[0-9]+\.[0-9]+)\s+(.+)$", text, re.M)
        if m:
            return {"version": m.group(1), "title": m.group(2).strip(), "source": path}
    if path == "CHANGELOG.md":
        m = re.search(r"^##\s+([0-9]+\.[0-9]+\.[0-9]+)\s+-\s+(.+)$", text, re.M)
        if m:
            return {"version": m.group(1), "title": m.group(2).strip(), "source": path}
    if path == "queuebash.sh":
        m = re.search(r'^QUEUEBASH_VERSION="([^"]+)"', text, re.M)
        if m:
            return {"version": m.group(1), "title": "QUEUEBASH_VERSION", "source": path}
    return None


def manifest_release_claims(manifest: Dict[str, Any]) -> List[Dict[str, str]]:
    claims: List[Dict[str, str]] = []
    version = manifest.get("version") or manifest.get("release_version") or manifest.get("target_version")
    title = manifest.get("title") or manifest.get("name") or manifest.get("package") or manifest.get("summary")
    if isinstance(version, str) and VERSION_RE.search(version):
        claims.append({"version": VERSION_RE.search(version).group(1), "title": str(title or "manifest version"), "source": "manifest.json"})
    # Some manifests only carry version in package/name/summary.
    for key in ("package", "name", "summary"):
        val = manifest.get(key)
        if isinstance(val, str):
            m = VERSION_RE.search(val)
            if m:
                claim = {"version": m.group(1), "title": val, "source": f"manifest.{key}"}
                if claim not in claims:
                    claims.append(claim)
    return claims


def parse_bash_functions(text: str) -> Dict[str, Dict[str, Any]]:
    lines = text.splitlines()
    result: Dict[str, Dict[str, Any]] = {}
    i = 0
    while i < len(lines):
        m = BASH_FUNCTION_RE.match(lines[i])
        if not m:
            i += 1
            continue
        name = m.group(1)
        start = i
        depth = lines[i].count("{") - lines[i].count("}")
        i += 1
        while i < len(lines) and depth > 0:
            depth += lines[i].count("{") - lines[i].count("}")
            i += 1
        end = i
        body = "\n".join(lines[start:end]) + "\n"
        calls = sorted(set(c for c in CALL_RE.findall(body) if c != name))
        globals_seen = sorted(set(ASSIGN_RE.findall(body)))
        result[name] = {"name": name, "start_line": start + 1, "end_line": end, "md5": hashlib.md5(body.encode()).hexdigest(), "sha256": sha256(body.encode()), "calls": calls, "globals": globals_seen, "body": body}
    return result


def parse_python_functions(text: str) -> Dict[str, Dict[str, Any]]:
    lines = text.splitlines()
    result: Dict[str, Dict[str, Any]] = {}
    starts: List[Tuple[str, int, int]] = []
    for i, line in enumerate(lines):
        m = PY_FUNCTION_RE.match(line)
        if m:
            starts.append((m.group(1), i, len(line) - len(line.lstrip())))
    for idx, (name, start, indent) in enumerate(starts):
        end = len(lines)
        for _next_name, nstart, nindent in starts[idx + 1:]:
            if nindent <= indent:
                end = nstart
                break
        body = "\n".join(lines[start:end]) + "\n"
        result[name] = {"name": name, "start_line": start + 1, "end_line": end, "md5": hashlib.md5(body.encode()).hexdigest(), "sha256": sha256(body.encode()), "calls": [], "globals": [], "body": body}
    return result


def parse_functions_for_path(path: str, text: str) -> Dict[str, Dict[str, Any]]:
    if path.endswith(".sh") or path == "queuebash.sh":
        return parse_bash_functions(text)
    if path.endswith(".py"):
        return parse_python_functions(text)
    return {}


def reverse_call_index(functions: Dict[str, Dict[str, Any]]) -> Dict[str, List[str]]:
    idx: Dict[str, List[str]] = defaultdict(list)
    for name, data in functions.items():
        for c in data.get("calls", []):
            idx[c].append(name)
    return {k: sorted(v) for k, v in idx.items()}


def diff_changed_functions(relpath: str, old_text: Optional[str], new_text: Optional[str]) -> Dict[str, Any]:
    if old_text is None and new_text is None:
        return {"tooling": {"status": "not_applicable"}, "functions": []}
    old_funcs = parse_functions_for_path(relpath, old_text or "")
    new_funcs = parse_functions_for_path(relpath, new_text or "")
    if not old_funcs and not new_funcs:
        return {"tooling": {"status": "not_applicable"}, "functions": []}
    old_names, new_names = set(old_funcs), set(new_funcs)
    changed = []
    for name in sorted(old_names | new_names):
        if name not in old_names:
            status = "function_added"
        elif name not in new_names:
            status = "function_deleted"
        elif old_funcs[name]["md5"] != new_funcs[name]["md5"]:
            status = "function_modified"
        else:
            continue
        new_data = new_funcs.get(name, old_funcs.get(name, {}))
        callers = reverse_call_index(new_funcs).get(name, [])
        tests = ["bash -n queuebash.sh"] if relpath == "queuebash.sh" else []
        if relpath == "queuebash.sh":
            tests.append(f"queue dev test qbtest --file queuebash.sh --function {name} --json")
        elif relpath.endswith(".sh"):
            tests.append(f"bash -n {relpath}")
        elif relpath.endswith(".py"):
            tests.append(f"python3 -m py_compile {relpath}")
        changed.append({"function": name, "status": status, "calls": new_data.get("calls", []), "called_by": callers, "globals": new_data.get("globals", []), "recommended_tests": tests})
    return {"tooling": {"preferred": "queue dev functions/symbols/flow/extract for queuebash.sh; static parser for generic .py/.sh fixtures", "status": "static_fallback_used", "fallback": "bounded_static_function_boundary_parser"}, "functions": changed}


def normalize_change_type(value: Any) -> str:
    v = str(value or "unknown").strip().lower()
    return {"modified_file": "modify", "update": "modify", "updated": "modify", "new_file": "add", "created_file": "add", "create": "add", "remove": "delete", "deleted_file": "delete"}.get(v, v)


def normalize_manifest_entries(manifest: Dict[str, Any]) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """Return normalised entries and manifest-shape warnings."""
    warnings: List[Dict[str, Any]] = []
    raw: Any = None
    dialect = "unknown"
    if isinstance(manifest.get("entries"), list):
        raw = manifest.get("entries")
        dialect = "entries"
    elif isinstance(manifest.get("files"), list):
        raw = manifest.get("files")
        dialect = "files"
    else:
        warnings.append({"type": "unsupported_manifest_shape", "reason": "manifest has neither entries[] nor files[]", "keys": sorted(manifest.keys())})
        return [], warnings
    out: List[Dict[str, Any]] = []
    for idx, item in enumerate(raw or []):
        if not isinstance(item, dict):
            warnings.append({"type": "malformed_manifest_entry", "index": idx, "reason": "entry is not an object"})
            continue
        rel = item.get("relpath") or item.get("path") or item.get("target") or item.get("target_path") or item.get("name") or item.get("file")
        if rel and isinstance(rel, str):
            rel = re.sub(r"^(files|new|payload|after|content)/", "", rel)
        if not rel:
            warnings.append({"type": "malformed_manifest_entry", "index": idx, "reason": "cannot determine relpath", "entry_keys": sorted(item.keys())})
            continue
        change_type = normalize_change_type(item.get("change_type") or item.get("action") or item.get("change") or item.get("type"))
        out.append({
            "relpath": rel,
            "change_type": change_type,
            "dialect": dialect,
            "entry_id": item.get("entry_id") or item.get("id") or item.get("manifest_entry_id") or f"{dialect}-{idx}",
            "file": item.get("file") or item.get("new_file") or item.get("new") or item.get("payload") or item.get("content_path"),
            "baseline": item.get("baseline") or item.get("base_file") or item.get("old_file") or item.get("old") or item.get("before"),
            "diff": item.get("diff") or item.get("diff_file") or item.get("patch"),
            "changed_functions": item.get("changed_functions") or item.get("functions") or [],
            "file_new_size": item.get("file_new_size") or item.get("new_size") or item.get("size"),
            "file_old_size": item.get("file_old_size") or item.get("old_size"),
            "baseline_present": item.get("baseline_present"),
            "raw_keys": sorted(item.keys()),
        })
    if not out:
        warnings.append({"type": "zero_entry_patchset", "reason": "manifest normalised to zero entries", "dialect": dialect, "keys": sorted(manifest.keys())})
    return out, warnings


def candidate_members(root: str, rel: str, explicit: Optional[str], kind: str) -> List[str]:
    vals: List[str] = []
    if explicit:
        vals.append(root + explicit.lstrip("/"))
    if kind == "file":
        vals += [root + f"files/{rel}", root + f"new/{rel}", root + f"payload/{rel}", root + f"after/{rel}", root + rel]
    elif kind == "baseline":
        vals += [root + f"baseline/{rel}", root + f"baselines/{rel}", root + f"base/{rel}", root + f"old/{rel}", root + f"before/{rel}"]
    else:
        vals += [root + f"diffs/{rel}.diff", root + f"diffs/{rel}.patch", root + f"diff/{rel}.diff"]
    seen = []
    for v in vals:
        if v not in seen:
            seen.append(v)
    return seen


def first_existing_limited(z: zipfile.ZipFile, candidates: List[str], max_bytes: int) -> Tuple[Optional[str], Optional[bytes]]:
    for c in candidates:
        data = zip_read_limited(z, c, max_bytes)
        if data is not None:
            return c, data
    return None, None


def analyse_patchset_root(src: ZipSource, root: str, max_bytes: int) -> Dict[str, Any]:
    with src.open() as z:
        infos = z.infolist()
        manifest_member = root + "manifest.json"
        manifest = load_json_bytes(z.read(manifest_member), f"{src.name}:{manifest_member}")
        entries_norm, warnings = normalize_manifest_entries(manifest)
        extracted_bytes = 0
        extracted_members = 1
        entries_out = []
        release_claims = manifest_release_claims(manifest)
        function_changes = []
        scratchpad = {"items_added": 0, "malformed": 0, "strategy": "item_level_required"}
        evidence = []
        for e in entries_norm:
            rel = e["relpath"]
            change_type = e["change_type"]
            cls = classify_path(rel, change_type)
            file_member, new_bytes = first_existing_limited(z, candidate_members(root, rel, e.get("file"), "file"), max_bytes)
            base_member, old_bytes = first_existing_limited(z, candidate_members(root, rel, e.get("baseline"), "baseline"), max_bytes)
            diff_member, diff_bytes = first_existing_limited(z, candidate_members(root, rel, e.get("diff"), "diff"), max_bytes)
            for blob in (new_bytes, old_bytes, diff_bytes):
                if blob is not None:
                    extracted_members += 1
                    extracted_bytes += len(blob)
            item = {
                "relpath": rel,
                "classification": cls,
                "change_type": change_type,
                "manifest_dialect": e.get("dialect"),
                "baseline_present": bool(e.get("baseline_present")) or old_bytes is not None,
                "file_new_size": e.get("file_new_size") or (len(new_bytes) if new_bytes else None),
                "file_old_size": e.get("file_old_size") or (len(old_bytes) if old_bytes else None),
                "manifest_entry_id": e.get("entry_id"),
                "changed_functions_manifest": e.get("changed_functions", []),
                "payload_member": file_member,
                "baseline_member": base_member,
                "diff_member": diff_member,
            }
            old_text = old_bytes.decode("utf-8", "replace") if old_bytes else None
            new_text = new_bytes.decode("utf-8", "replace") if new_bytes else None
            if rel == "queuebash.sh" or rel.endswith(".py") or rel.endswith(".sh"):
                fc = diff_changed_functions(rel, old_text, new_text)
                item["function_analysis"] = fc
                function_changes.extend([dict(f, relpath=rel) for f in fc.get("functions", [])])
            for text, src_name in ((new_text, rel),):
                if text and src_name in {"README.md", "CHANGELOG.md", "queuebash.sh"}:
                    claim = extract_release_claim(text, src_name)
                    if claim:
                        release_claims.append(claim)
            if cls == "scratchpad_item_merge" and new_bytes:
                try:
                    sp = json.loads(new_bytes.decode("utf-8"))
                    scratchpad["items_added"] = len(sp.get("items", [])) if isinstance(sp, dict) else 0
                except Exception:
                    scratchpad["malformed"] += 1
            if cls == "delivery_evidence":
                evidence.append({"relpath": rel, "recommendation": "move_to_.queuebash/dev/deliveries/<delivery-id>/"})
            if new_bytes is None and change_type not in {"delete"}:
                warnings.append({"type": "missing_payload", "relpath": rel, "searched": candidate_members(root, rel, e.get("file"), "file")[:4]})
            entries_out.append(item)
        return {
            "name": src.name if root == "" else f"{src.name}:{root.rstrip('/')}",
            "path": str(src.origin_path) if src.origin_path else src.name,
            "container_member": src.container_member,
            "zip_bytes": src.size,
            "members_scanned": len(infos),
            "members_extracted": extracted_members,
            "extracted_bytes": extracted_bytes,
            "space_safety": "bounded",
            "patchset_root": root,
            "manifest_schema": manifest.get("schema"),
            "manifest_warnings": warnings,
            "created_at": manifest.get("created_at") or manifest.get("created_utc"),
            "summary": manifest.get("summary", {}),
            "entries": entries_out,
            "release_claims": release_claims,
            "function_changes": function_changes,
            "scratchpad": scratchpad,
            "delivery_evidence": evidence,
        }


def load_zip_source(path: Path, max_bytes: int) -> ZipSource:
    data = path.read_bytes()
    if len(data) > max_bytes * 20:
        # This limit is intentionally much higher than per-member extraction. The
        # central directory still controls what is read from the archive.
        pass
    return ZipSource(path.name, data, origin_path=path)


def analyse_zip_source(src: ZipSource, max_bytes: int) -> List[Dict[str, Any]]:
    with src.open() as z:
        roots = discover_patchset_roots(z)
        if roots:
            return [analyse_patchset_root(src, root, max_bytes) for root in roots]
        inner_infos = [i for i in z.infolist() if i.filename.endswith(".zip") and i.file_size <= max_bytes]
        if not inner_infos:
            raise SystemExit(f"queue dev merge-plan: no patchset manifest root found in {src.name}")
        out: List[Dict[str, Any]] = []
        for info in inner_infos:
            inner_data = z.read(info)
            inner = ZipSource(f"{src.name}!{info.filename}", inner_data, origin_path=src.origin_path, container_member=info.filename)
            try:
                child = analyse_zip_source(inner, max_bytes)
                for ps in child:
                    ps.setdefault("container", {"outer": src.name, "member": info.filename})
                    out.append(ps)
            except Exception as exc:
                out.append({
                    "name": f"{src.name}!{info.filename}",
                    "path": str(src.origin_path) if src.origin_path else src.name,
                    "container_member": info.filename,
                    "zip_bytes": info.file_size,
                    "members_scanned": len(z.infolist()),
                    "members_extracted": 1,
                    "extracted_bytes": info.file_size,
                    "space_safety": "bounded",
                    "patchset_root": None,
                    "manifest_schema": None,
                    "manifest_warnings": [{"type": "inner_patchset_unreadable", "reason": str(exc)}],
                    "created_at": None,
                    "summary": {},
                    "entries": [],
                    "release_claims": [],
                    "function_changes": [],
                    "scratchpad": {"items_added": 0, "malformed": 0, "strategy": "item_level_required"},
                    "delivery_evidence": [],
                })
        return out


def collision_report(patchsets: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    by_path: Dict[str, List[Tuple[Dict[str, Any], Dict[str, Any]]]] = defaultdict(list)
    by_path_func: Dict[Tuple[str, str], List[Tuple[Dict[str, Any], Dict[str, Any], Dict[str, Any]]]] = defaultdict(list)
    for ps in patchsets:
        for e in ps.get("entries", []):
            by_path[e["relpath"]].append((ps, e))
            fa = e.get("function_analysis", {})
            for f in fa.get("functions", []):
                by_path_func[(e["relpath"], f["function"])].append((ps, e, f))
    out = []
    for path, refs in sorted(by_path.items()):
        if len(refs) < 2:
            continue
        classes = {r[1]["classification"] for r in refs}
        if path == ".queuebash/dev/scratchpad.json":
            cls, risk = "scratchpad_distinct_items", "medium"
        elif classes <= {"docs_update", "release_identity_update"}:
            cls, risk = ("docs_release_overlap" if path in {"README.md", "CHANGELOG.md"} else "same_file_different_area"), "medium"
        elif path.startswith("tests/"):
            cls, risk = "test_only_overlap", "low"
        elif path == "queuebash.sh":
            cls, risk = "dispatcher_overlap", "high"
        else:
            cls, risk = "same_file_different_area", "medium"
        out.append({"path": path, "patchsets": [r[0]["name"] for r in refs], "classification": cls, "risk": risk})
    for (path, func), refs in sorted(by_path_func.items()):
        if len(refs) < 2:
            continue
        statuses = {r[2].get("status") for r in refs}
        cls = "same_function_different_change" if len(statuses) == 1 else "same_function_conflict"
        out.append({"path": path, "function": func, "patchsets": [r[0]["name"] for r in refs], "classification": cls, "risk": "high", "reason": "multiple patchsets touch the same function"})
    return out


def collect_release_claims(patchsets: List[Dict[str, Any]], target_version: Optional[str]) -> Dict[str, Any]:
    claims = []
    for ps in patchsets:
        for c in ps.get("release_claims", []):
            cc = dict(c)
            cc["patchset"] = ps["name"]
            if cc not in claims:
                claims.append(cc)
    versions = sorted({c["version"] for c in claims})
    overlaps = len(versions) < len(claims) or len(versions) > 1
    recommended = target_version or (versions[-1] if versions else "<set-by-merger>")
    return {"release_claims": claims, "versions_seen": versions, "recommended_version": recommended, "recommended_readme_heading": f"{recommended} BOB_MERGER multi-stream merge" if recommended != "<set-by-merger>" else "<target-version> BOB_MERGER multi-stream merge", "recommended_changelog_bullets": ["Merge safe additive docs, provider/helper files, tests and fixtures first.", "Manually reconcile same-path/function overlaps.", "Normalize README, CHANGELOG and QUEUEBASH_VERSION after merge scope is accepted."], "version_overlap_policy": "ledger_overlap_not_runtime_conflict", "release_identity_overlap": overlaps}


def classify_steps(patchsets: List[Dict[str, Any]], collisions: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    high_paths = {c.get("path") for c in collisions if c.get("risk") == "high"}
    medium_paths = {c.get("path") for c in collisions if c.get("risk") == "medium"}
    order = ["docs_update", "policy_update", "provider_update", "test_update", "add_file", "queuebash_function_update", "release_identity_update", "scratchpad_item_merge", "delivery_evidence", "unknown"]
    rank = {c: i for i, c in enumerate(order)}
    steps = []
    for ps in patchsets:
        for e in ps.get("entries", []):
            cls, rel = e["classification"], e["relpath"]
            if rel in high_paths or cls in {"queuebash_function_update", "release_identity_update"}:
                action = "manual_review_required"
            elif rel in medium_paths:
                action = "manual_review_required"
            elif cls == "scratchpad_item_merge":
                action = "manual_review_required"
            elif cls == "delivery_evidence":
                action = "defer"
            else:
                action = "auto_apply_safe"
            steps.append({"patchset": ps["name"], "relpath": rel, "classification": cls, "recommended_action": action, "order_rank": rank.get(cls, 99)})
    steps.sort(key=lambda s: (s["order_rank"], s["patchset"], s["relpath"]))
    for i, s in enumerate(steps, 1):
        s["step"] = i
        del s["order_rank"]
    return steps


def validation_plan(patchsets: List[Dict[str, Any]]) -> List[str]:
    cmds = {"bash -n queuebash.sh", "queue dev test qbtest --file queuebash.sh --list --json", "test ! -e assets.d/net_usage.sh"}
    for ps in patchsets:
        for e in ps.get("entries", []):
            rel = e["relpath"]
            if rel.startswith("tests/") and rel.endswith(".sh"):
                cmds.add(f"bash {rel}")
            if rel.startswith("tests/") and rel.endswith(".py"):
                cmds.add(f"python3 {rel}")
            if rel.endswith(".sh") and not rel.startswith("tests/"):
                cmds.add(f"bash -n {rel}")
            if rel.endswith(".py") and not rel.startswith("tests/"):
                cmds.add(f"python3 -m py_compile {rel}")
            fa = e.get("function_analysis", {})
            for f in fa.get("functions", []):
                if rel == "queuebash.sh":
                    cmds.add(f"queue dev test qbtest --file queuebash.sh --function {f['function']} --json")
    cmds.add("find . -name __pycache__ -o -name '*.pyc' -o -name '*.dev.lock' -o -name '*.devpatch.*'")
    return sorted(cmds)


def build_plan(args: argparse.Namespace) -> Dict[str, Any]:
    base = Path(args.base).resolve()
    if not base.exists():
        raise SystemExit(f"queue dev merge-plan: base does not exist: {base}")
    patchsets: List[Dict[str, Any]] = []
    for p in args.patchset:
        patchsets.extend(analyse_zip_source(load_zip_source(Path(p), args.max_bytes), args.max_bytes))
    collisions = collision_report(patchsets)
    release = collect_release_claims(patchsets, args.target_version)
    steps = classify_steps(patchsets, collisions)
    warnings = []
    for ps in patchsets:
        warnings.extend([dict(w, patchset=ps["name"]) for w in ps.get("manifest_warnings", [])])
        if not ps.get("entries"):
            warnings.append({"type": "zero_entry_patchset", "patchset": ps["name"], "reason": "normalised patchset has no entries"})
    summary = {"patchsets": len(patchsets), "entries": sum(len(p.get("entries", [])) for p in patchsets), "collisions": len(collisions), "high_risk_collisions": sum(1 for c in collisions if c.get("risk") == "high"), "auto_apply_safe_steps": sum(1 for s in steps if s["recommended_action"] == "auto_apply_safe"), "manual_review_steps": sum(1 for s in steps if s["recommended_action"] == "manual_review_required"), "warnings": len(warnings)}
    return {"schema": SCHEMA, "status": "ok", "mode": "read_only_plan", "base": str(base), "target_version": args.target_version, "summary": summary, "warnings": warnings, "patchsets": patchsets, "collisions": collisions, "release_reconciliation": release, "merge_plan": steps, "validation_plan": validation_plan(patchsets), "non_goals": ["no automatic conflict resolution", "no full tree unzip by default", "no automatic writes to target tree", "no scratchpad wholesale merge recommendation", "no assumption that newer version number means newer code"]}


def emit_human(plan: Dict[str, Any]) -> None:
    s = plan["summary"]
    print(f"Merge plan: {s['patchsets']} patchset(s) against {plan['base']}")
    print(f"Entries: {s['entries']}  Collisions: {s['collisions']}  High risk: {s['high_risk_collisions']}  Warnings: {s.get('warnings',0)}")
    print("")
    safe = [x for x in plan["merge_plan"] if x["recommended_action"] == "auto_apply_safe"][:10]
    print("Safe:")
    for x in safe:
        print(f"  + {x['relpath']} ({x['classification']}) from {x['patchset']}")
    if not safe:
        print("  none")
    print("Manual:")
    for c in plan["collisions"][:10]:
        label = c.get("function") or c.get("path")
        print(f"  ! {label}: {c['classification']} risk={c.get('risk','unknown')}")
    if not plan["collisions"]:
        print("  none")
    if plan.get("warnings"):
        print("Warnings:")
        for w in plan["warnings"][:10]:
            print(f"  ? {w.get('patchset')}: {w.get('type')} {w.get('reason','')}")
    rr = plan["release_reconciliation"]
    print("")
    print(f"Release: {rr['version_overlap_policy']}; recommended={rr['recommended_version']}")
    print("Recommended order:")
    labels = ["docs/policies", "providers/helpers", "tests/fixtures", "standalone files", "queuebash functions", "dispatcher/help", "README/CHANGELOG", "scratchpad item merge", "delivery evidence relocation", "validation"]
    for i, label in enumerate(labels, 1):
        print(f"  {i}. {label}")


def cmd_explain(path: str, json_mode: bool) -> int:
    plan = json.loads(Path(path).read_text(encoding="utf-8"))
    if json_mode:
        print(json.dumps(plan, sort_keys=True, indent=2))
    else:
        emit_human(plan)
    return 0


def cmd_summary(path: str, json_mode: bool) -> int:
    plan = json.loads(Path(path).read_text(encoding="utf-8"))
    out = {"schema": "queuebash.dev_merge_plan_summary.v1", "status": plan.get("status"), "summary": plan.get("summary", {}), "warnings": plan.get("warnings", [])[:20], "collisions": plan.get("collisions", [])[:20], "release_reconciliation": plan.get("release_reconciliation", {})}
    if json_mode:
        print(json.dumps(out, sort_keys=True, separators=(",", ":")))
    else:
        print(f"patchsets={out['summary'].get('patchsets')} entries={out['summary'].get('entries')} collisions={out['summary'].get('collisions')} warnings={out['summary'].get('warnings')}")
        for c in out["collisions"][:10]:
            print(f"{c.get('risk','?')}\t{c.get('classification')}\t{c.get('function') or c.get('path')}")
    return 0


def main(argv: Optional[List[str]] = None) -> int:
    argv = list(argv or sys.argv[1:])
    if argv and argv[0] in {"explain", "summary"}:
        sub = argv.pop(0)
        p = argparse.ArgumentParser(prog=f"queue dev merge-plan {sub}")
        p.add_argument("plan_json")
        p.add_argument("--json", action="store_true")
        ns = p.parse_args(argv)
        return cmd_explain(ns.plan_json, ns.json) if sub == "explain" else cmd_summary(ns.plan_json, ns.json)
    p = argparse.ArgumentParser(prog="queue dev merge-plan")
    p.add_argument("--base", required=True)
    p.add_argument("--patchset", action="append", required=True)
    p.add_argument("--full-delivery", action="append", default=[])
    p.add_argument("--target-version", default=None)
    p.add_argument("--json", action="store_true")
    p.add_argument("--human", action="store_true")
    p.add_argument("--extract-dir", default=None)
    p.add_argument("--max-bytes", type=int, default=DEFAULT_MAX_BYTES)
    p.add_argument("--keep-workdir", action="store_true")
    p.add_argument("--extract-all", action="store_true")
    ns = p.parse_args(argv)
    plan = build_plan(ns)
    if ns.json:
        print(json.dumps(plan, sort_keys=True, separators=(",", ":")))
    else:
        emit_human(plan)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
