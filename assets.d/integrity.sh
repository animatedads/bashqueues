#!/usr/bin/env bash
# bashqueues asset plugin: integrity
# Operational payload/config integrity gates.
#
# Purpose:
#   Keep critical classes from silently running a changed script/config tree.
#   This is separate from bashqueues code/plugin signing: it verifies the
#   payloads and inputs the queued job relies on.

queue_asset_facilities() {
    cat <<'FACILITIES'
integrity:file_sha256	Blocks dispatch unless a file's SHA256 matches the approved value
integrity:manifest_verified	Blocks dispatch unless every file listed in a manifest matches its SHA256
integrity:tree_manifest_verified	Blocks dispatch unless manifest entries under a tree match their SHA256 values
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
integrity:file_sha256	target=file path	params=sha256=HEX		example=queue_class_shared_asset integrity file_sha256 /opt/jobs/month_end.sh sha256=abc123...	notes=Strict single-file immutable payload check.
integrity:manifest_verified	target=manifest path	params=allow_user_manifest=0|1		example=queue_class_shared_asset integrity manifest_verified /etc/queuebash/manifests/month_end.manifest	notes=Manifest lines may be '<sha256> <path>' or 'sha256 <path> <hash>'. Blank lines and # comments are ignored.
integrity:tree_manifest_verified	target=tree root	params=manifest=/path/to/manifest allow_user_manifest=0|1		example=queue_class_shared_asset integrity tree_manifest_verified /opt/batch/month_end manifest=/etc/queuebash/manifests/month_end.tree	notes=Relative manifest paths are resolved under the tree root; absolute paths must remain inside the tree.
EOF_HINTS
}

queue_asset_param() {
    local key="$1" p
    shift || true
    for p in "$@"; do
        case "$p" in
            "$key="*) printf '%s\n' "${p#*=}"; return 0 ;;
        esac
    done
    return 1
}

_queue_asset_integrity_sha256_valid() {
    [[ "${1:-}" =~ ^[A-Fa-f0-9]{64}$ ]]
}

_queue_asset_integrity_sha256_file() {
    local file="$1"
    sha256sum -- "$file" 2>/dev/null | awk '{print $1}'
}

_queue_asset_integrity_abs() {
    local p="$1"
    if command -v realpath >/dev/null 2>&1; then
        realpath -m -- "$p" 2>/dev/null
    else
        python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$p" 2>/dev/null
    fi
}

_queue_asset_integrity_is_under() {
    local child base
    child="$(_queue_asset_integrity_abs "$1")" || return 1
    base="$(_queue_asset_integrity_abs "$2")" || return 1
    [[ "$child" == "$base" || "$child" == "$base"/* ]]
}

_queue_asset_integrity_manifest_safe() {
    local manifest="$1" allow_user_manifest="${2:-0}" qroot st_mode
    [[ -r "$manifest" ]] || { echo "asset_check_blocked: integrity:manifest manifest_not_readable path=$manifest"; return 1; }

    qroot="${QUEUEBASH_ROOT:-$HOME/.queuebash}"
    if [[ "$allow_user_manifest" != "1" ]] && _queue_asset_integrity_is_under "$manifest" "$qroot"; then
        echo "asset_check_blocked: integrity:manifest manifest_under_queue_root path=$manifest allow_user_manifest=1_required"
        return 1
    fi

    if command -v stat >/dev/null 2>&1; then
        st_mode="$(stat -c '%a' -- "$manifest" 2>/dev/null || true)"
        if [[ "$st_mode" =~ ^[0-9]+$ ]]; then
            # Last two octal digits represent group/other permissions.  If any
            # write bit is present, a non-owner can amend the approved manifest.
            local group other
            group=$(( (10#$st_mode / 10) % 10 ))
            other=$(( 10#$st_mode % 10 ))
            if (( (group & 2) != 0 || (other & 2) != 0 )); then
                echo "asset_check_blocked: integrity:manifest manifest_group_or_other_writable path=$manifest mode=$st_mode"
                return 1
            fi
        fi
    fi

    return 0
}

_queue_asset_integrity_parse_manifest_line() {
    local line="$1" a b c
    # Output: '<hash>\t<path>'
    [[ -n "$line" ]] || return 1
    [[ "$line" =~ ^[[:space:]]*# ]] && return 1
    # shellcheck disable=SC2086
    set -- $line
    case "$#" in
        0) return 1 ;;
        2)
            a="$1"; b="$2"
            if _queue_asset_integrity_sha256_valid "$a"; then
                printf '%s\t%s\n' "$a" "$b"
                return 0
            fi
            ;;
        *)
            a="$1"; b="$2"; c="$3"
            if [[ "$a" == "sha256" ]] && _queue_asset_integrity_sha256_valid "$c"; then
                printf '%s\t%s\n' "$c" "$b"
                return 0
            fi
            if _queue_asset_integrity_sha256_valid "$a"; then
                printf '%s\t%s\n' "$a" "$b"
                return 0
            fi
            ;;
    esac
    echo "asset_check_blocked: integrity:manifest invalid_manifest_line line=${line@Q}"
    return 2
}

queue_asset_check_integrity_file_sha256() {
    local file="$1" expected actual
    shift || true
    expected="$(queue_asset_param sha256 "$@" || true)"

    [[ -n "$file" ]] || { echo "asset_check_blocked: integrity:file_sha256 file_required"; return 1; }
    [[ -r "$file" ]] || { echo "asset_check_blocked: integrity:file_sha256 file_not_readable path=$file"; return 1; }
    _queue_asset_integrity_sha256_valid "$expected" || { echo "asset_check_blocked: integrity:file_sha256 invalid_or_missing_sha256 path=$file"; return 1; }

    actual="$(_queue_asset_integrity_sha256_file "$file")"
    _queue_asset_integrity_sha256_valid "$actual" || { echo "asset_check_blocked: integrity:file_sha256 cannot_hash path=$file"; return 1; }

    if [[ "${actual,,}" == "${expected,,}" ]]; then
        echo "asset_check_ok: integrity:file_sha256 path=$file sha256=$actual"
        return 0
    fi

    echo "asset_check_blocked: integrity:file_sha256 mismatch path=$file expected=${expected,,} actual=$actual"
    return 1
}

queue_asset_check_integrity_manifest_verified() {
    local manifest="$1" allow parsed expected file actual rc=0 count=0
    shift || true
    allow="$(queue_asset_param allow_user_manifest "$@" || echo 0)"

    [[ -n "$manifest" ]] || { echo "asset_check_blocked: integrity:manifest_verified manifest_required"; return 1; }
    _queue_asset_integrity_manifest_safe "$manifest" "$allow" || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        parsed="$(_queue_asset_integrity_parse_manifest_line "$line")" || {
            [[ "$?" -eq 1 ]] && continue
            rc=1; continue
        }
        expected="${parsed%%$'\t'*}"
        file="${parsed#*$'\t'}"
        count=$((count + 1))
        [[ -r "$file" ]] || { echo "asset_check_blocked: integrity:manifest_verified file_not_readable path=$file manifest=$manifest"; rc=1; continue; }
        actual="$(_queue_asset_integrity_sha256_file "$file")"
        if [[ "${actual,,}" != "${expected,,}" ]]; then
            echo "asset_check_blocked: integrity:manifest_verified mismatch path=$file expected=${expected,,} actual=$actual manifest=$manifest"
            rc=1
        fi
    done < "$manifest"

    if (( count == 0 )); then
        echo "asset_check_blocked: integrity:manifest_verified empty_manifest path=$manifest"
        return 1
    fi

    if (( rc == 0 )); then
        echo "asset_check_ok: integrity:manifest_verified manifest=$manifest files=$count"
    fi
    return "$rc"
}

queue_asset_check_integrity_tree_manifest_verified() {
    local tree="$1" manifest allow parsed expected rel file actual tree_abs file_abs rc=0 count=0
    shift || true
    manifest="$(queue_asset_param manifest "$@" || true)"
    allow="$(queue_asset_param allow_user_manifest "$@" || echo 0)"

    [[ -n "$tree" ]] || { echo "asset_check_blocked: integrity:tree_manifest_verified tree_required"; return 1; }
    [[ -d "$tree" ]] || { echo "asset_check_blocked: integrity:tree_manifest_verified tree_not_directory path=$tree"; return 1; }
    [[ -n "$manifest" ]] || { echo "asset_check_blocked: integrity:tree_manifest_verified manifest_param_required tree=$tree"; return 1; }
    _queue_asset_integrity_manifest_safe "$manifest" "$allow" || return 1
    tree_abs="$(_queue_asset_integrity_abs "$tree")" || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        parsed="$(_queue_asset_integrity_parse_manifest_line "$line")" || {
            [[ "$?" -eq 1 ]] && continue
            rc=1; continue
        }
        expected="${parsed%%$'\t'*}"
        rel="${parsed#*$'\t'}"
        if [[ "$rel" = /* ]]; then
            file="$rel"
        else
            file="$tree_abs/$rel"
        fi
        file_abs="$(_queue_asset_integrity_abs "$file")" || { rc=1; continue; }
        if ! _queue_asset_integrity_is_under "$file_abs" "$tree_abs"; then
            echo "asset_check_blocked: integrity:tree_manifest_verified path_outside_tree path=$file_abs tree=$tree_abs manifest=$manifest"
            rc=1
            continue
        fi
        count=$((count + 1))
        [[ -r "$file_abs" ]] || { echo "asset_check_blocked: integrity:tree_manifest_verified file_not_readable path=$file_abs manifest=$manifest"; rc=1; continue; }
        actual="$(_queue_asset_integrity_sha256_file "$file_abs")"
        if [[ "${actual,,}" != "${expected,,}" ]]; then
            echo "asset_check_blocked: integrity:tree_manifest_verified mismatch path=$file_abs expected=${expected,,} actual=$actual manifest=$manifest"
            rc=1
        fi
    done < "$manifest"

    if (( count == 0 )); then
        echo "asset_check_blocked: integrity:tree_manifest_verified empty_manifest path=$manifest tree=$tree_abs"
        return 1
    fi

    if (( rc == 0 )); then
        echo "asset_check_ok: integrity:tree_manifest_verified tree=$tree_abs manifest=$manifest files=$count"
    fi
    return "$rc"
}
