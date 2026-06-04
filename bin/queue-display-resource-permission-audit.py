#!/usr/bin/env python3
"""Read-only permission audit helper for bashqueues display/XML resources.

The helper checks reviewed display/XML resource files and manifests for safe
presentation-resource permissions. It never renders templates, substitutes
values, calls providers, verifies signatures, or mutates install state.
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import stat
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

SHELL_RE = re.compile(r"\$\{|\$\(|`")
SECRET_VALUE_RE = re.compile(r"(?i)(actual[-_ ]?secret|secret[-_ ]?value|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16})")
VALID_TYPE = {"display", "xml"}


@dataclass
class Finding:
    level: str
    path: str
    code: str
    message: str


@dataclass(frozen=True)
class ManifestEntry:
    resource_type: str
    name: str
    language: str
    fallback_required: str
    tokens: str
    surface: str
    json_contract_source: str
    secret_rendering_allowed: str
    notes: str
    manifest_path: str


def _rel(root: Path, path: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def _manifest_path(root: Path, resource_type: str) -> Path:
    return root / "resources.d" / resource_type / "manifest.example.tsv"


def _resource_path(root: Path, entry: ManifestEntry) -> Path:
    return root / "resources.d" / entry.resource_type / entry.language / entry.name


def _read_manifest(root: Path, path: Path) -> tuple[list[ManifestEntry], list[Finding]]:
    entries: list[ManifestEntry] = []
    findings: list[Finding] = []
    if not path.exists():
        findings.append(Finding("error", _rel(root, path), "manifest_missing", "manifest is not present"))
        return entries, findings
    with path.open(newline="") as fh:
        for lineno, raw in enumerate(fh, start=1):
            if not raw.strip() or raw.startswith("#"):
                continue
            where = f"{_rel(root, path)}:{lineno}"
            if SHELL_RE.search(raw):
                findings.append(Finding("error", where, "manifest_shell_expansion", "manifest contains shell-looking expansion"))
            if SECRET_VALUE_RE.search(raw):
                findings.append(Finding("error", where, "manifest_secret_value", "manifest appears to contain a concrete secret value"))
            row = next(csv.reader([raw], delimiter="\t"))
            if len(row) != 9:
                findings.append(Finding("error", where, "manifest_row_width", "manifest row must contain nine TSV fields"))
                continue
            entry = ManifestEntry(*row, manifest_path=_rel(root, path))
            entries.append(entry)
    return entries, findings


def _mode_string(path: Path) -> str | None:
    try:
        return stat.filemode(path.lstat().st_mode)
    except FileNotFoundError:
        return None


def _check_file_permissions(root: Path, path: Path, role: str, findings: list[Finding]) -> dict[str, object]:
    rel = _rel(root, path)
    exists = path.exists()
    mode = _mode_string(path)
    is_file = path.is_file() if exists else False
    is_symlink = path.is_symlink()
    executable = False
    group_writable = False
    world_writable = False
    readable_by_owner = False
    if exists:
        st_mode = path.lstat().st_mode
        executable = bool(st_mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH))
        group_writable = bool(st_mode & stat.S_IWGRP)
        world_writable = bool(st_mode & stat.S_IWOTH)
        readable_by_owner = bool(st_mode & stat.S_IRUSR)
        if is_symlink:
            findings.append(Finding("error", rel, "resource_symlink", f"{role} must not be a symlink"))
        if not is_file:
            findings.append(Finding("error", rel, "resource_not_regular_file", f"{role} must be a regular file"))
        if executable:
            findings.append(Finding("error", rel, "resource_executable", f"{role} must not be executable"))
        if group_writable:
            findings.append(Finding("error", rel, "resource_group_writable", f"{role} must not be group-writable"))
        if world_writable:
            findings.append(Finding("error", rel, "resource_world_writable", f"{role} must not be world-writable"))
        if not readable_by_owner:
            findings.append(Finding("error", rel, "resource_not_owner_readable", f"{role} must be owner-readable"))
    else:
        findings.append(Finding("error", rel, "resource_missing", f"{role} is missing"))
    return {
        "path": rel,
        "role": role,
        "exists": exists,
        "is_regular_file": is_file,
        "is_symlink": is_symlink,
        "mode": mode,
        "owner_readable": readable_by_owner,
        "executable": executable,
        "group_writable": group_writable,
        "world_writable": world_writable,
    }


def audit_permissions(root: Path) -> dict[str, object]:
    root = root.resolve()
    findings: list[Finding] = []
    entries: list[ManifestEntry] = []
    checked_files: list[dict[str, object]] = []

    for resource_type in ("display", "xml"):
        manifest = _manifest_path(root, resource_type)
        checked_files.append(_check_file_permissions(root, manifest, "manifest", findings))
        manifest_entries, manifest_findings = _read_manifest(root, manifest)
        entries.extend(manifest_entries)
        findings.extend(manifest_findings)

    seen: set[Path] = set()
    for entry in entries:
        if entry.resource_type not in VALID_TYPE:
            findings.append(Finding("error", entry.manifest_path, "resource_type_invalid", f"unsupported resource_type: {entry.resource_type}"))
            continue
        if entry.json_contract_source != "false":
            findings.append(Finding("error", entry.manifest_path, "json_contract_source", "display/XML resources must not be JSON contract sources"))
        if entry.secret_rendering_allowed != "false":
            findings.append(Finding("error", entry.manifest_path, "secret_rendering_allowed", "display/XML resources must not render secrets"))
        resource = _resource_path(root, entry)
        if resource in seen:
            continue
        seen.add(resource)
        checked_files.append(_check_file_permissions(root, resource, "resource", findings))

    stats = {
        "manifest_files_checked": sum(1 for item in checked_files if item["role"] == "manifest"),
        "resource_files_checked": sum(1 for item in checked_files if item["role"] == "resource"),
        "files_checked": len(checked_files),
        "findings": len(findings),
        "executable_files": sum(1 for item in checked_files if item["executable"]),
        "group_writable_files": sum(1 for item in checked_files if item["group_writable"]),
        "world_writable_files": sum(1 for item in checked_files if item["world_writable"]),
        "symlink_files": sum(1 for item in checked_files if item["is_symlink"]),
    }
    status = "ok" if not any(f.level == "error" for f in findings) else "error"
    return {
        "schema": "queuebash.display_resource_permission_audit.v1",
        "status": status,
        "root": str(root),
        "redacted": True,
        "owner_lane": "bob18-display-resources",
        "renderer": "none-permission-audit-only",
        "source": "manifest-metadata-and-filesystem-mode-only",
        "read_only": True,
        "installer": False,
        "signing_mutation": False,
        "json_contract_source": False,
        "secret_rendering_allowed": False,
        "token_value_substitution": False,
        "permission_mutation": False,
        "required_file_properties": {
            "regular_file": True,
            "symlink_allowed": False,
            "executable_allowed": False,
            "group_writable_allowed": False,
            "world_writable_allowed": False,
            "owner_readable_required": True,
        },
        "stats": stats,
        "files": checked_files,
        "forbidden": [
            "chmod_mutation",
            "install_mutation",
            "signing_mutation",
            "resource_rendering",
            "token_substitution",
            "secret_values",
            "provider_credentials",
            "command_json_generation_from_templates",
            "eval",
            "source",
            "shell_expansion",
        ],
        "findings": [asdict(f) for f in findings],
    }


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Audit bashqueues display/XML resource file permissions")
    parser.add_argument("--root", default=".", help="repository or installed root containing resources.d")
    parser.add_argument("--json", action="store_true", help="emit queuebash.display_resource_permission_audit.v1 JSON")
    args = parser.parse_args(list(argv) if argv is not None else None)

    payload = audit_permissions(Path(args.root))
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        stats = payload["stats"]
        print(f"display resource permission audit: {payload['status']} ({stats['files_checked']} files checked)")
        for finding in payload["findings"]:
            print(f"{finding['level']}\t{finding['code']}\t{finding['path']}\t{finding['message']}")
    return 0 if payload["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
