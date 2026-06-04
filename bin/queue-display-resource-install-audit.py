#!/usr/bin/env python3
"""Read-only installed-resource audit helper for bashqueues display/XML resources.

The helper compares bundled/source display/XML manifest entries with an installed
resource tree. It is release-review evidence only: it does not install files,
sign files, render templates, substitute tokens, or read secret values.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
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
            if SHELL_RE.search(raw):
                findings.append(Finding("error", f"{_rel(root, path)}:{lineno}", "manifest_shell_expansion", "manifest contains shell-looking expansion"))
            if SECRET_VALUE_RE.search(raw):
                findings.append(Finding("error", f"{_rel(root, path)}:{lineno}", "manifest_secret_value", "manifest appears to contain a concrete secret value"))
            row = next(csv.reader([raw], delimiter="\t"))
            if len(row) != 9:
                findings.append(Finding("error", f"{_rel(root, path)}:{lineno}", "manifest_row_width", "manifest row must contain nine TSV fields"))
                continue
            entries.append(ManifestEntry(*row, manifest_path=_rel(root, path)))
    return entries, findings


def _rel(root: Path, path: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def _resource_path(root: Path, entry: ManifestEntry) -> Path:
    return root / "resources.d" / entry.resource_type / entry.language / entry.name


def _manifest_path(root: Path, resource_type: str) -> Path:
    return root / "resources.d" / resource_type / "manifest.example.tsv"


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _validate_entry(entry: ManifestEntry, source_root: Path, findings: list[Finding]) -> None:
    where = entry.manifest_path
    if entry.resource_type not in VALID_TYPE:
        findings.append(Finding("error", where, "resource_type_invalid", f"unsupported resource_type: {entry.resource_type}"))
    if entry.fallback_required not in {"yes", "no"}:
        findings.append(Finding("error", where, "fallback_required_invalid", "fallback_required must be yes or no"))
    if entry.json_contract_source != "false":
        findings.append(Finding("error", where, "json_contract_source", "display/XML resources must not be JSON contract sources"))
    if entry.secret_rendering_allowed != "false":
        findings.append(Finding("error", where, "secret_rendering_allowed", "display/XML resources must not render secrets"))
    source_file = _resource_path(source_root, entry)
    if not source_file.exists():
        findings.append(Finding("error", _rel(source_root, source_file), "source_resource_missing", "source manifest entry references a missing resource"))


def audit_install(source_root: Path, installed_root: Path) -> dict[str, object]:
    source_root = source_root.resolve()
    installed_root = installed_root.resolve()
    findings: list[Finding] = []
    source_entries: list[ManifestEntry] = []

    for resource_type in ("display", "xml"):
        entries, manifest_findings = _read_manifest(source_root, _manifest_path(source_root, resource_type))
        source_entries.extend(entries)
        findings.extend(manifest_findings)
        installed_manifest = _manifest_path(installed_root, resource_type)
        source_manifest = _manifest_path(source_root, resource_type)
        if not installed_manifest.exists():
            findings.append(Finding("error", _rel(installed_root, installed_manifest), "installed_manifest_missing", "installed manifest is missing"))
        elif source_manifest.exists() and _sha256(source_manifest) != _sha256(installed_manifest):
            findings.append(Finding("error", _rel(installed_root, installed_manifest), "installed_manifest_hash_mismatch", "installed manifest differs from source manifest"))

    resources: list[dict[str, object]] = []
    installed_ok = 0
    for entry in source_entries:
        _validate_entry(entry, source_root, findings)
        source_file = _resource_path(source_root, entry)
        installed_file = _resource_path(installed_root, entry)
        source_exists = source_file.exists()
        installed_exists = installed_file.exists()
        hash_match = False
        source_hash = None
        installed_hash = None
        if source_exists:
            source_hash = _sha256(source_file)
        if installed_exists:
            installed_hash = _sha256(installed_file)
        if source_hash and installed_hash:
            hash_match = source_hash == installed_hash
        if not installed_exists:
            findings.append(Finding("error", _rel(installed_root, installed_file), "installed_resource_missing", "installed resource is missing"))
        elif not hash_match:
            findings.append(Finding("error", _rel(installed_root, installed_file), "installed_resource_hash_mismatch", "installed resource differs from source resource"))
        else:
            installed_ok += 1
        resources.append({
            "type": entry.resource_type,
            "name": entry.name,
            "language": entry.language,
            "source_path": _rel(source_root, source_file),
            "installed_path": _rel(installed_root, installed_file),
            "source_present": source_exists,
            "installed_present": installed_exists,
            "sha256_match": hash_match,
            "source_sha256": source_hash,
            "installed_sha256": installed_hash,
            "json_contract_source": False,
            "secret_rendering_allowed": False,
        })

    status = "ok" if not any(f.level == "error" for f in findings) else "error"
    return {
        "schema": "queuebash.display_resource_install_audit.v1",
        "status": status,
        "source_root": str(source_root),
        "installed_root": str(installed_root),
        "redacted": True,
        "owner_lane": "bob18-display-resources",
        "renderer": "none-install-audit-only",
        "source": "manifest-metadata-and-file-hash-presence-only",
        "read_only": True,
        "installer": False,
        "signing_mutation": False,
        "json_contract_source": False,
        "secret_rendering_allowed": False,
        "token_value_substitution": False,
        "stats": {
            "resources_declared": len(source_entries),
            "resources_installed_ok": installed_ok,
            "findings": len(findings),
        },
        "resources": resources,
        "forbidden": [
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
    parser = argparse.ArgumentParser(description="Audit installed bashqueues display/XML resource copies")
    parser.add_argument("--source-root", default=".", help="repository/source root to compare from")
    parser.add_argument("--installed-root", required=True, help="installed root to compare against")
    parser.add_argument("--json", action="store_true", help="emit queuebash.display_resource_install_audit.v1 JSON")
    args = parser.parse_args(list(argv) if argv is not None else None)

    payload = audit_install(Path(args.source_root), Path(args.installed_root))
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        stats = payload["stats"]
        print(f"display resource install audit: {payload['status']} ({stats['resources_installed_ok']}/{stats['resources_declared']} resources installed ok)")
        for finding in payload["findings"]:
            print(f"{finding['level']}\t{finding['code']}\t{finding['path']}\t{finding['message']}")
    return 0 if payload["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
