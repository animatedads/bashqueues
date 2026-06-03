#!/usr/bin/env python3
"""Read-only lint helper for bashqueues display/XML resources.

This helper validates Bob18 display-resource manifests and fixtures. It is not a
renderer, not a policy engine, and not a queue command JSON generator.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable

TOKEN_RE = re.compile(r"\{\{([A-Z0-9_]+)\}\}")
SHELL_RE = re.compile(r"\$\{|\$\(|`")
SECRET_RE = re.compile(r"(?i)(secret(_?value)?|password|passwd|token|api[_-]?key|private[_-]?key|credential)")
FORBIDDEN_XML_RE = re.compile(r"(?is)<!DOCTYPE|<!ENTITY|<\?xml-stylesheet|SYSTEM\s+[\"']|PUBLIC\s+[\"']")


@dataclass
class Finding:
    level: str
    path: str
    code: str
    message: str


def _read_manifest(path: Path) -> list[list[str]]:
    rows: list[list[str]] = []
    if not path.exists():
        return rows
    with path.open(newline="") as fh:
        for raw in fh:
            if not raw.strip() or raw.startswith("#"):
                continue
            rows.append(next(csv.reader([raw], delimiter="\t")))
    return rows


def _resource_path(root: Path, resource_type: str, language: str, name: str) -> Path:
    if resource_type == "display":
        return root / "resources.d" / "display" / language / name
    if resource_type == "xml":
        return root / "resources.d" / "xml" / language / name
    return root / "resources.d" / resource_type / language / name


def _fallback_path(root: Path, resource_type: str, name: str) -> Path:
    if resource_type == "display":
        return root / "resources.d" / "display" / "fallback" / name
    if resource_type == "xml":
        return root / "resources.d" / "xml" / "fallback" / name
    return root / "resources.d" / resource_type / "fallback" / name


def _token_allowlist(tokens: str) -> set[str]:
    if tokens == "none":
        return set()
    return {tok for tok in tokens.split(",") if tok}


def lint(root: Path) -> tuple[list[Finding], dict[str, int]]:
    findings: list[Finding] = []
    stats = {
        "manifest_rows": 0,
        "resources_checked": 0,
        "xml_resources_checked": 0,
        "fallback_peers_checked": 0,
    }
    manifests = [
        root / "resources.d" / "display" / "manifest.example.tsv",
        root / "resources.d" / "xml" / "manifest.example.tsv",
    ]
    for manifest_path in manifests:
        rows = _read_manifest(manifest_path)
        if not rows:
            findings.append(Finding("error", str(manifest_path), "manifest_missing_or_empty", "manifest is missing or has no data rows"))
            continue
        for row in rows:
            stats["manifest_rows"] += 1
            if len(row) != 9:
                findings.append(Finding("error", str(manifest_path), "manifest_row_width", "manifest row must contain nine TSV fields"))
                continue
            resource_type, name, language, fallback_required, tokens, surface, json_source, secret_allowed, notes = row
            row_text = "\t".join(row)
            if resource_type not in {"display", "xml"}:
                findings.append(Finding("error", str(manifest_path), "resource_type", f"unsupported resource_type {resource_type!r}"))
            if not (language == "fallback" or language.startswith("lang_")):
                findings.append(Finding("error", str(manifest_path), "language", f"unsupported language {language!r}"))
            if fallback_required not in {"yes", "no"}:
                findings.append(Finding("error", str(manifest_path), "fallback_required", "fallback_required must be yes or no"))
            if json_source != "false":
                findings.append(Finding("error", str(manifest_path), "json_contract_source", "display resources must not be JSON contract sources"))
            if secret_allowed != "false":
                findings.append(Finding("error", str(manifest_path), "secret_rendering_allowed", "display resources must not render secrets"))
            if SHELL_RE.search(row_text):
                findings.append(Finding("error", str(manifest_path), "manifest_shell_expansion", "manifest contains shell-looking expansion"))
            # Manifest notes may explicitly describe the no-secrets boundary.
            # Concrete secret-like resource names/values are checked in resource text.

            path = _resource_path(root, resource_type, language, name)
            if not path.exists():
                findings.append(Finding("error", str(path), "resource_missing", "manifest references a missing resource"))
                continue
            stats["resources_checked"] += 1
            text = path.read_text(errors="replace")
            if SHELL_RE.search(text):
                findings.append(Finding("error", str(path), "resource_shell_expansion", "resource contains shell-looking expansion"))
            if SECRET_RE.search(text):
                findings.append(Finding("error", str(path), "resource_secret_text", "resource contains secret-looking text"))

            allowed = _token_allowlist(tokens)
            used = set(TOKEN_RE.findall(text))
            unknown = used - allowed
            if unknown:
                findings.append(Finding("error", str(path), "resource_token_not_allowed", "resource uses tokens not listed in manifest: " + ",".join(sorted(unknown))))
            if tokens == "none" and used:
                findings.append(Finding("error", str(path), "resource_unexpected_tokens", "resource uses tokens but manifest says none"))

            if fallback_required == "yes" and language != "fallback":
                fb = _fallback_path(root, resource_type, name)
                stats["fallback_peers_checked"] += 1
                if not fb.exists():
                    findings.append(Finding("error", str(fb), "fallback_missing", "fallback-required resource lacks fallback peer"))

            if resource_type == "xml":
                stats["xml_resources_checked"] += 1
                if FORBIDDEN_XML_RE.search(text):
                    findings.append(Finding("error", str(path), "xml_forbidden_construct", "XML resource contains DTD/entity/external processing construct"))
                try:
                    ET.fromstring(text)
                except ET.ParseError as exc:
                    findings.append(Finding("error", str(path), "xml_parse_error", f"XML parse failed: {exc}"))
    return findings, stats


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Lint bashqueues display/XML resource manifests and fixtures")
    parser.add_argument("--root", default=".", help="repository root to inspect")
    parser.add_argument("--json", action="store_true", help="emit queuebash.display_resource_lint.v1 JSON")
    args = parser.parse_args(list(argv) if argv is not None else None)

    root = Path(args.root).resolve()
    findings, stats = lint(root)
    status = "ok" if not any(f.level == "error" for f in findings) else "error"
    payload = {
        "schema": "queuebash.display_resource_lint.v1",
        "status": status,
        "root": str(root),
        "redacted": True,
        "json_contract_source": False,
        "secret_rendering_allowed": False,
        "renderer": "none-lint-only",
        "stats": stats,
        "findings": [asdict(f) for f in findings],
    }
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(f"display resource lint: {status}")
        for finding in findings:
            print(f"{finding.level}\t{finding.code}\t{finding.path}\t{finding.message}")
    return 0 if status == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
