#!/usr/bin/env python3
"""Read-only orphan audit helper for bashqueues display/XML resources.

The helper compares manifest rows with resource files present under resources.d.
It reports unmanifested/orphan files and duplicate manifest entries without
rendering templates, substituting tokens, reading secrets, signing, installing,
or mutating permissions.
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
IGNORED_FILENAMES = {"manifest.example.tsv"}


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
    manifest_line: int


def _rel(root: Path, path: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def _manifest_path(root: Path, resource_type: str) -> Path:
    return root / "resources.d" / resource_type / "manifest.example.tsv"


def _resource_path(root: Path, entry: ManifestEntry) -> Path:
    return root / "resources.d" / entry.resource_type / entry.language / entry.name


def _mode_string(path: Path) -> str | None:
    try:
        return stat.filemode(path.lstat().st_mode)
    except FileNotFoundError:
        return None


def _read_manifest(root: Path, path: Path) -> tuple[list[ManifestEntry], list[Finding]]:
    entries: list[ManifestEntry] = []
    findings: list[Finding] = []
    rel = _rel(root, path)
    if not path.exists():
        findings.append(Finding("error", rel, "manifest_missing", "manifest is not present"))
        return entries, findings
    if path.is_symlink():
        findings.append(Finding("error", rel, "manifest_symlink", "manifest must not be a symlink"))
        return entries, findings
    if not path.is_file():
        findings.append(Finding("error", rel, "manifest_not_regular_file", "manifest must be a regular file"))
        return entries, findings
    with path.open(newline="") as fh:
        for lineno, raw in enumerate(fh, start=1):
            if not raw.strip() or raw.startswith("#"):
                continue
            where = f"{rel}:{lineno}"
            if SHELL_RE.search(raw):
                findings.append(Finding("error", where, "manifest_shell_expansion", "manifest contains shell-looking expansion"))
            if SECRET_VALUE_RE.search(raw):
                findings.append(Finding("error", where, "manifest_secret_value", "manifest appears to contain a concrete secret value"))
            row = next(csv.reader([raw], delimiter="\t"))
            if len(row) != 9:
                findings.append(Finding("error", where, "manifest_row_width", "manifest row must contain nine TSV fields"))
                continue
            entry = ManifestEntry(*row, manifest_path=rel, manifest_line=lineno)
            if entry.resource_type not in VALID_TYPE:
                findings.append(Finding("error", where, "resource_type_invalid", f"unsupported resource_type: {entry.resource_type}"))
            if entry.json_contract_source != "false":
                findings.append(Finding("error", where, "json_contract_source", "display/XML resources must not be JSON contract sources"))
            if entry.secret_rendering_allowed != "false":
                findings.append(Finding("error", where, "secret_rendering_allowed", "display/XML resources must not render secrets"))
            entries.append(entry)
    return entries, findings


def _discover_resource_files(root: Path, resource_type: str, findings: list[Finding]) -> list[dict[str, object]]:
    base = root / "resources.d" / resource_type
    discovered: list[dict[str, object]] = []
    if not base.exists():
        findings.append(Finding("error", _rel(root, base), "resource_root_missing", f"resources.d/{resource_type} is missing"))
        return discovered
    if base.is_symlink() or not base.is_dir():
        findings.append(Finding("error", _rel(root, base), "resource_root_invalid", f"resources.d/{resource_type} must be a real directory"))
        return discovered
    for path in sorted(base.rglob("*")):
        if path.name in IGNORED_FILENAMES:
            continue
        rel = _rel(root, path)
        try:
            language = path.relative_to(base).parts[0]
        except IndexError:
            language = ""
        if path.is_dir():
            continue
        item = {
            "resource_type": resource_type,
            "language": language,
            "name": str(path.relative_to(base / language)) if language else path.name,
            "path": rel,
            "exists": path.exists(),
            "is_regular_file": path.is_file(),
            "is_symlink": path.is_symlink(),
            "mode": _mode_string(path),
        }
        if path.is_symlink():
            findings.append(Finding("error", rel, "resource_symlink", "resource file must not be a symlink"))
        elif not path.is_file():
            findings.append(Finding("error", rel, "resource_not_regular_file", "resource path must be a regular file"))
        discovered.append(item)
    return discovered


def build_audit(root: Path) -> dict[str, object]:
    root = root.resolve()
    findings: list[Finding] = []
    entries: list[ManifestEntry] = []
    for resource_type in ("display", "xml"):
        manifest_entries, manifest_findings = _read_manifest(root, _manifest_path(root, resource_type))
        entries.extend(manifest_entries)
        findings.extend(manifest_findings)

    manifest_keys: set[tuple[str, str, str]] = set()
    duplicate_entries: list[dict[str, object]] = []
    missing_manifest_files: list[dict[str, object]] = []
    manifest_entries_json: list[dict[str, object]] = []
    for entry in entries:
        key = (entry.resource_type, entry.language, entry.name)
        resource_path = _resource_path(root, entry)
        item = {
            "resource_type": entry.resource_type,
            "language": entry.language,
            "name": entry.name,
            "path": _rel(root, resource_path),
            "manifest_path": entry.manifest_path,
            "manifest_line": entry.manifest_line,
            "fallback_required": entry.fallback_required,
            "tokens_declared": [t for t in entry.tokens.split(",") if t] if entry.tokens else [],
            "surface": entry.surface,
        }
        manifest_entries_json.append(item)
        if key in manifest_keys:
            duplicate_entries.append(item)
            findings.append(Finding("error", f"{entry.manifest_path}:{entry.manifest_line}", "duplicate_manifest_entry", "duplicate resource_type/language/name manifest entry"))
        else:
            manifest_keys.add(key)
        if not resource_path.exists():
            missing_manifest_files.append(item)
            findings.append(Finding("error", _rel(root, resource_path), "manifested_resource_missing", "manifest row references a missing resource file"))

    discovered_files: list[dict[str, object]] = []
    for resource_type in ("display", "xml"):
        discovered_files.extend(_discover_resource_files(root, resource_type, findings))

    orphan_files: list[dict[str, object]] = []
    for item in discovered_files:
        key = (str(item["resource_type"]), str(item["language"]), str(item["name"]))
        if key not in manifest_keys:
            orphan_files.append(item)
            findings.append(Finding("warning", str(item["path"]), "unmanifested_resource_file", "resource file is not represented by the display/XML manifest"))

    status = "error" if any(f.level == "error" for f in findings) else ("warning" if any(f.level == "warning" for f in findings) else "ok")
    return {
        "schema": "queuebash.display_resource_orphan_audit.v1",
        "status": status,
        "root": str(root),
        "redacted": True,
        "owner_lane": "bob18-display-resources",
        "renderer": "none-orphan-audit-only",
        "source": "manifest-rows-and-resource-file-presence-only",
        "read_only": True,
        "installer": False,
        "signing_mutation": False,
        "permission_mutation": False,
        "json_contract_source": False,
        "secret_rendering_allowed": False,
        "token_value_substitution": False,
        "file_content_read": False,
        "stats": {
            "manifest_entries": len(entries),
            "discovered_resource_files": len(discovered_files),
            "orphan_resource_files": len(orphan_files),
            "missing_manifest_resources": len(missing_manifest_files),
            "duplicate_manifest_entries": len(duplicate_entries),
            "findings": len(findings),
        },
        "manifest_entries": manifest_entries_json,
        "discovered_resource_files": discovered_files,
        "orphan_resource_files": orphan_files,
        "missing_manifest_resources": missing_manifest_files,
        "duplicate_manifest_entries": duplicate_entries,
        "forbidden": [
            "resource_rendering",
            "token_substitution",
            "secret_values",
            "provider_credentials",
            "command_json_generation_from_templates",
            "signing_mutation",
            "install_mutation",
            "permission_mutation",
            "eval",
            "source",
            "shell_expansion",
        ],
        "findings": [asdict(f) for f in findings],
    }


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Audit unmanifested/orphan bashqueues display/XML resources")
    parser.add_argument("--root", default=".", help="repository or installed root containing resources.d")
    parser.add_argument("--json", action="store_true", help="emit queuebash.display_resource_orphan_audit.v1 JSON")
    args = parser.parse_args(list(argv) if argv is not None else None)
    payload = build_audit(Path(args.root))
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        stats = payload["stats"]
        print(
            "display resource orphan audit: "
            f"{payload['status']} ({stats['orphan_resource_files']} orphan files, "
            f"{stats['missing_manifest_resources']} missing manifest resources)"
        )
        for finding in payload["findings"]:
            print(f"{finding['level']}\t{finding['code']}\t{finding['path']}\t{finding['message']}")
    return 1 if payload["status"] == "error" else 0


if __name__ == "__main__":
    raise SystemExit(main())
