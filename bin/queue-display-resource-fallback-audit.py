#!/usr/bin/env python3
"""Read-only fallback audit helper for bashqueues display/XML resources.

The helper reads display/XML manifest metadata and file presence only. It is not
an i18n renderer and never reads resource bodies for display, token
replacement, provider data, or secret values.
"""
from __future__ import annotations

import argparse
import csv
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


def _read_manifest(path: Path) -> tuple[list[ManifestEntry], list[Finding]]:
    entries: list[ManifestEntry] = []
    findings: list[Finding] = []
    if not path.exists():
        findings.append(Finding("warning", str(path), "manifest_missing", "manifest is not present"))
        return entries, findings
    with path.open(newline="") as fh:
        for lineno, raw in enumerate(fh, start=1):
            if not raw.strip() or raw.startswith("#"):
                continue
            if SHELL_RE.search(raw):
                findings.append(Finding("error", f"{path}:{lineno}", "manifest_shell_expansion", "manifest contains shell-looking expansion"))
            if SECRET_VALUE_RE.search(raw):
                findings.append(Finding("error", f"{path}:{lineno}", "manifest_secret_value", "manifest appears to contain a concrete secret value"))
            row = next(csv.reader([raw], delimiter="\t"))
            if len(row) != 9:
                findings.append(Finding("error", f"{path}:{lineno}", "manifest_row_width", "manifest row must contain nine TSV fields"))
                continue
            resource_type, name, language, fallback_required, tokens, surface, json_source, secret_allowed, notes = row
            entries.append(ManifestEntry(resource_type, name, language, fallback_required, tokens, surface, json_source, secret_allowed, notes, str(path)))
    return entries, findings


def _resource_path(root: Path, resource_type: str, language: str, name: str) -> Path:
    return root / "resources.d" / resource_type / language / name


def _rel(root: Path, path: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def audit_fallbacks(root: Path) -> dict[str, object]:
    manifests = [
        root / "resources.d" / "display" / "manifest.example.tsv",
        root / "resources.d" / "xml" / "manifest.example.tsv",
    ]
    findings: list[Finding] = []
    entries: list[ManifestEntry] = []
    for manifest in manifests:
        manifest_entries, manifest_findings = _read_manifest(manifest)
        entries.extend(manifest_entries)
        findings.extend(manifest_findings)

    grouped: dict[tuple[str, str], list[ManifestEntry]] = {}
    for entry in entries:
        grouped.setdefault((entry.resource_type, entry.name), []).append(entry)
        if entry.resource_type not in VALID_TYPE:
            findings.append(Finding("error", entry.manifest_path, "resource_type_invalid", f"unsupported resource_type: {entry.resource_type}"))
        if entry.json_contract_source != "false":
            findings.append(Finding("error", entry.manifest_path, "json_contract_source", "display/XML resources must not be JSON contract sources"))
        if entry.secret_rendering_allowed != "false":
            findings.append(Finding("error", entry.manifest_path, "secret_rendering_allowed", "display/XML resources must not render secrets"))
        if entry.fallback_required not in {"yes", "no"}:
            findings.append(Finding("error", entry.manifest_path, "fallback_required_invalid", "fallback_required must be yes or no"))
        path = _resource_path(root, entry.resource_type, entry.language, entry.name)
        if not path.exists():
            findings.append(Finding("error", _rel(root, path), "resource_missing", "manifest entry references a missing resource"))

    resources: list[dict[str, object]] = []
    required_count = 0
    fallback_present_count = 0
    for (resource_type, name), group in sorted(grouped.items()):
        languages = sorted({entry.language for entry in group})
        fallback_entries = [entry for entry in group if entry.language == "fallback"]
        fallback_path = _resource_path(root, resource_type, "fallback", name)
        fallback_present = bool(fallback_entries) and fallback_path.exists()
        required_by = sorted(entry.language for entry in group if entry.fallback_required == "yes")
        if required_by:
            required_count += 1
            if fallback_present:
                fallback_present_count += 1
            else:
                findings.append(Finding("error", _rel(root, fallback_path), "fallback_missing", f"fallback required by languages: {','.join(required_by)}"))
        if len(fallback_entries) > 1:
            findings.append(Finding("error", _rel(root, fallback_path), "fallback_duplicate", "manifest declares duplicate fallback entries"))
        resources.append({
            "type": resource_type,
            "name": name,
            "manifest_languages": languages,
            "fallback_required_by": required_by,
            "fallback_manifest_entry": bool(fallback_entries),
            "fallback_file_present": fallback_path.exists(),
            "fallback_path": _rel(root, fallback_path),
            "lookup_boundary": "localized-file-then-fallback-presence-only",
            "json_contract_source": False,
            "secret_rendering_allowed": False,
        })

    status = "ok" if not any(f.level == "error" for f in findings) else "error"
    return {
        "schema": "queuebash.display_resource_fallback_audit.v1",
        "status": status,
        "root": str(root),
        "redacted": True,
        "owner_lane": "bob18-display-resources",
        "renderer": "none-fallback-audit-only",
        "source": "manifest-metadata-and-file-presence-only",
        "json_contract_source": False,
        "secret_rendering_allowed": False,
        "token_value_substitution": False,
        "stats": {
            "manifest_rows": len(entries),
            "resources_declared": len(grouped),
            "fallback_required_resources": required_count,
            "fallback_present_resources": fallback_present_count,
            "findings": len(findings),
        },
        "resources": resources,
        "forbidden": [
            "secret_values",
            "provider_credentials",
            "resource_rendering",
            "token_substitution",
            "shell_expansion",
            "command_substitution",
            "eval",
            "source",
            "json_generation_from_template",
        ],
        "findings": [asdict(f) for f in findings],
    }


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Audit bashqueues display/XML fallback manifest coverage")
    parser.add_argument("--root", default=".", help="repository root to inspect")
    parser.add_argument("--json", action="store_true", help="emit queuebash.display_resource_fallback_audit.v1 JSON")
    args = parser.parse_args(list(argv) if argv is not None else None)

    payload = audit_fallbacks(Path(args.root).resolve())
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        stats = payload["stats"]
        print(f"display resource fallback audit: {payload['status']} ({stats['fallback_present_resources']}/{stats['fallback_required_resources']} required fallbacks present)")
        for finding in payload["findings"]:
            print(f"{finding['level']}\t{finding['code']}\t{finding['path']}\t{finding['message']}")
    return 0 if payload["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
