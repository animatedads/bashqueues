#!/usr/bin/env python3
"""Read-only namespace/path audit helper for bashqueues display/XML resources.

The helper inspects display/XML resource manifests and manifest-listed resource
names for release-review namespace hygiene. It reports unsafe path names,
absolute paths, parent traversal, duplicate rows, mismatched resource type/name
conventions, and missing manifest-listed files without rendering templates,
substituting tokens, reading resource bodies, reading secrets, signing,
installing, changing file modes/owners, or generating command/provider JSON.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path, PurePosixPath

SHELL_RE = re.compile(r"\$\{|\$\(|`")
SECRET_VALUE_RE = re.compile(r"(?i)(actual[-_ ]?secret|secret[-_ ]?value|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16})")
LANGUAGE_RE = re.compile(r"^(fallback|lang_[a-z][a-z0-9_]{1,31})$")
SAFE_COMPONENT_RE = re.compile(r"^[A-Za-z0-9._@+-]+$")
VALID_TYPE = {"display", "xml"}
MANIFEST_NAME = "manifest.example.tsv"
MAX_NAME_LEN = 160


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
    return root / "resources.d" / resource_type / MANIFEST_NAME


def _resource_base(root: Path, resource_type: str) -> Path:
    return root / "resources.d" / resource_type


def _resource_path(root: Path, entry: ManifestEntry) -> Path:
    return _resource_base(root, entry.resource_type) / entry.language / entry.name


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
            if not LANGUAGE_RE.match(entry.language):
                findings.append(Finding("error", where, "language_identifier_invalid", "language must be fallback or lang_<identifier>"))
            entries.append(entry)
    return entries, findings


def _audit_name(root: Path, entry: ManifestEntry, findings: list[Finding]) -> dict[str, object]:
    where = f"{entry.manifest_path}:{entry.manifest_line}"
    name = entry.name
    pure = PurePosixPath(name)
    components = list(pure.parts)
    extension = pure.suffix.lower()
    is_safe = True
    if not name:
        findings.append(Finding("error", where, "resource_name_empty", "resource name must not be empty"))
        is_safe = False
    if len(name) > MAX_NAME_LEN:
        findings.append(Finding("error", where, "resource_name_too_long", f"resource name exceeds {MAX_NAME_LEN} characters"))
        is_safe = False
    if pure.is_absolute() or name.startswith("/"):
        findings.append(Finding("error", where, "resource_name_absolute", "resource name must be relative"))
        is_safe = False
    if name.startswith("~"):
        findings.append(Finding("error", where, "resource_name_home_relative", "resource name must not use home-relative syntax"))
        is_safe = False
    if "\\" in name:
        findings.append(Finding("error", where, "resource_name_backslash", "resource name must use portable forward-slash separators only"))
        is_safe = False
    if any(part in {"", ".", ".."} for part in components):
        findings.append(Finding("error", where, "resource_name_path_traversal", "resource name must not contain empty, dot, or parent components"))
        is_safe = False
    for part in components:
        if part in {"", ".", ".."}:
            continue
        if not SAFE_COMPONENT_RE.match(part):
            findings.append(Finding("error", where, "resource_name_unsafe_component", f"unsafe resource name component: {part}"))
            is_safe = False
    if entry.resource_type == "xml" and extension != ".xml":
        findings.append(Finding("error", where, "xml_resource_extension", "XML resources must use .xml extension"))
        is_safe = False
    if entry.resource_type == "display" and extension == ".xml":
        findings.append(Finding("error", where, "display_resource_extension", "display resources must not use .xml extension"))
        is_safe = False
    path = _resource_path(root, entry)
    relpath = _rel(root, path)
    if path.exists():
        if path.is_symlink():
            findings.append(Finding("error", relpath, "resource_symlink", "manifest-listed resource must not be a symlink"))
            is_safe = False
        elif not path.is_file():
            findings.append(Finding("error", relpath, "resource_not_regular_file", "manifest-listed resource must be a regular file"))
            is_safe = False
    else:
        findings.append(Finding("error", relpath, "resource_missing", "manifest-listed resource file is missing"))
        is_safe = False
    return {
        "resource_type": entry.resource_type,
        "language": entry.language,
        "name": entry.name,
        "manifest_path": entry.manifest_path,
        "manifest_line": entry.manifest_line,
        "components": components,
        "extension": extension,
        "safe_namespace": is_safe,
        "resource_path": relpath,
    }


def audit(root: Path) -> dict[str, object]:
    root = root.resolve()
    findings: list[Finding] = []
    entries: list[ManifestEntry] = []
    for resource_type in ("display", "xml"):
        manifest_entries, manifest_findings = _read_manifest(root, _manifest_path(root, resource_type))
        entries.extend(manifest_entries)
        findings.extend(manifest_findings)
    names: list[dict[str, object]] = []
    seen: dict[tuple[str, str, str], ManifestEntry] = {}
    for entry in entries:
        key = (entry.resource_type, entry.language, entry.name)
        where = f"{entry.manifest_path}:{entry.manifest_line}"
        if key in seen:
            findings.append(Finding("error", where, "duplicate_manifest_entry", "resource type/language/name appears more than once in manifest rows"))
        else:
            seen[key] = entry
        if entry.resource_type in VALID_TYPE:
            names.append(_audit_name(root, entry, findings))
    errors = sum(1 for finding in findings if finding.level == "error")
    warnings = sum(1 for finding in findings if finding.level == "warning")
    return {
        "schema": "queuebash.display_resource_namespace_audit.v1",
        "status": "ok" if errors == 0 else "error",
        "renderer": "none-namespace-audit-only",
        "root": str(root),
        "resource_rendering": False,
        "token_substitution": False,
        "secret_rendering": False,
        "provider_calls": False,
        "signing_mutation": False,
        "install_mutation": False,
        "permission_mutation": False,
        "json_contract_source": False,
        "summary": {
            "manifest_entries": len(entries),
            "audited_names": len(names),
            "errors": errors,
            "warnings": warnings,
            "max_name_length": MAX_NAME_LEN,
        },
        "names": names,
        "findings": [asdict(finding) for finding in findings],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit bashqueues display/XML resource namespace metadata")
    parser.add_argument("--root", default=".", help="repository or installed-share root to audit")
    parser.add_argument("--json", action="store_true", help="emit JSON evidence")
    args = parser.parse_args()
    result = audit(Path(args.root))
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(f"display resource namespace audit: {result['status']}")
        print(json.dumps(result["summary"], sort_keys=True))
    return 0 if result["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
