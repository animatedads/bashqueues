#!/usr/bin/env python3
"""Read-only encoding audit helper for bashqueues display/XML resources.

The helper inspects manifest-listed display/XML resource bytes for release-review
encoding hygiene. It validates UTF-8 decoding, line-ending consistency, absence
of NUL bytes and unsafe control characters, and newline termination without
rendering templates, substituting tokens, reading secrets, signing, installing,
or mutating permissions.
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


def _audit_bytes(root: Path, entry: ManifestEntry, findings: list[Finding]) -> dict[str, object]:
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
        "bytes": 0,
        "utf8_valid": False,
        "line_ending": "unknown",
        "newline_terminated": False,
        "nul_bytes": 0,
        "unsafe_control_bytes": 0,
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
    item["bytes"] = len(data)
    item["nul_bytes"] = data.count(b"\x00")
    unsafe_controls = sum(1 for b in data if b < 32 and b not in (9, 10, 13))
    item["unsafe_control_bytes"] = unsafe_controls
    if item["nul_bytes"]:
        findings.append(Finding("error", rel, "nul_byte", "resource contains NUL bytes"))
    if unsafe_controls:
        findings.append(Finding("error", rel, "unsafe_control_byte", "resource contains unsafe control bytes"))

    try:
        text = data.decode("utf-8")
        item["utf8_valid"] = True
    except UnicodeDecodeError as exc:
        findings.append(Finding("error", rel, "utf8_invalid", f"resource is not valid UTF-8: byte {exc.start}"))
        return item

    if data:
        item["newline_terminated"] = data.endswith(b"\n")
        if not item["newline_terminated"]:
            findings.append(Finding("warning", rel, "missing_final_newline", "resource should end with a newline for stable display diffs"))

    crlf_count = text.count("\r\n")
    bare_cr_count = text.count("\r") - crlf_count
    lf_count = text.count("\n")
    item["crlf_count"] = crlf_count
    item["bare_cr_count"] = bare_cr_count
    item["lf_count"] = lf_count
    if bare_cr_count:
        item["line_ending"] = "bare-cr"
        findings.append(Finding("error", rel, "bare_cr_line_ending", "resource contains bare carriage returns"))
    elif crlf_count and lf_count != crlf_count:
        item["line_ending"] = "mixed"
        findings.append(Finding("warning", rel, "mixed_line_endings", "resource contains mixed LF and CRLF endings"))
    elif crlf_count:
        item["line_ending"] = "crlf"
        findings.append(Finding("warning", rel, "crlf_line_endings", "resource should use LF line endings in repository fixtures"))
    elif lf_count:
        item["line_ending"] = "lf"
    else:
        item["line_ending"] = "none"
    return item


def build_audit(root: Path) -> dict[str, object]:
    root = root.resolve()
    findings: list[Finding] = []
    entries: list[ManifestEntry] = []
    for resource_type in ("display", "xml"):
        manifest_entries, manifest_findings = _read_manifest(root, _manifest_path(root, resource_type))
        entries.extend(manifest_entries)
        findings.extend(manifest_findings)

    resources = [_audit_bytes(root, entry, findings) for entry in entries]
    status = "error" if any(f.level == "error" for f in findings) else ("warning" if any(f.level == "warning" for f in findings) else "ok")
    return {
        "schema": "queuebash.display_resource_encoding_audit.v1",
        "status": status,
        "root": str(root),
        "redacted": True,
        "owner_lane": "bob18-display-resources",
        "renderer": "none-encoding-audit-only",
        "source": "manifest-listed-resource-bytes-for-encoding-only",
        "read_only": True,
        "installer": False,
        "signing_mutation": False,
        "permission_mutation": False,
        "json_contract_source": False,
        "secret_rendering_allowed": False,
        "token_value_substitution": False,
        "resource_rendering": False,
        "file_content_read_scope": "manifest-listed-display-xml-resource-bytes-only",
        "stats": {
            "manifest_entries": len(entries),
            "resource_files_audited": len(resources),
            "utf8_invalid": sum(1 for r in resources if r.get("exists") and not r.get("utf8_valid")),
            "nul_byte_resources": sum(1 for r in resources if int(r.get("nul_bytes") or 0) > 0),
            "unsafe_control_resources": sum(1 for r in resources if int(r.get("unsafe_control_bytes") or 0) > 0),
            "crlf_resources": sum(1 for r in resources if r.get("line_ending") == "crlf"),
            "mixed_line_ending_resources": sum(1 for r in resources if r.get("line_ending") == "mixed"),
            "missing_final_newline_resources": sum(1 for r in resources if r.get("exists") and r.get("is_regular_file") and r.get("bytes", 0) and not r.get("newline_terminated")),
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
    parser = argparse.ArgumentParser(description="Audit bashqueues display/XML resource encoding hygiene")
    parser.add_argument("--root", default=".", help="repository or installed root containing resources.d")
    parser.add_argument("--json", action="store_true", help="emit queuebash.display_resource_encoding_audit.v1 JSON")
    args = parser.parse_args(list(argv) if argv is not None else None)
    payload = build_audit(Path(args.root))
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        stats = payload["stats"]
        print(
            "display resource encoding audit: "
            f"{payload['status']} ({stats['resource_files_audited']} files, "
            f"{stats['utf8_invalid']} invalid UTF-8)"
        )
        for finding in payload["findings"]:
            print(f"{finding['level']}\t{finding['code']}\t{finding['path']}\t{finding['message']}")
    return 1 if payload["status"] == "error" else 0


if __name__ == "__main__":
    raise SystemExit(main())
