#!/usr/bin/env python3
"""Read-only hash inventory helper for bashqueues display/XML resources.

The helper records SHA-256 evidence for manifest-listed display/XML resources.
It never signs resources, renders templates, substitutes token values, calls
providers, reads secrets, or mutates install state.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
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


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


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
            entries.append(ManifestEntry(*row, manifest_path=rel, manifest_line=lineno))
    return entries, findings


def _inventory_resource(root: Path, entry: ManifestEntry, findings: list[Finding]) -> dict[str, object]:
    path = _resource_path(root, entry)
    rel = _rel(root, path)
    exists = path.exists()
    is_symlink = path.is_symlink()
    is_regular = path.is_file() if exists else False
    mode = _mode_string(path)
    size: int | None = None
    sha256: str | None = None
    status = "ok"
    if entry.resource_type not in VALID_TYPE:
        status = "error"
        findings.append(Finding("error", entry.manifest_path, "resource_type_invalid", f"unsupported resource_type: {entry.resource_type}"))
    if entry.json_contract_source != "false":
        status = "error"
        findings.append(Finding("error", entry.manifest_path, "json_contract_source", "display/XML resources must not be JSON contract sources"))
    if entry.secret_rendering_allowed != "false":
        status = "error"
        findings.append(Finding("error", entry.manifest_path, "secret_rendering_allowed", "display/XML resources must not render secrets"))
    if not exists:
        status = "missing"
        findings.append(Finding("error", rel, "resource_missing", "manifest-listed resource is missing"))
    elif is_symlink:
        status = "error"
        findings.append(Finding("error", rel, "resource_symlink", "resource must not be a symlink for hash inventory"))
    elif not is_regular:
        status = "error"
        findings.append(Finding("error", rel, "resource_not_regular_file", "resource must be a regular file for hash inventory"))
    else:
        st = path.stat()
        size = st.st_size
        sha256 = _sha256_file(path)
    return {
        "resource_type": entry.resource_type,
        "name": entry.name,
        "language": entry.language,
        "path": rel,
        "manifest_path": entry.manifest_path,
        "manifest_line": entry.manifest_line,
        "exists": exists,
        "is_regular_file": is_regular,
        "is_symlink": is_symlink,
        "mode": mode,
        "size_bytes": size,
        "sha256": sha256,
        "hash_status": status,
        "fallback_required": entry.fallback_required,
        "tokens_declared": [t for t in entry.tokens.split(",") if t] if entry.tokens else [],
        "surface": entry.surface,
    }


def build_inventory(root: Path) -> dict[str, object]:
    root = root.resolve()
    findings: list[Finding] = []
    entries: list[ManifestEntry] = []
    manifest_hashes: list[dict[str, object]] = []
    for resource_type in ("display", "xml"):
        manifest = _manifest_path(root, resource_type)
        if manifest.exists() and manifest.is_file() and not manifest.is_symlink():
            manifest_hashes.append({
                "resource_type": resource_type,
                "path": _rel(root, manifest),
                "exists": True,
                "is_regular_file": True,
                "is_symlink": False,
                "mode": _mode_string(manifest),
                "size_bytes": manifest.stat().st_size,
                "sha256": _sha256_file(manifest),
                "hash_status": "ok",
            })
        else:
            manifest_hashes.append({
                "resource_type": resource_type,
                "path": _rel(root, manifest),
                "exists": manifest.exists(),
                "is_regular_file": manifest.is_file() if manifest.exists() else False,
                "is_symlink": manifest.is_symlink(),
                "mode": _mode_string(manifest),
                "size_bytes": None,
                "sha256": None,
                "hash_status": "missing" if not manifest.exists() else "error",
            })
        manifest_entries, manifest_findings = _read_manifest(root, manifest)
        entries.extend(manifest_entries)
        findings.extend(manifest_findings)

    seen_keys: set[tuple[str, str, str]] = set()
    resources: list[dict[str, object]] = []
    for entry in entries:
        key = (entry.resource_type, entry.language, entry.name)
        if key in seen_keys:
            findings.append(Finding("error", f"{entry.manifest_path}:{entry.manifest_line}", "duplicate_resource_entry", "duplicate resource/language/name manifest entry"))
            continue
        seen_keys.add(key)
        resources.append(_inventory_resource(root, entry, findings))

    ok_resources = sum(1 for item in resources if item["hash_status"] == "ok")
    missing_resources = sum(1 for item in resources if item["hash_status"] == "missing")
    error_resources = sum(1 for item in resources if item["hash_status"] == "error")
    status = "ok" if not any(f.level == "error" for f in findings) else "error"
    return {
        "schema": "queuebash.display_resource_hash_inventory.v1",
        "status": status,
        "root": str(root),
        "redacted": True,
        "owner_lane": "bob18-display-resources",
        "renderer": "none-hash-inventory-only",
        "source": "manifest-listed-files-and-sha256-only",
        "read_only": True,
        "installer": False,
        "signing_mutation": False,
        "json_contract_source": False,
        "secret_rendering_allowed": False,
        "token_value_substitution": False,
        "permission_mutation": False,
        "hash_algorithm": "sha256",
        "stats": {
            "manifest_files": len(manifest_hashes),
            "manifest_entries": len(entries),
            "resource_files": len(resources),
            "resource_hashes_ok": ok_resources,
            "resource_hashes_missing": missing_resources,
            "resource_hashes_error": error_resources,
            "findings": len(findings),
        },
        "manifests": manifest_hashes,
        "resources": resources,
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
    parser = argparse.ArgumentParser(description="Build a read-only SHA-256 inventory for bashqueues display/XML resources")
    parser.add_argument("--root", default=".", help="repository or installed root containing resources.d")
    parser.add_argument("--json", action="store_true", help="emit queuebash.display_resource_hash_inventory.v1 JSON")
    args = parser.parse_args(list(argv) if argv is not None else None)
    payload = build_inventory(Path(args.root))
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        stats = payload["stats"]
        print(f"display resource hash inventory: {payload['status']} ({stats['resource_hashes_ok']}/{stats['resource_files']} resources hashed)")
        for finding in payload["findings"]:
            print(f"{finding['level']}\t{finding['code']}\t{finding['path']}\t{finding['message']}")
    return 0 if payload["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
