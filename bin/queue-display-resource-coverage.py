#!/usr/bin/env python3
"""Read-only coverage helper for bashqueues display/XML resource manifests.

The helper reports language/fallback coverage from manifest metadata. It does not
render templates, read secret values, inspect provider state, generate command
JSON contracts, or mutate signing/installer state.
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
LANG_RE = re.compile(r"^lang_[A-Za-z0-9_]+$")


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


def _discover_language_dirs(root: Path) -> dict[str, list[str]]:
    discovered: dict[str, list[str]] = {}
    for resource_type in ("display", "xml"):
        base = root / "resources.d" / resource_type
        langs: list[str] = []
        if base.exists():
            for child in base.iterdir():
                if child.is_dir() and LANG_RE.match(child.name):
                    langs.append(child.name)
        discovered[resource_type] = sorted(set(langs))
    return discovered


def build_coverage(root: Path) -> dict[str, object]:
    manifests = [
        root / "resources.d" / "display" / "manifest.example.tsv",
        root / "resources.d" / "xml" / "manifest.example.tsv",
    ]
    findings: list[Finding] = []
    discovered = _discover_language_dirs(root)
    grouped: dict[tuple[str, str], dict[str, object]] = {}
    manifest_rows = 0

    for manifest in manifests:
        rows, manifest_findings = _read_manifest(manifest)
        findings.extend(manifest_findings)
        for row in rows:
            manifest_rows += 1
            if len(row) != 9:
                findings.append(Finding("error", str(manifest), "manifest_row_width", "manifest row must contain nine TSV fields"))
                continue
            resource_type, name, language, fallback_required, tokens, surface, json_source, secret_allowed, notes = row
            if resource_type not in {"display", "xml"}:
                findings.append(Finding("error", str(manifest), "resource_type", f"unsupported resource type {resource_type!r}"))
                continue
            if language != "fallback" and not LANG_RE.match(language):
                findings.append(Finding("error", str(manifest), "language", f"unsupported language {language!r}"))
            if json_source != "false":
                findings.append(Finding("error", str(manifest), "json_contract_source", "display/XML resources must not be command JSON contract sources"))
            if secret_allowed != "false":
                findings.append(Finding("error", str(manifest), "secret_rendering_allowed", "display/XML resources must not render secret values"))
            key = (resource_type, name)
            entry = grouped.setdefault(
                key,
                {
                    "type": resource_type,
                    "name": name,
                    "languages_present": [],
                    "fallback_present": False,
                    "fallback_required": False,
                    "catalog_only": True,
                    "json_contract_source": False,
                    "secret_rendering_allowed": False,
                    "surfaces": [],
                },
            )
            if language == "fallback":
                entry["fallback_present"] = True
            else:
                entry["languages_present"] = sorted(set(entry["languages_present"]) | {language})
            entry["fallback_required"] = bool(entry["fallback_required"] or fallback_required == "yes")
            entry["surfaces"] = sorted(set(entry["surfaces"]) | {surface})

    resources: list[dict[str, object]] = []
    language_totals: dict[str, dict[str, int]] = {}
    for key in sorted(grouped):
        entry = grouped[key]
        resource_type = str(entry["type"])
        present = set(entry["languages_present"])
        expected = set(discovered.get(resource_type, []))
        missing = sorted(expected - present)
        coverage_status = "complete"
        if entry["fallback_required"] and not entry["fallback_present"]:
            coverage_status = "missing_fallback"
            findings.append(Finding("error", f"{resource_type}:{entry['name']}", "fallback_missing", "fallback-required resource lacks manifest fallback entry"))
        elif missing:
            # Non-English translation gaps are advisory until a resource declares a release language target.
            coverage_status = "partial"
        resource = dict(entry)
        resource["languages_expected"] = sorted(expected)
        resource["languages_missing"] = missing
        resource["coverage_status"] = coverage_status
        resource["translation_gap_count"] = len(missing)
        resources.append(resource)
        totals = language_totals.setdefault(resource_type, {"resources": 0, "fallback_present": 0, "translation_gaps": 0})
        totals["resources"] += 1
        totals["fallback_present"] += 1 if entry["fallback_present"] else 0
        totals["translation_gaps"] += len(missing)

    status = "ok" if not any(f.level == "error" for f in findings) else "error"
    return {
        "schema": "queuebash.display_resource_coverage.v1",
        "status": status,
        "root": str(root),
        "redacted": True,
        "owner_lane": "bob18-display-resources",
        "renderer": "none-coverage-only",
        "source": "manifest-metadata-only",
        "json_contract_source": False,
        "secret_rendering_allowed": False,
        "manifest_rows": manifest_rows,
        "resource_count": len(resources),
        "language_dirs": discovered,
        "language_totals": language_totals,
        "resources": resources,
        "forbidden": [
            "rendering_templates",
            "reading_secret_values",
            "provider_calls",
            "signing_mutation",
            "json_generation_from_template",
            "shell_expansion",
        ],
        "findings": [asdict(f) for f in findings],
    }


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Emit redacted display/XML resource language coverage evidence")
    parser.add_argument("--root", default=".", help="repository root to inspect")
    parser.add_argument("--json", action="store_true", help="emit queuebash.display_resource_coverage.v1 JSON")
    args = parser.parse_args(list(argv) if argv is not None else None)

    payload = build_coverage(Path(args.root).resolve())
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(f"display resource coverage: {payload['status']} ({payload['resource_count']} resources)")
        for resource in payload["resources"]:
            print(
                f"{resource['type']}\t{resource['name']}\t{resource['coverage_status']}\t"
                f"langs={','.join(resource['languages_present']) or '-'}\tmissing={','.join(resource['languages_missing']) or '-'}"
            )
        for finding in payload["findings"]:
            print(f"{finding['level']}\t{finding['code']}\t{finding['path']}\t{finding['message']}")
    return 0 if payload["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
