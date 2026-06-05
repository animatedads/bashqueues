#!/usr/bin/env python3
"""Read-only line hygiene audit helper for bashqueues display/XML resources.

The helper inspects manifest-listed display/XML resource text for release-review
line hygiene. It reports trailing whitespace, overlong lines, tab-prefixed
indentation in XML resources, missing final newline, and line-count evidence
without rendering templates, substituting tokens, reading secrets, signing,
installing, changing file modes/owners, or generating command/provider JSON.
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
DEFAULT_MAX_LINE_LENGTH = 160


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


def _audit_lines(root: Path, entry: ManifestEntry, findings: list[Finding], max_line_length: int) -> dict[str, object]:
    path = _resource_path(root, entry)
    rel = _rel(root, path)
    item: dict[str, object] = {
        "resource_type": entry.resource_type,
        "language": entry.language,
        "name": entry.name,
        "path": rel,
        "manifest_path": entry.manifest_path,
        "manifest_line": entry.manifest_line,
        "exists": path.exists(),
        "is_regular_file": path.is_file(),
        "is_symlink": path.is_symlink(),
        "line_count": 0,
        "max_line_length": 0,
        "overlong_lines": [],
        "trailing_whitespace_lines": [],
        "blank_lines": 0,
        "xml_tab_indented_lines": [],
        "newline_terminated": False,
    }
    if not path.exists():
        findings.append(Finding("error", rel, "resource_missing", "manifest-listed resource is missing"))
        return item
    if path.is_symlink():
        findings.append(Finding("error", rel, "resource_symlink", "resource file must not be a symlink"))
        return item
    if not path.is_file():
        findings.append(Finding("error", rel, "resource_not_regular_file", "resource path must be a regular file"))
        return item

    data = path.read_bytes()
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        findings.append(Finding("error", rel, "utf8_invalid", f"resource is not valid UTF-8: byte {exc.start}"))
        return item

    item["newline_terminated"] = (not data) or data.endswith(b"\n")
    if data and not item["newline_terminated"]:
        findings.append(Finding("warning", rel, "missing_final_newline", "resource should end with a newline for stable display diffs"))

    # splitlines keeps the audit independent of rendering and token substitution.
    lines = text.splitlines()
    item["line_count"] = len(lines)
    overlong: list[int] = []
    trailing: list[int] = []
    xml_tabs: list[int] = []
    blank = 0
    max_seen = 0
    for lineno, line in enumerate(lines, start=1):
        length = len(line)
        max_seen = max(max_seen, length)
        if length > max_line_length:
            overlong.append(lineno)
        if line.endswith(" ") or line.endswith("\t"):
            trailing.append(lineno)
        if not line.strip():
            blank += 1
        if entry.resource_type == "xml" and line.startswith("\t"):
            xml_tabs.append(lineno)
    item["max_line_length"] = max_seen
    item["overlong_lines"] = overlong
    item["trailing_whitespace_lines"] = trailing
    item["blank_lines"] = blank
    item["xml_tab_indented_lines"] = xml_tabs

    for lineno in overlong:
        findings.append(Finding("warning", f"{rel}:{lineno}", "overlong_line", f"line exceeds {max_line_length} characters"))
    for lineno in trailing:
        findings.append(Finding("warning", f"{rel}:{lineno}", "trailing_whitespace", "line ends with space or tab"))
    for lineno in xml_tabs:
        findings.append(Finding("warning", f"{rel}:{lineno}", "xml_tab_indentation", "XML resource line begins with a tab; prefer spaces for stable display diffs"))
    return item


def build_audit(root: Path, max_line_length: int = DEFAULT_MAX_LINE_LENGTH) -> dict[str, object]:
    root = root.resolve()
    findings: list[Finding] = []
    entries: list[ManifestEntry] = []
    for resource_type in ("display", "xml"):
        manifest_entries, manifest_findings = _read_manifest(root, _manifest_path(root, resource_type))
        entries.extend(manifest_entries)
        findings.extend(manifest_findings)

    resources = [_audit_lines(root, entry, findings, max_line_length) for entry in entries]
    status = "error" if any(f.level == "error" for f in findings) else ("warning" if any(f.level == "warning" for f in findings) else "ok")
    return {
        "schema": "queuebash.display_resource_line_audit.v1",
        "status": status,
        "root": str(root),
        "redacted": True,
        "owner_lane": "bob18-display-resources",
        "renderer": "none-line-audit-only",
        "source": "manifest-listed-resource-text-line-hygiene-only",
        "read_only": True,
        "installer": False,
        "signing_mutation": False,
        "permission_mutation": False,
        "json_contract_source": False,
        "secret_rendering_allowed": False,
        "token_value_substitution": False,
        "resource_rendering": False,
        "file_content_read_scope": "manifest-listed-display-xml-resource-text-for-line-hygiene-only",
        "line_policy": {
            "max_line_length": max_line_length,
            "trailing_whitespace": "warning",
            "missing_final_newline": "warning",
            "xml_tab_indentation": "warning",
        },
        "stats": {
            "manifest_entries": len(entries),
            "resource_files_audited": len(resources),
            "total_lines": sum(int(r.get("line_count") or 0) for r in resources),
            "overlong_line_resources": sum(1 for r in resources if r.get("overlong_lines")),
            "trailing_whitespace_resources": sum(1 for r in resources if r.get("trailing_whitespace_lines")),
            "xml_tab_indented_resources": sum(1 for r in resources if r.get("xml_tab_indented_lines")),
            "missing_final_newline_resources": sum(1 for r in resources if r.get("exists") and r.get("is_regular_file") and not r.get("newline_terminated")),
            "findings": len(findings),
        },
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
    parser = argparse.ArgumentParser(description="Audit bashqueues display/XML resource line hygiene")
    parser.add_argument("--root", default=".", help="repository or installed root containing resources.d")
    parser.add_argument("--json", action="store_true", help="emit queuebash.display_resource_line_audit.v1 JSON")
    parser.add_argument("--max-line-length", type=int, default=DEFAULT_MAX_LINE_LENGTH, help="warning threshold for long display/XML resource lines")
    args = parser.parse_args(list(argv) if argv is not None else None)
    if args.max_line_length < 40:
        raise SystemExit("--max-line-length must be at least 40")
    payload = build_audit(Path(args.root), args.max_line_length)
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        stats = payload["stats"]
        print(
            "display resource line audit: "
            f"{payload['status']} ({stats['resource_files_audited']} files, "
            f"{stats['total_lines']} lines)"
        )
        for finding in payload["findings"]:
            print(f"{finding['level']}\t{finding['code']}\t{finding['path']}\t{finding['message']}")
    return 1 if payload["status"] == "error" else 0


if __name__ == "__main__":
    raise SystemExit(main())
