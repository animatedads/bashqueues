#!/usr/bin/env bash
# bashqueues asset plugin: secaudit
# Static security-audit gates for commands and shell scripts.

queue_asset_param() {
    local key="$1"
    shift || true
    local arg
    for arg in "$@"; do
        case "$arg" in
            "$key"=*) printf '%s\n' "${arg#*=}"; return 0 ;;
        esac
    done
    return 1
}

queue_asset_facilities() {
    cat <<'FACILITIES'
secaudit:no_destructive	Checks for destructive file/disk operations.
secaudit:no_network_c2	Checks for reverse shells and unauthorized network sockets.
secaudit:no_obfuscation	Checks for obfuscated payload execution.
secaudit:no_privesc	Checks for privilege escalation attempts.
secaudit:script_safe	Scans a target shell script for all dangerous patterns.
secaudit:string_safe	Scans a literal command string for dangerous patterns.
FACILITIES
}

queue_asset_hints() {
    cat <<'HINTS'
secaudit:script_safe	target=path to shell script	params=strict=0	example=queue_class_shared_asset secaudit script_safe "/opt/scripts/import.sh" strict=0	notes=Blocks obvious destructive, C2, privilege escalation, and obfuscation patterns before dispatch. strict=1 also runs shellcheck when available.
secaudit:string_safe	target=literal command string	params=strict=0	example=queue_class_shared_asset secaudit string_safe "bash publish_to_github.sh" strict=0	notes=Useful for generated cron or manager commands. Static audit is a safety net, not a runtime sandbox.
secaudit:no_destructive	target=script path or command string	params=allow_rm=0	example=queue_class_shared_asset secaudit no_destructive "/opt/scripts/cleanup.sh" allow_rm=0	notes=Looks for rm -rf style wipes, mkfs, dd disk wipes, fork bombs, and critical file/device overwrite patterns.
secaudit:no_network_c2	target=script path or command string	params=	example=queue_class_shared_asset secaudit no_network_c2 "/opt/ingest/parse_payload.sh"	notes=Looks for reverse shell and curl-pipe-shell patterns. Combine with sandbox=network-none or strict for runtime enforcement.
secaudit:no_privesc	target=script path or command string	params=allow_sudo=0	example=queue_class_shared_asset secaudit no_privesc "/opt/scripts/user_sync.sh" allow_sudo=0	notes=Looks for sudo, su, chmod 777, SUID changes, and root ownership changes.
secaudit:no_obfuscation	target=script path or command string	params=	example=queue_class_shared_asset secaudit no_obfuscation "/opt/scripts/generated.sh"	notes=Looks for eval of variables and base64-decoded payload execution.
HINTS
}

_secaudit_is_file() {
    [[ -f "${1:-}" ]]
}

_secaudit_read_target() {
    local target="$1"
    if _secaudit_is_file "$target"; then
        cat -- "$target" 2>/dev/null
    else
        printf '%s\n' "$target"
    fi
}

_secaudit_block() {
    local facility="$1" threat="$2" target="$3" line="${4:-}"
    if _secaudit_is_file "$target"; then
        if [[ -n "$line" ]]; then
            printf 'asset_check_blocked: secaudit:%s threat_detected=%q file=%q line=%q\n' "$facility" "$threat" "$target" "$line"
        else
            printf 'asset_check_blocked: secaudit:%s threat_detected=%q file=%q\n' "$facility" "$threat" "$target"
        fi
    else
        printf 'asset_check_blocked: secaudit:%s threat_detected=%q target=%q\n' "$facility" "$threat" "$target"
    fi
}

_secaudit_ok() {
    local facility="$1" target="$2"
    printf 'asset_check_ok: secaudit:%s target=%q\n' "$facility" "$target"
}

_secaudit_scan_patterns() {
    local facility="$1" target="$2"
    shift 2
    local name regex line data

    if _secaudit_is_file "$target"; then
        while [[ "$#" -gt 0 ]]; do
            name="$1"; regex="$2"; shift 2
            line="$(grep -nE "$regex" -- "$target" 2>/dev/null | head -1 | cut -d: -f1)"
            if [[ -n "$line" ]]; then
                _secaudit_block "$facility" "$name" "$target" "$line"
                return 1
            fi
        done
    else
        data="$(_secaudit_read_target "$target")"
        while [[ "$#" -gt 0 ]]; do
            name="$1"; regex="$2"; shift 2
            if printf '%s\n' "$data" | grep -Eq "$regex" 2>/dev/null; then
                _secaudit_block "$facility" "$name" "$target"
                return 1
            fi
        done
    fi

    return 0
}

queue_asset_check_secaudit_no_destructive() {
    local target="$1" allow_rm
    shift || true
    allow_rm="$(queue_asset_param allow_rm "$@" 2>/dev/null || echo 0)"
    local patterns=()
    if [[ "$allow_rm" != "1" ]]; then
        patterns+=( rm_recursive 'rm[[:space:]]+-[^\n;|&]*r[^\n;|&]*f[^\n;|&]*(/|/\*|\$|~)' )
    fi
    patterns+=(
        mkfs 'mkfs\.(ext|xfs|btrfs|fat|ntfs)'
        dd_wipe 'dd[[:space:]]+if=/dev/(zero|random|urandom)[[:space:]]+of='
        critical_overwrite '>[[:space:]]*(/dev/sd[a-z]|/dev/nvme|/etc/passwd|/etc/shadow)'
        fork_bomb ':\(\)[[:space:]]*\{[[:space:]]*:\|:&[[:space:]]*\};:'
    )
    _secaudit_scan_patterns no_destructive "$target" "${patterns[@]}" || return 1
    _secaudit_ok no_destructive "$target"
}

queue_asset_check_secaudit_no_network_c2() {
    local target="$1"
    _secaudit_scan_patterns no_network_c2 "$target" \
        dev_tcp '/dev/(tcp|udp)/[^/]+/[0-9]+' \
        nc_exec 'nc[[:space:]].*-e[[:space:]]+(/bin/)?(bash|sh)' \
        nc_listen 'nc[[:space:]]+-[^\n]*l[^\n]*(:[0-9]+|-p[[:space:]]+[0-9]+)' \
        ncat_listen 'ncat[[:space:]]+-[^\n]*l' \
        socat_listen 'socat[[:space:]].*TCP[46]?-LISTEN:' \
        python_socket_bind 'socket[[:space:]]*\([^)]*\).*\.bind[[:space:]]*\(|\.bind[[:space:]]*\([[:space:]]*\(' \
        bash_reverse 'bash[[:space:]]+-i[[:space:]]+>&' \
        curl_pipe_shell 'curl.*\|[[:space:]]*(bash|sh|zsh)' \
        wget_pipe_shell 'wget.*(-O[[:space:]]*-|--output-document[=[:space:]]*-).*\|[[:space:]]*(bash|sh|zsh)' || return 1
    _secaudit_ok no_network_c2 "$target"
}

queue_asset_check_secaudit_no_privesc() {
    local target="$1" allow_sudo
    shift || true
    allow_sudo="$(queue_asset_param allow_sudo "$@" 2>/dev/null || echo 0)"
    local patterns=()
    [[ "$allow_sudo" == "1" ]] || patterns+=( sudo '(^|[;&|])[[:space:]]*sudo[[:space:]]+' )
    patterns+=(
        su_root '(^|[;&|])[[:space:]]*su[[:space:]]+-'
        chmod_777 'chmod[[:space:]]+[0-7]*777'
        chmod_suid 'chmod[[:space:]]+(u\+s|4[0-7]{3})'
        chown_root 'chown[[:space:]]+root:'
    )
    _secaudit_scan_patterns no_privesc "$target" "${patterns[@]}" || return 1
    _secaudit_ok no_privesc "$target"
}

queue_asset_check_secaudit_no_obfuscation() {
    local target="$1"
    _secaudit_scan_patterns no_obfuscation "$target" \
        base64_pipe_shell '\|[[:space:]]*base64[[:space:]]+-d[[:space:]]*\|[[:space:]]*(bash|sh)' \
        eval_variable 'eval[[:space:]]+\$' || return 1
    _secaudit_ok no_obfuscation "$target"
}

queue_asset_check_secaudit_string_safe() {
    local target="$1" strict
    shift || true
    strict="$(queue_asset_param strict "$@" 2>/dev/null || echo 0)"
    queue_asset_check_secaudit_no_destructive "$target" "$@" || return 1
    queue_asset_check_secaudit_no_network_c2 "$target" "$@" || return 1
    queue_asset_check_secaudit_no_privesc "$target" "$@" || return 1
    queue_asset_check_secaudit_no_obfuscation "$target" "$@" || return 1
    _secaudit_ok string_safe "$target"
}

queue_asset_check_secaudit_script_safe() {
    local target="$1" strict
    shift || true
    if [[ ! -f "$target" ]]; then
        printf 'asset_check_blocked: secaudit:script_safe file_not_found=%q\n' "$target"
        return 1
    fi
    strict="$(queue_asset_param strict "$@" 2>/dev/null || echo 0)"
    if [[ "$strict" == "1" ]]; then
        if command -v shellcheck >/dev/null 2>&1; then
            if ! shellcheck -s bash -- "$target" >/tmp/bashqueues_secaudit_shellcheck.$$ 2>&1; then
                local msg
                msg="$(head -1 /tmp/bashqueues_secaudit_shellcheck.$$ 2>/dev/null || true)"
                rm -f /tmp/bashqueues_secaudit_shellcheck.$$
                printf 'asset_check_blocked: secaudit:script_safe tool=shellcheck finding=%q file=%q\n' "$msg" "$target"
                return 1
            fi
            rm -f /tmp/bashqueues_secaudit_shellcheck.$$
        else
            printf 'asset_check_blocked: secaudit:script_safe tool_missing=shellcheck file=%q\n' "$target"
            return 1
        fi
    fi
    queue_asset_check_secaudit_no_destructive "$target" "$@" || return 1
    queue_asset_check_secaudit_no_network_c2 "$target" "$@" || return 1
    queue_asset_check_secaudit_no_privesc "$target" "$@" || return 1
    queue_asset_check_secaudit_no_obfuscation "$target" "$@" || return 1
    _secaudit_ok script_safe "$target"
}
