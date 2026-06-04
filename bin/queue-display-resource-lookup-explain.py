#!/usr/bin/env python3
"""Explain display/XML resource lookup without rendering templates.

This helper is read-only Bob18 evidence. It explains which localized resource,
fallback resource, or missing state would be selected for a resource name. It
never renders resource body text, performs token replacement, reads secrets,
invokes providers, mutates signing state, or generates command JSON.
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
LANG_RE = re.compile(r"^(fallback|lang_[A-Za-z0-9_]+)$")
RESOURCE_TYPE_MANIFESTS = {
    "display": Path("resources.d/display/manifest.example.tsv"),
    "xml": Path("resources.d/xml/manifest.example.tsv"),
}


@dataclass
class Finding:
    level: str
    path: str
    code: str
    message: str


def _read_manifest(path: Path) -> tuple[list[dict[str, str]], list[Finding]]:
    rows: list[dict[str, str]] = []
    findings: list[Finding] = []
    if not path.exists():
        findings.append(Finding("error", str(path), "manifest_missing", "manifest is not present"))
        return rows, findings
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
            rows.append(
                {
                    "resource_type": resource_type,
                    "name": name,
                    "language": language,
                    "fallback_required": fallback_required,
                    "tokens": tokens,
                    "surface": surface,
                    "json_contract_source": json_source,
                    "secret_rendering_allowed": secret_allowed,
                    "notes_redacted": "true",
                    "manifest_path": str(path),
                    "manifest_line": str(lineno),
                }
            )
    return rows, findings


def _resource_path(root: Path, resource_type: str, language: str, name: str) -> Path:
    return root / "resources.d" / resource_type / language / name


def _tokens(value: str) -> list[str]:
    if not value or value == "none":
        return []
    return sorted({part for part in value.split(",") if part})


def build_lookup_explain(root: Path, resource_type: str, name: str, language: str) -> dict[str, object]:
    findings: list[Finding] = []
    if resource_type not in RESOURCE_TYPE_MANIFESTS:
        findings.append(Finding("error", resource_type, "resource_type", "resource type must be display or xml"))
    if not LANG_RE.match(language):
        findings.append(Finding("error", language, "language", "language must be fallback or lang_*"))

    manifest_path = root / RESOURCE_TYPE_MANIFESTS.get(resource_type, Path("resources.d/unknown/manifest.example.tsv"))
    rows, manifest_findings = _read_manifest(manifest_path)
    findings.extend(manifest_findings)
    matching = [r for r in rows if r["resource_type"] == resource_type and r["name"] == name]
    by_language = {r["language"]: r for r in matching}

    if not matching:
        findings.append(Finding("error", str(manifest_path), "resource_not_declared", "resource is not declared in the manifest"))

    for row in matching:
        if row["json_contract_source"] != "false":
            findings.append(Finding("error", row["manifest_path"], "json_contract_source", "display/XML resources must not be command JSON contract sources"))
        if row["secret_rendering_allowed"] != "false":
            findings.append(Finding("error", row["manifest_path"], "secret_rendering_allowed", "display/XML resources must not render secret values"))

    requested_path = _resource_path(root, resource_type, language, name)
    fallback_path = _resource_path(root, resource_type, "fallback", name)
    selected_language = None
    selected_path = None
    resolution = "missing"
    fallback_used = False

    if language in by_language and requested_path.exists():
        selected_language = language
        selected_path = requested_path
        resolution = "localized"
    elif "fallback" in by_language and fallback_path.exists():
        selected_language = "fallback"
        selected_path = fallback_path
        resolution = "fallback"
        fallback_used = language != "fallback"
    else:
        if matching:
            findings.append(Finding("error", f"{resource_type}:{name}", "resource_file_missing", "neither requested language nor fallback resource file is available"))

    expected_paths = [str(requested_path), str(fallback_path)] if language != "fallback" else [str(fallback_path)]
    manifest_entry = by_language.get(selected_language or language) or (matching[0] if matching else {})
    status = "ok" if resolution in {"localized", "fallback"} and not any(f.level == "error" for f in findings) else "error"
    return {
        "schema": "queuebash.display_resource_lookup_explain.v1",
        "status": status,
        "root": str(root),
        "redacted": True,
        "owner_lane": "bob18-display-resources",
        "renderer": "none-lookup-explain-only",
        "source": "manifest-metadata-and-file-presence-only",
        "json_contract_source": False,
        "secret_rendering_allowed": False,
        "request": {"type": resource_type, "name": name, "language": language},
        "resolution": {
            "state": resolution,
            "selected_language": selected_language,
            "selected_path": str(selected_path) if selected_path else None,
            "fallback_used": fallback_used,
            "expected_paths": expected_paths,
        },
        "manifest": {
            "path": str(manifest_path),
            "declared_languages": sorted(by_language),
            "fallback_declared": "fallback" in by_language,
            "tokens": _tokens(str(manifest_entry.get("tokens", ""))),
            "surface": manifest_entry.get("surface"),
            "notes_redacted": True,
        },
        "forbidden": [
            "rendering_templates",
            "token_replacement",
            "reading_secret_values",
            "provider_calls",
            "signing_mutation",
            "json_generation_from_template",
            "shell_expansion",
        ],
        "findings": [asdict(f) for f in findings],
    }


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Explain display/XML resource lookup without rendering templates")
    parser.add_argument("--root", default=".", help="repository root to inspect")
    parser.add_argument("--type", choices=("display", "xml"), required=True, help="resource type")
    parser.add_argument("--name", required=True, help="resource file name")
    parser.add_argument("--language", default="lang_eng", help="requested language directory, for example lang_eng")
    parser.add_argument("--json", action="store_true", help="emit queuebash.display_resource_lookup_explain.v1 JSON")
    args = parser.parse_args(list(argv) if argv is not None else None)

    payload = build_lookup_explain(Path(args.root).resolve(), args.type, args.name, args.language)
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        resolution = payload["resolution"]
        print(
            f"display resource lookup: {payload['status']} "
            f"{payload['request']['type']}:{payload['request']['name']} "
            f"requested={payload['request']['language']} selected={resolution['selected_language'] or '-'} "
            f"state={resolution['state']}"
        )
        for finding in payload["findings"]:
            print(f"{finding['level']}\t{finding['code']}\t{finding['path']}\t{finding['message']}")
    return 0 if payload["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
