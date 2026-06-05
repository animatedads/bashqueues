#!/usr/bin/env python3
"""Read-only surface-label audit helper for bashqueues display/XML resources.

The helper inspects display/XML resource manifests and their human-facing
surface metadata for release-review hygiene. It reports empty, overlong,
unsafe, duplicate, or secret-looking surface labels without rendering
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

SHELL_RE = re.compile(r"\$\{|\$\(|`")
SECRET_VALUE_RE = re.compile(r"(?i)(actual[-_ ]?secret|secret[-_ ]?value|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16})")
SECRET_SURFACE_RE = re.compile(r"(?i)\b(password|passwd|secret|token|api[-_ ]?key|private[-_ ]?key|credential)\b")
SURFACE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 _.,:/()@+\-]{0,119}$")
LANGUAGE_RE = re.compile(r"^(fallback|lang_[a-z][a-z0-9_]{1,31})$")
VALID_TYPE = {"display", "xml"}
MANIFEST_NAME = "manifest.example.tsv"
MAX_SURFACE_LEN = 120


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
    with path.open(newline="", encoding="utf-8") as fh:
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


def _audit_surface(entry: ManifestEntry, findings: list[Finding]) -> dict[str, object]:
    where = f"{entry.manifest_path}:{entry.manifest_line}"
    surface = entry.surface
    trimmed = surface.strip()
    safe_surface = True
    if not trimmed:
        findings.append(Finding("error", where, "surface_empty", "surface label must not be empty"))
        safe_surface = False
    if surface != trimmed:
        findings.append(Finding("warning", where, "surface_outer_whitespace", "surface label has leading or trailing whitespace"))
    if len(surface) > MAX_SURFACE_LEN:
        findings.append(Finding("warning", where, "surface_overlong", "surface label is longer than the reviewed limit"))
        safe_surface = False
    if SHELL_RE.search(surface):
        findings.append(Finding("error", where, "surface_shell_expansion", "surface label contains shell-looking expansion"))
        safe_surface = False
    if SECRET_VALUE_RE.search(surface):
        findings.append(Finding("error", where, "surface_secret_value", "surface label appears to contain a concrete secret value"))
        safe_surface = False
    if SECRET_SURFACE_RE.search(surface):
        findings.append(Finding("warning", where, "surface_secret_word", "surface label contains a secret-looking word and should be reviewed"))
    if trimmed and not SURFACE_RE.match(surface):
        findings.append(Finding("warning", where, "surface_unsafe_characters", "surface label contains characters outside the reviewed display metadata set"))
        safe_surface = False
    return {
        "resource_type": entry.resource_type,
        "name": entry.name,
        "language": entry.language,
        "surface": surface,
        "surface_length": len(surface),
        "safe_surface": safe_surface,
        "manifest_path": entry.manifest_path,
        "manifest_line": entry.manifest_line,
    }


def audit(root: Path) -> dict[str, object]:
    root = root.resolve()
    findings: list[Finding] = []
    entries: list[ManifestEntry] = []
    for resource_type in sorted(VALID_TYPE):
        got, got_findings = _read_manifest(root, _manifest_path(root, resource_type))
        entries.extend(got)
        findings.extend(got_findings)

    surfaces: list[dict[str, object]] = []
    seen_row_keys: dict[tuple[str, str, str], ManifestEntry] = {}
    surface_by_resource: dict[tuple[str, str], set[str]] = {}
    for entry in entries:
        row_key = (entry.resource_type, entry.name, entry.language)
        where = f"{entry.manifest_path}:{entry.manifest_line}"
        if row_key in seen_row_keys:
            prev = seen_row_keys[row_key]
            findings.append(Finding(
                "error",
                where,
                "duplicate_manifest_entry",
                f"duplicate manifest row also appears at {prev.manifest_path}:{prev.manifest_line}",
            ))
        else:
            seen_row_keys[row_key] = entry
        surface_by_resource.setdefault((entry.resource_type, entry.name), set()).add(entry.surface)
        surfaces.append(_audit_surface(entry, findings))

    for (resource_type, name), values in sorted(surface_by_resource.items()):
        if len(values) > 1:
            findings.append(Finding(
                "warning",
                f"resources.d/{resource_type}/{name}",
                "surface_differs_by_language",
                "localized/fallback rows use different surface labels; verify this is deliberate",
            ))

    errors = sum(1 for f in findings if f.level == "error")
    warnings = sum(1 for f in findings if f.level == "warning")
    return {
        "schema": "queuebash.display_resource_surface_audit.v1",
        "status": "ok" if errors == 0 else "error",
        "renderer": "none-surface-audit-only",
        "root": str(root),
        "manifest_only": True,
        "resource_rendering": False,
        "resource_body_read": False,
        "token_substitution": False,
        "secret_rendering": False,
        "provider_calls": False,
        "signing_mutation": False,
        "install_mutation": False,
        "permission_mutation": False,
        "json_contract_source": False,
        "summary": {
            "entries": len(entries),
            "audited_surfaces": len(surfaces),
            "unique_surface_labels": len({str(s["surface"]) for s in surfaces}),
            "errors": errors,
            "warnings": warnings,
        },
        "surfaces": surfaces,
        "findings": [asdict(f) for f in findings],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit display/XML resource manifest surface labels.")
    parser.add_argument("--root", default=".", help="bashqueues source/install root")
    parser.add_argument("--json", action="store_true", help="emit JSON evidence")
    args = parser.parse_args()
    result = audit(Path(args.root))
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(f"{result['schema']} status={result['status']} surfaces={result['summary']['audited_surfaces']} errors={result['summary']['errors']} warnings={result['summary']['warnings']}")
        for finding in result["findings"]:
            print(f"{finding['level']}: {finding['path']}: {finding['code']}: {finding['message']}")
    return 0 if result["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
