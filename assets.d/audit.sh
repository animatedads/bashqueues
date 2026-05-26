#!/usr/bin/env bash
# bashqueues asset plugin: audit
# Governance checks for audit/event stream availability.

queue_asset_facilities() {
    cat <<'FACILITIES'
audit:stream_verified	Checks audit/event logging is active for the requested classification
FACILITIES
}

queue_asset_hints() {
    cat <<'HINTS'
audit:stream_verified	target=classification	params=require_remote=auto require_auditd=auto stream_file=/path/to/events.jsonl	example=queue_class_shared_asset audit stream_verified "SENSITIVE" require_remote=1	notes=For higher classifications, blocks unless audit/event logging and optional remote audit sink are configured.
HINTS
}

queue_asset_param() {
    local key="$1" p
    shift || true
    for p in "$@"; do
        case "$p" in "$key="*) printf '%s\n' "${p#*=}"; return 0 ;; esac
    done
    return 1
}

_audit_bool_true() { case "${1:-}" in 1|yes|true|on|Y|y) return 0 ;; *) return 1 ;; esac; }
_audit_upper() { printf '%s' "${1:-}" | tr '[:lower:]-' '[:upper:]_'; }

queue_asset_check_audit_stream_verified() {
    local token="$1" classification="$2"; shift 2 || true
    local require_auditd require_remote stream_file remote_conf level
    require_auditd="$(queue_asset_param require_auditd "$@" || echo auto)"
    require_remote="$(queue_asset_param require_remote "$@" || echo auto)"
    stream_file="$(queue_asset_param stream_file "$@" || echo "${QUEUEBASH_ROOT:-${HOME:-}/.queuebash}/events.jsonl")"
    remote_conf="$(queue_asset_param remote_conf "$@" || echo /etc/audit/auditd.conf)"
    level="$(_audit_upper "$classification")"

    if [[ "$require_auditd" == "auto" ]]; then
        case "$level" in SENSITIVE|OFFICIAL_SENSITIVE|CONFIDENTIAL|SECRET|HIPAA|PROTECTED|CUI) require_auditd=1 ;; *) require_auditd=0 ;; esac
    fi
    if [[ "$require_remote" == "auto" ]]; then
        case "$level" in SENSITIVE|OFFICIAL_SENSITIVE|CONFIDENTIAL|SECRET|HIPAA|PROTECTED|CUI) require_remote=1 ;; *) require_remote=0 ;; esac
    fi

    if _audit_bool_true "$require_auditd"; then
        if command -v systemctl >/dev/null 2>&1; then
            systemctl is-active --quiet auditd || { echo "asset_check_blocked: audit:stream_verified auditd_not_running classification=$level"; return 1; }
        elif [[ ! -d /var/log/audit && ! -f /var/log/audit/audit.log ]]; then
            echo "asset_check_blocked: audit:stream_verified auditd_unknown classification=$level"
            return 1
        fi
    fi

    [[ -n "$stream_file" ]] || { echo "asset_check_blocked: audit:stream_verified stream_file_required"; return 1; }
    mkdir -p "$(dirname "$stream_file")" 2>/dev/null || true
    if [[ ! -e "$stream_file" ]]; then
        : > "$stream_file" 2>/dev/null || { echo "asset_check_blocked: audit:stream_verified stream_unwritable=$stream_file"; return 1; }
    fi
    [[ -w "$stream_file" ]] || { echo "asset_check_blocked: audit:stream_verified stream_unwritable=$stream_file"; return 1; }

    if _audit_bool_true "$require_remote"; then
        if [[ -f "$remote_conf" ]] && grep -Eq '^[[:space:]]*(remote_server|dispatcher|action_mail_acct|name_format)[[:space:]]*=' "$remote_conf"; then
            :
        elif [[ -n "${QUEUEBASH_AUDIT_REMOTE_SINK:-}" ]]; then
            :
        else
            echo "asset_check_blocked: audit:stream_verified no_remote_audit_sink classification=$level"
            return 1
        fi
    fi

    echo "asset_check_ok: $token classification=$level stream=$stream_file"
}
