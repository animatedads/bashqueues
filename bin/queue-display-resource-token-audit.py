#!/usr/bin/env python3
"""Read-only token audit helper for bashqueues display/XML resources.

The helper compares controlled {{TOKEN}} usage in display/XML resource bodies
against manifest allow-lists. It is not a renderer and never substitutes token
values.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable

TOKEN_RE = re.compile(r"\{\{([A-Z0-9_]+)\}\}")
ANY_TOKEN_RE = re.compile(r"\{\{([^{}]+)\}\}")
SHELL_RE = re.compile(r"\$\{|\$\(|`")
SECRET_TOKEN_RE = re.compile(r"(?i)(SECRET|PASSWORD|PASSWD|TOKEN|API_KEY|PRIVATE_KEY|CREDENTIAL)")
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


def _resource_path(root: Path, resource_type: str, language: str, name: str) -> Path:
    if resource_type == "display":
        return root / "resources.d" / "display" / language / name
    if resource_type == "xml":
        return root / "resources.d" / "xml" / language / name
    return root / "resources.d" / resource_type / language / name


def _allowlist(tokens: str) -> set[str]:
    if not tokens or tokens == "none":
        return set()
    return {part for part in tokens.split(",") if part}


def audit_tokens(root: Path) -> dict[str, object]:
    manifests = [
        root / "resources.d" / "display" / "manifest.example.tsv",
        root / "resources.d" / "xml" / "manifest.example.tsv",
    ]
    findings: list[Finding] = []
    entries: list[dict[str, object]] = []
    stats = {
        "manifest_rows": 0,
        "resources_checked": 0,
        "tokens_declared": 0,
        "tokens_used": 0,
        "unused_declared_tokens": 0,
        "undeclared_used_tokens": 0,
    }

    for manifest in manifests:
        rows, manifest_findings = _read_manifest(manifest)
        findings.extend(manifest_findings)
        for row in rows:
            stats["manifest_rows"] += 1
            if len(row) != 9:
                findings.append(Finding("error", str(manifest), "manifest_row_width", "manifest row must contain nine TSV fields"))
                continue
            resource_type, name, language, fallback_required, tokens, surface, json_source, secret_allowed, notes = row
            if json_source != "false":
                findings.append(Finding("error", str(manifest), "json_contract_source", "display resources must not be command JSON contract sources"))
            if secret_allowed != "false":
                findings.append(Finding("error", str(manifest), "secret_rendering_allowed", "display resources must not render secrets"))
            declared = _allowlist(tokens)
            stats["tokens_declared"] += len(declared)
            for token in sorted(declared):
                if SECRET_TOKEN_RE.search(token):
                    findings.append(Finding("error", str(manifest), "secret_token_declared", f"secret-looking token name is forbidden: {token}"))

            path = _resource_path(root, resource_type, language, name)
            if not path.exists():
                findings.append(Finding("error", str(path), "resource_missing", "manifest references a missing resource"))
                continue
            text = path.read_text(errors="replace")
            stats["resources_checked"] += 1
            if SHELL_RE.search(text):
                findings.append(Finding("error", str(path), "resource_shell_expansion", "resource contains shell-looking expansion"))
            if SECRET_VALUE_RE.search(text):
                findings.append(Finding("error", str(path), "resource_secret_value", "resource appears to contain a concrete secret value"))

            malformed = sorted(set(raw for raw in ANY_TOKEN_RE.findall(text) if not re.fullmatch(r"[A-Z0-9_]+", raw)))
            for token in malformed:
                findings.append(Finding("error", str(path), "token_malformed", f"token is not uppercase identifier syntax: {token}"))
            used = set(TOKEN_RE.findall(text))
            stats["tokens_used"] += len(used)
            undeclared = used - declared
            unused = declared - used
            stats["undeclared_used_tokens"] += len(undeclared)
            stats["unused_declared_tokens"] += len(unused)
            for token in sorted(used):
                if SECRET_TOKEN_RE.search(token):
                    findings.append(Finding("error", str(path), "secret_token_used", f"secret-looking token name is forbidden: {token}"))
            if undeclared:
                findings.append(Finding("error", str(path), "token_not_declared", "resource uses undeclared tokens: " + ",".join(sorted(undeclared))))
            if unused:
                findings.append(Finding("warning", str(path), "token_declared_unused", "manifest declares unused tokens: " + ",".join(sorted(unused))))

            entries.append({
                "type": resource_type,
                "name": name,
                "language": language,
                "path": str(path.relative_to(root)) if path.is_relative_to(root) else str(path),
                "declared_tokens": sorted(declared),
                "used_tokens": sorted(used),
                "undeclared_tokens": sorted(undeclared),
                "unused_tokens": sorted(unused),
                "secret_token_names_present": any(SECRET_TOKEN_RE.search(tok) for tok in declared | used),
            })

    status = "ok" if not any(f.level == "error" for f in findings) else "error"
    return {
        "schema": "queuebash.display_resource_token_audit.v1",
        "status": status,
        "root": str(root),
        "redacted": True,
        "owner_lane": "bob18-display-resources",
        "renderer": "none-token-audit-only",
        "source": "manifest-and-resource-token-names-only",
        "json_contract_source": False,
        "secret_rendering_allowed": False,
        "token_value_substitution": False,
        "stats": stats,
        "resources": entries,
        "forbidden": [
            "secret_token_names",
            "secret_values",
            "provider_credentials",
            "shell_expansion",
            "command_substitution",
            "eval",
            "source",
            "json_generation_from_template",
        ],
        "findings": [asdict(f) for f in findings],
    }


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Audit bashqueues display/XML resource token allow-lists")
    parser.add_argument("--root", default=".", help="repository root to inspect")
    parser.add_argument("--json", action="store_true", help="emit queuebash.display_resource_token_audit.v1 JSON")
    args = parser.parse_args(list(argv) if argv is not None else None)

    payload = audit_tokens(Path(args.root).resolve())
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(f"display resource token audit: {payload['status']} ({payload['stats']['resources_checked']} resources)")
        for finding in payload["findings"]:
            print(f"{finding['level']}\t{finding['code']}\t{finding['path']}\t{finding['message']}")
    return 0 if payload["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
