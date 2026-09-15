#!/usr/bin/env python3
"""Read-only manifest-field audit helper for bashqueues display/XML resources.

The helper inspects display/XML resource manifests and validates the contract
shape of each TSV metadata field. It checks resource type/path consistency,
name shape, language shape, fallback flags, token-list syntax, surface and
notes metadata, JSON-source flags, and secret-rendering flags without rendering
templates, substituting tokens, reading resource bodies, reading secrets,
signing, installing, changing file modes/owners, or generating command/provider
JSON.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path

MANIFEST_NAME = "manifest.example.tsv"
RESOURCE_TYPES = ("display", "xml")
HEADER_FIELDS = [
    "resource_type",
    "name",
    "language",
    "fallback_required",
    "tokens",
    "surface",
    "json_contract_source",
    "secret_rendering_allowed",
    "notes",
]
LANGUAGE_RE = re.compile(r"^(fallback|lang_[a-z][a-z0-9_]{1,31})$")
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/-]{0,159}$")
SAFE_COMPONENT_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$")
TOKEN_RE = re.compile(r"^[A-Z][A-Z0-9_]{0,63}$")
SURFACE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 _.,:;/'()@+\-]{0,159}$")
NOTE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 _.,:;/'()@+\-]{0,199}$")
SHELL_RE = re.compile(r"\$\{|\$\(|`")
SECRET_VALUE_RE = re.compile(r"(?i)(actual[-_ ]?secret|secret[-_ ]?value|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16})")
SECRET_WORD_RE = re.compile(r"(?i)\b(password|passwd|secret|token|api[-_ ]?key|private[-_ ]?key|credential)\b")
BOUNDARY_WORD_RE = re.compile(r"(?i)\b(json contract|provider output|command output|dispatch|executor|runner|render secret|secret render|live provider|cloud mutation)\b")


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
    manifest_type: str
    manifest_path: str
    manifest_line: int


def _rel(root: Path, path: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def _manifest_path(root: Path, resource_type: str) -> Path:
    return root / "resources.d" / resource_type / MANIFEST_NAME


def _split_tokens(value: str) -> list[str]:
    value = value.strip()
    if not value:
        return []
    return [part.strip() for part in value.split(",")]


def _read_manifest(root: Path, manifest_type: str) -> tuple[list[ManifestEntry], list[Finding]]:
    path = _manifest_path(root, manifest_type)
    rel = _rel(root, path)
    entries: list[ManifestEntry] = []
    findings: list[Finding] = []
    if not path.exists():
        findings.append(Finding("error", rel, "manifest_missing", "manifest is not present"))
        return entries, findings
    if path.is_symlink():
        findings.append(Finding("error", rel, "manifest_symlink", "manifest must not be a symlink"))
        return entries, findings
    if not path.is_file():
        findings.append(Finding("error", rel, "manifest_not_regular_file", "manifest must be a regular file"))
        return entries, findings
    with path.open(newline="", encoding="utf-8") as fh:
        for lineno, raw in enumerate(fh, start=1):
            stripped = raw.strip()
            if not stripped:
                continue
            where = f"{rel}:{lineno}"
            if raw.startswith("#"):
                lowered = raw.lower()
                for field in HEADER_FIELDS:
                    if field not in lowered and "resource_type" in lowered:
                        findings.append(Finding("warning", where, "header_field_missing", f"header comment does not mention {field}"))
                continue
            if SHELL_RE.search(raw):
                findings.append(Finding("error", where, "manifest_shell_expansion", "manifest contains shell-looking expansion"))
            if SECRET_VALUE_RE.search(raw):
                findings.append(Finding("error", where, "manifest_secret_value", "manifest appears to contain concrete secret material"))
            row = next(csv.reader([raw], delimiter="\t"))
            if len(row) != len(HEADER_FIELDS):
                findings.append(Finding("error", where, "manifest_row_width", "manifest row must contain nine TSV fields"))
                continue
            entries.append(ManifestEntry(*row, manifest_type=manifest_type, manifest_path=rel, manifest_line=lineno))
    return entries, findings


def _resource_path(root: Path, entry: ManifestEntry) -> Path:
    return root / "resources.d" / entry.manifest_type / entry.language / entry.name


def _safe_name(name: str) -> bool:
    if not NAME_RE.match(name):
        return False
    if name.startswith(("/", "~")) or "//" in name:
        return False
    parts = name.split("/")
    return all(part not in ("", ".", "..") and SAFE_COMPONENT_RE.match(part) for part in parts)


def _audit_entry(root: Path, entry: ManifestEntry, findings: list[Finding]) -> dict[str, object]:
    where = f"{entry.manifest_path}:{entry.manifest_line}"
    tokens = _split_tokens(entry.tokens)
    field_ok = True

    def error(code: str, message: str) -> None:
        nonlocal field_ok
        field_ok = False
        findings.append(Finding("error", where, code, message))

    def warning(code: str, message: str) -> None:
        findings.append(Finding("warning", where, code, message))

    if entry.resource_type not in RESOURCE_TYPES:
        error("resource_type_invalid", f"unsupported resource_type: {entry.resource_type}")
    elif entry.resource_type != entry.manifest_type:
        error("resource_type_path_mismatch", "resource_type must match the manifest directory")

    if not _safe_name(entry.name):
        error("name_invalid", "resource name must be a relative safe path without traversal")
    if entry.resource_type == "xml" and not entry.name.endswith(".xml"):
        error("xml_name_extension", "XML resources should use a .xml name")
    if entry.resource_type == "display" and entry.name.endswith(".xml"):
        warning("display_name_xml_extension", "display resources should not use .xml names")

    if not LANGUAGE_RE.match(entry.language):
        error("language_invalid", "language must be fallback or lang_<identifier>")

    if entry.fallback_required not in {"yes", "no"}:
        error("fallback_required_invalid", "fallback_required must be yes or no")
    if entry.language == "fallback" and entry.fallback_required != "no":
        error("fallback_row_requires_no", "fallback rows must set fallback_required to no")
    if entry.language != "fallback" and entry.fallback_required == "no":
        warning("localized_row_no_fallback_required", "localized rows without fallback requirement should be reviewed")

    if not entry.tokens.strip():
        warning("tokens_empty", "token allow-list is empty")
    for token in tokens:
        if not TOKEN_RE.match(token):
            error("token_invalid", f"invalid token name: {token}")
        if SECRET_WORD_RE.search(token):
            error("token_secret_word", f"token name is secret-looking: {token}")
    if len(tokens) != len(set(tokens)):
        error("token_duplicate", "token allow-list contains duplicates")

    if not entry.surface.strip():
        error("surface_empty", "surface label must not be empty")
    elif len(entry.surface) > 160:
        warning("surface_overlong", "surface label is longer than the reviewed limit")
    elif not SURFACE_RE.match(entry.surface):
        warning("surface_unusual_characters", "surface label contains unusual characters")
    if BOUNDARY_WORD_RE.search(entry.surface):
        warning("surface_boundary_word", "surface label mentions display-boundary-sensitive behaviour")

    if entry.json_contract_source != "false":
        error("json_contract_source", "display/XML resources must not be JSON contract sources")
    if entry.secret_rendering_allowed != "false":
        error("secret_rendering_allowed", "display/XML resources must not render secrets")

    if not entry.notes.strip():
        warning("notes_empty", "notes field is empty")
    elif len(entry.notes) > 200:
        warning("notes_overlong", "notes field is longer than the reviewed limit")
    elif not NOTE_RE.match(entry.notes):
        warning("notes_unusual_characters", "notes field contains unusual characters")
    if SECRET_VALUE_RE.search(entry.notes):
        error("notes_secret_value", "notes field appears to contain concrete secret material")

    resource_path = _resource_path(root, entry)
    rel_resource = _rel(root, resource_path)
    if not resource_path.exists():
        error("resource_missing", "manifest-listed resource file is missing")
    elif resource_path.is_symlink():
        error("resource_symlink", "manifest-listed resource file must not be a symlink")
    elif not resource_path.is_file():
        error("resource_not_regular_file", "manifest-listed resource must be a regular file")

    return {
        "resource_type": entry.resource_type,
        "manifest_type": entry.manifest_type,
        "name": entry.name,
        "language": entry.language,
        "fallback_required": entry.fallback_required,
        "token_count": len(tokens),
        "field_contract_ok": field_ok,
        "resource_path": rel_resource,
        "resource_exists": resource_path.exists(),
        "manifest_path": entry.manifest_path,
        "manifest_line": entry.manifest_line,
    }


def audit(root: Path) -> dict[str, object]:
    root = root.resolve()
    entries: list[ManifestEntry] = []
    findings: list[Finding] = []
    for manifest_type in RESOURCE_TYPES:
        got_entries, got_findings = _read_manifest(root, manifest_type)
        entries.extend(got_entries)
        findings.extend(got_findings)

    audited: list[dict[str, object]] = []
    seen: dict[tuple[str, str, str], ManifestEntry] = {}
    for entry in entries:
        key = (entry.resource_type, entry.name, entry.language)
        where = f"{entry.manifest_path}:{entry.manifest_line}"
        if key in seen:
            prev = seen[key]
            findings.append(Finding("error", where, "duplicate_manifest_entry", f"duplicate row also appears at {prev.manifest_path}:{prev.manifest_line}"))
        else:
            seen[key] = entry
        audited.append(_audit_entry(root, entry, findings))

    errors = sum(1 for f in findings if f.level == "error")
    warnings = sum(1 for f in findings if f.level == "warning")
    return {
        "schema": "queuebash.display_resource_manifest_field_audit.v1",
        "status": "ok" if errors == 0 else "error",
        "renderer": "none-manifest-field-audit-only",
        "root": str(root),
        "manifest_only": True,
        "resource_body_read": False,
        "resource_rendering": False,
        "token_substitution": False,
        "secret_rendering": False,
        "provider_calls": False,
        "signing_mutation": False,
        "install_mutation": False,
        "permission_mutation": False,
        "json_contract_source": False,
        "summary": {
            "entries": len(entries),
            "audited_entries": len(audited),
            "field_contract_ok": sum(1 for item in audited if item["field_contract_ok"]),
            "errors": errors,
            "warnings": warnings,
        },
        "entries": audited,
        "findings": [asdict(f) for f in findings],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit display/XML resource manifest field contracts.")
    parser.add_argument("--root", default=".", help="bashqueues source/install root")
    parser.add_argument("--json", action="store_true", help="emit JSON evidence")
    args = parser.parse_args()
    result = audit(Path(args.root))
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(f"{result['schema']} status={result['status']} entries={result['summary']['audited_entries']} errors={result['summary']['errors']} warnings={result['summary']['warnings']}")
        for finding in result["findings"]:
            print(f"{finding['level']}: {finding['path']}: {finding['code']}: {finding['message']}")
    return 0 if result["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
