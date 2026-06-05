#!/usr/bin/env python3
"""Read-only locale/directory audit helper for bashqueues display/XML resources.

The helper inspects display/XML resource manifests and resource directory names
for release-review locale hygiene. It reports malformed language identifiers,
missing language directories, duplicate manifest rows, fallback row coverage, and
unmanifested locale directories without rendering templates, substituting tokens,
reading secrets, signing, installing, changing file modes/owners, or generating
command/provider JSON.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path

SHELL_RE = re.compile(r"\$\{|\$\(|`")
SECRET_VALUE_RE = re.compile(r"(?i)(actual[-_ ]?secret|secret[-_ ]?value|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16})")
LANGUAGE_RE = re.compile(r"^(fallback|lang_[a-z][a-z0-9_]{1,31})$")
VALID_TYPE = {"display", "xml"}
SPECIAL_DIRS = {"fallback"}
MANIFEST_NAME = "manifest.example.tsv"


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


def _language_dirs(root: Path, resource_type: str, findings: list[Finding]) -> list[str]:
    base = _resource_base(root, resource_type)
    relbase = _rel(root, base)
    if not base.exists():
        findings.append(Finding("error", relbase, "resource_base_missing", "resource base directory is not present"))
        return []
    if base.is_symlink():
        findings.append(Finding("error", relbase, "resource_base_symlink", "resource base directory must not be a symlink"))
        return []
    if not base.is_dir():
        findings.append(Finding("error", relbase, "resource_base_not_directory", "resource base must be a directory"))
        return []
    dirs: list[str] = []
    for child in sorted(base.iterdir(), key=lambda p: p.name):
        if child.name == MANIFEST_NAME:
            continue
        rel = _rel(root, child)
        if child.is_symlink():
            findings.append(Finding("error", rel, "language_dir_symlink", "language directory must not be a symlink"))
            continue
        if not child.is_dir():
            findings.append(Finding("warning", rel, "non_directory_in_resource_base", "non-directory entry is ignored by locale audit"))
            continue
        dirs.append(child.name)
        if child.name not in SPECIAL_DIRS and not LANGUAGE_RE.match(child.name):
            findings.append(Finding("warning", rel, "language_dir_name_unusual", "language directory should be fallback or lang_<identifier>"))
    return dirs


def _audit_resource_type(root: Path, resource_type: str) -> tuple[dict[str, object], list[Finding]]:
    findings: list[Finding] = []
    manifest_entries, manifest_findings = _read_manifest(root, _manifest_path(root, resource_type))
    findings.extend(manifest_findings)
    dirs = _language_dirs(root, resource_type, findings)

    languages_in_manifest = sorted({entry.language for entry in manifest_entries})
    dirs_set = set(dirs)
    manifest_lang_set = set(languages_in_manifest)
    duplicate_keys: dict[tuple[str, str, str], list[str]] = {}
    for entry in manifest_entries:
        key = (entry.resource_type, entry.language, entry.name)
        duplicate_keys.setdefault(key, []).append(f"{entry.manifest_path}:{entry.manifest_line}")
        lang_path = _resource_base(root, entry.resource_type) / entry.language
        if entry.language not in dirs_set:
            findings.append(Finding("error", f"{entry.manifest_path}:{entry.manifest_line}", "language_directory_missing", f"manifest language directory is missing: {entry.language}"))
        resource = _resource_path(root, entry)
        if resource.is_symlink():
            findings.append(Finding("error", _rel(root, resource), "resource_symlink", "manifest-listed resource must not be a symlink"))
        elif not resource.exists():
            findings.append(Finding("error", _rel(root, resource), "resource_missing", "manifest-listed resource file is missing"))
        elif not resource.is_file():
            findings.append(Finding("error", _rel(root, resource), "resource_not_regular_file", "manifest-listed resource must be a regular file"))
        if lang_path.exists() and lang_path.is_symlink():
            findings.append(Finding("error", _rel(root, lang_path), "language_directory_symlink", "language directory must not be a symlink"))

    duplicates = []
    for key, locations in sorted(duplicate_keys.items()):
        if len(locations) > 1:
            resource_type_key, language, name = key
            duplicates.append({"resource_type": resource_type_key, "language": language, "name": name, "locations": locations})
            findings.append(Finding("error", locations[0], "duplicate_manifest_entry", f"duplicate manifest row for {language}/{name}"))

    unmanifested_dirs = sorted(dirs_set - manifest_lang_set)
    for language in unmanifested_dirs:
        findings.append(Finding("warning", _rel(root, _resource_base(root, resource_type) / language), "language_directory_unmanifested", "language directory has no manifest rows"))

    missing_dirs = sorted(manifest_lang_set - dirs_set)
    fallback_manifested = "fallback" in manifest_lang_set
    fallback_dir_present = "fallback" in dirs_set
    if not fallback_manifested:
        findings.append(Finding("error", _rel(root, _manifest_path(root, resource_type)), "fallback_language_unmanifested", "fallback language must have manifest rows"))
    if not fallback_dir_present:
        findings.append(Finding("error", _rel(root, _resource_base(root, resource_type) / "fallback"), "fallback_directory_missing", "fallback directory is required"))

    item = {
        "resource_type": resource_type,
        "manifest_path": _rel(root, _manifest_path(root, resource_type)),
        "manifest_entry_count": len(manifest_entries),
        "languages_in_manifest": languages_in_manifest,
        "language_directories": sorted(dirs),
        "missing_language_directories": missing_dirs,
        "unmanifested_language_directories": unmanifested_dirs,
        "fallback_manifested": fallback_manifested,
        "fallback_directory_present": fallback_dir_present,
        "duplicate_manifest_entries": duplicates,
    }
    return item, findings


def audit(root: Path) -> dict[str, object]:
    root = root.resolve()
    all_findings: list[Finding] = []
    resources = []
    for resource_type in sorted(VALID_TYPE):
        item, findings = _audit_resource_type(root, resource_type)
        resources.append(item)
        all_findings.extend(findings)
    errors = sum(1 for finding in all_findings if finding.level == "error")
    warnings = sum(1 for finding in all_findings if finding.level == "warning")
    return {
        "schema": "queuebash.display_resource_locale_audit.v1",
        "status": "ok" if errors == 0 else "error",
        "root": str(root),
        "renderer": "none-locale-audit-only",
        "resource_rendering": False,
        "token_substitution": False,
        "secret_rendering": False,
        "provider_calls": False,
        "signing_mutation": False,
        "install_mutation": False,
        "permission_mutation": False,
        "json_contract_source": False,
        "summary": {"resource_type_count": len(resources), "errors": errors, "warnings": warnings},
        "resources": resources,
        "findings": [asdict(finding) for finding in all_findings],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit bashqueues display/XML resource locale directory coverage without rendering resources.")
    parser.add_argument("--root", default=".", help="repository/root directory to inspect")
    parser.add_argument("--json", action="store_true", help="emit JSON evidence")
    args = parser.parse_args()
    result = audit(Path(args.root))
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        summary = result["summary"]
        print(f"display resource locale audit: status={result['status']} errors={summary['errors']} warnings={summary['warnings']}")
        for finding in result["findings"]:
            print(f"{finding['level']}: {finding['path']}: {finding['code']}: {finding['message']}")
    return 0 if result["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
