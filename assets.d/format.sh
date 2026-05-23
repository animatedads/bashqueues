#!/usr/bin/env bash
# bashqueues standard file format validation asset checks

queue_asset_facilities() {
    cat <<'FACILITIES'
format:json	Checks that a target file contains structurally valid JSON
format:xml	Checks that a target file contains structurally valid XML
format:yaml	Checks that a target file contains structurally valid YAML
format:csv	Checks CSV readability (handles quoted newlines/commas)
format:archive	Tests integrity of .zip, .gz, or .tar files
format:sqlite	Runs a PRAGMA integrity_check on a SQLite3 database
FACILITIES
}

queue_asset_param() {
    local key="$1"
    shift
    local p
    for p in "$@"; do
        case "$p" in
            "$key="*) printf '%s\n' "${p#*=}"; return 0 ;;
        esac
    done
    return 1
}

queue_asset_check_format_json() {
    local token="$1" target_file="$2"
    shift 2 || true
    [[ -f "$target_file" ]] || { echo "asset_check_blocked: format:json target missing: $target_file"; return 1; }
    if command -v jq >/dev/null 2>&1; then
        jq -e . "$target_file" >/dev/null 2>&1 && { echo "asset_check_ok: $token"; return 0; }
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c 'import json, sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$target_file" >/dev/null 2>&1 && { echo "asset_check_ok: $token"; return 0; }
    else
        echo "asset_check_blocked: format:json requires jq or python3"; return 1
    fi
    echo "asset_check_blocked: format:json invalid syntax: $target_file"; return 1
}

queue_asset_check_format_xml() {
    local token="$1" target_file="$2"
    shift 2 || true
    [[ -f "$target_file" ]] || { echo "asset_check_blocked: format:xml target missing: $target_file"; return 1; }
    if command -v xmllint >/dev/null 2>&1; then
        xmllint --noout "$target_file" >/dev/null 2>&1 && { echo "asset_check_ok: $token"; return 0; }
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c 'import xml.etree.ElementTree as ET, sys; ET.parse(sys.argv[1])' "$target_file" >/dev/null 2>&1 && { echo "asset_check_ok: $token"; return 0; }
    else
        echo "asset_check_blocked: format:xml requires xmllint or python3"; return 1
    fi
    echo "asset_check_blocked: format:xml invalid syntax: $target_file"; return 1
}

queue_asset_check_format_yaml() {
    local token="$1" target_file="$2"
    shift 2 || true
    [[ -f "$target_file" ]] || { echo "asset_check_blocked: format:yaml target missing: $target_file"; return 1; }
    if command -v yq >/dev/null 2>&1; then
        yq e '.' "$target_file" >/dev/null 2>&1 && { echo "asset_check_ok: $token"; return 0; }
    elif command -v ruby >/dev/null 2>&1; then
        ruby -ryaml -e 'YAML.load_file(ARGV[0])' "$target_file" >/dev/null 2>&1 && { echo "asset_check_ok: $token"; return 0; }
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c 'import sys; import yaml; yaml.safe_load(open(sys.argv[1], encoding="utf-8"))' "$target_file" >/dev/null 2>&1 && { echo "asset_check_ok: $token"; return 0; }
    else
        echo "asset_check_blocked: format:yaml requires yq, ruby, or python3+PyYAML"; return 1
    fi
    echo "asset_check_blocked: format:yaml invalid syntax: $target_file"; return 1
}

queue_asset_check_format_csv() {
    local token="$1" target_file="$2"
    shift 2 || true
    [[ -f "$target_file" ]] || { echo "asset_check_blocked: format:csv target missing: $target_file"; return 1; }
    local strict_columns
    strict_columns="$(queue_asset_param strict_columns "$@" || echo 0)"
    command -v python3 >/dev/null 2>&1 || { echo "asset_check_blocked: format:csv requires python3"; return 1; }
    if python3 - "$target_file" "$strict_columns" >/dev/null 2>&1 <<'PY'
import csv
import sys
path = sys.argv[1]
strict = sys.argv[2] == "1"
try:
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        header = next(reader, None)
        if header is None:
            sys.exit(0)
        width = len(header)
        for row in reader:
            if strict and len(row) != width:
                sys.exit(2)
except Exception:
    sys.exit(1)
PY
    then
        echo "asset_check_ok: $token"; return 0
    fi
    rc="$?"
    if [[ "$rc" == "2" ]]; then
        echo "asset_check_blocked: format:csv strict_columns=1 failed: $target_file"
    else
        echo "asset_check_blocked: format:csv unreadable or malformed: $target_file"
    fi
    return 1
}

queue_asset_check_format_archive() {
    local token="$1" target_file="$2"
    shift 2 || true
    [[ -f "$target_file" ]] || { echo "asset_check_blocked: format:archive target missing: $target_file"; return 1; }
    local mimetype
    mimetype="$(file -b --mime-type "$target_file" 2>/dev/null || true)"
    case "$mimetype" in
        application/gzip|application/x-gzip) gzip -t "$target_file" >/dev/null 2>&1 && { echo "asset_check_ok: $token"; return 0; } ;;
        application/zip) unzip -tq "$target_file" >/dev/null 2>&1 && { echo "asset_check_ok: $token"; return 0; } ;;
        application/x-tar) tar -tf "$target_file" >/dev/null 2>&1 && { echo "asset_check_ok: $token"; return 0; } ;;
        *) echo "asset_check_blocked: format:archive unsupported archive type ($mimetype): $target_file"; return 1 ;;
    esac
    echo "asset_check_blocked: format:archive corrupt or truncated: $target_file"; return 1
}

queue_asset_check_format_sqlite() {
    local token="$1" target_file="$2"
    shift 2 || true
    [[ -f "$target_file" ]] || { echo "asset_check_blocked: format:sqlite target missing: $target_file"; return 1; }
    command -v sqlite3 >/dev/null 2>&1 || { echo "asset_check_blocked: format:sqlite requires sqlite3"; return 1; }
    local result
    result="$(sqlite3 "$target_file" 'PRAGMA integrity_check;' 2>/dev/null || true)"
    if [[ "$result" == "ok" ]]; then echo "asset_check_ok: $token"; return 0; fi
    echo "asset_check_blocked: format:sqlite corrupt or not sqlite3: $target_file"; return 1
}
