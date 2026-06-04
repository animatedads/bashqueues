#!/usr/bin/env python3
"""Read-only catalog helper for bashqueues display/XML resource manifests.

The helper summarizes manifest metadata for reviewers and installers. It does not
render templates, inspect provider state, generate command JSON contracts, or
read secret values.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable

SHELL_RE = re.compile(r"\$\{|\$\(|`")
SECRET_VALUE_RE = re.compile(r"(?i)(actual[-_ ]?secret|secret[-_ ]?value|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16})")


@dataclass
class Finding:
    level: str
    path: str
    code: str
    message: str


def _read_manifest(path: Path) -> tuple[list[list[str]], list[Finding]]:
    rows: list[list[str]] = []
    findings: list[Finding] = []
    if not path.exists():
        findings.append(Finding("warning", str(path), "manifest_missing", "manifest is not present"))
        return rows, findings
    with path.open(newline="") as fh:
        for lineno, raw in enumerate(fh, start=1):
            if not raw.strip() or raw.startswith("#"):
                continue
            if SHELL_RE.search(raw):
                findings.append(Finding("error", f"{path}:{lineno}", "manifest_shell_expansion", "manifest contains shell-looking expansion"))
            if SECRET_VALUE_RE.search(raw):
                findings.append(Finding("error", f"{path}:{lineno}", "manifest_secret_value", "manifest appears to contain a concrete secret value"))
            rows.append(next(csv.reader([raw], delimiter="\t")))
    return rows, findings


def _tokens(value: str) -> list[str]:
    if value == "none" or not value:
        return []
    return sorted({part for part in value.split(",") if part})


def build_catalog(root: Path) -> dict[str, object]:
    manifests = [
        root / "resources.d" / "display" / "manifest.example.tsv",
        root / "resources.d" / "xml" / "manifest.example.tsv",
    ]
    findings: list[Finding] = []
    grouped: dict[tuple[str, str], dict[str, object]] = {}
    row_count = 0
    for manifest in manifests:
        rows, manifest_findings = _read_manifest(manifest)
        findings.extend(manifest_findings)
        for row in rows:
            row_count += 1
            if len(row) != 9:
                findings.append(Finding("error", str(manifest), "manifest_row_width", "manifest row must contain nine TSV fields"))
                continue
            resource_type, name, language, fallback_required, tokens, surface, json_source, secret_allowed, notes = row
            if resource_type not in {"display", "xml"}:
                findings.append(Finding("error", str(manifest), "resource_type", f"unsupported resource type {resource_type!r}"))
            if json_source != "false":
                findings.append(Finding("error", str(manifest), "json_contract_source", "display resources must not be command JSON contract sources"))
            if secret_allowed != "false":
                findings.append(Finding("error", str(manifest), "secret_rendering_allowed", "display resources must not render secret values"))
            key = (resource_type, name)
            entry = grouped.setdefault(
                key,
                {
                    "type": resource_type,
                    "name": name,
                    "languages": [],
                    "tokens": [],
                    "surfaces": [],
                    "fallback_required": False,
                    "json_contract_source": False,
                    "secret_rendering_allowed": False,
                    "notes_redacted": True,
                },
            )
            entry["languages"] = sorted(set(entry["languages"]) | {language})
            entry["tokens"] = sorted(set(entry["tokens"]) | set(_tokens(tokens)))
            entry["surfaces"] = sorted(set(entry["surfaces"]) | {surface})
            entry["fallback_required"] = bool(entry["fallback_required"] or fallback_required == "yes")

    resources = [grouped[key] for key in sorted(grouped)]
    status = "ok" if not any(f.level == "error" for f in findings) else "error"
    return {
        "schema": "queuebash.display_resource_catalog.v1",
        "status": status,
        "root": str(root),
        "redacted": True,
        "owner_lane": "bob18-display-resources",
        "renderer": "none-catalog-only",
        "json_contract_source": False,
        "secret_rendering_allowed": False,
        "manifest_rows": row_count,
        "resource_count": len(resources),
        "resources": resources,
        "forbidden": [
            "eval",
            "source",
            "shell_expansion",
            "command_substitution",
            "DTD",
            "external_entities",
            "secret_values",
            "provider_credentials",
            "json_generation_from_template",
        ],
        "findings": [asdict(f) for f in findings],
    }


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Emit a redacted bashqueues display/XML resource catalog")
    parser.add_argument("--root", default=".", help="repository root to inspect")
    parser.add_argument("--json", action="store_true", help="emit queuebash.display_resource_catalog.v1 JSON")
    args = parser.parse_args(list(argv) if argv is not None else None)

    payload = build_catalog(Path(args.root).resolve())
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(f"display resource catalog: {payload['status']} ({payload['resource_count']} resources)")
        for finding in payload["findings"]:
            print(f"{finding['level']}\t{finding['code']}\t{finding['path']}\t{finding['message']}")
    return 0 if payload["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
