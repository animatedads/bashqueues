#!/usr/bin/env bash
# bashqueues WinRM / PowerShell remoting asset checks

_WINRM_TIMEOUT="${WINRM_TIMEOUT:-10}"

queue_asset_facilities() {
    cat <<'FACILITIES'
winrm:connect	Validates WinRM connectivity to a Windows host using pywinrm
winrm:run_command	Runs a simple command through WinRM to validate execution
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
winrm:connect	target=https://host:5986/wsman	params=user=... password=... timeout=10	example=queue_class_shared_asset winrm connect https://winhost:5986/wsman user=svc password=$WINRM_PASSWORD	notes=Requires python3 and pywinrm.
winrm:run_command	target=https://host:5986/wsman	params=user=... password=... cmd=hostname timeout=10	example=queue_class_exclusive_asset winrm run_command https://winhost:5986/wsman user=svc password=$WINRM_PASSWORD cmd=hostname	notes=Runs a command through pywinrm. Keep cmd simple and trusted.
EOF_HINTS
}

_queue_asset_winrm_param() { queue_asset_param "$@"; }

_queue_asset_winrm_python() {
    local mode="$1" host="$2" user="$3" password="$4" cmd="$5"
    QB_WINRM_MODE="$mode" QB_WINRM_HOST="$host" QB_WINRM_USER="$user" QB_WINRM_PASSWORD="$password" QB_WINRM_CMD="$cmd" python3 - <<'PY'
import os, sys
try:
    import winrm
except ImportError:
    sys.exit(2)
host = os.environ.get('QB_WINRM_HOST', '')
user = os.environ.get('QB_WINRM_USER', '')
password = os.environ.get('QB_WINRM_PASSWORD', '')
mode = os.environ.get('QB_WINRM_MODE', 'connect')
cmd = os.environ.get('QB_WINRM_CMD', 'hostname')
try:
    s = winrm.Session(host, auth=(user, password))
    if mode == 'run_command':
        r = s.run_ps(cmd)
    else:
        r = s.run_cmd('echo', ['ok'])
    sys.exit(0 if getattr(r, 'status_code', 1) == 0 else 1)
except Exception:
    sys.exit(1)
PY
}

queue_asset_check_winrm_connect() {
    local token="$1" host="$2"; shift 2 || true
    local user password timeout
    user="$(_queue_asset_winrm_param user "$@" || true)"
    password="$(_queue_asset_winrm_param password "$@" || true)"
    timeout="$(_queue_asset_winrm_param timeout "$@" || echo "$_WINRM_TIMEOUT")"
    if ! command -v python3 >/dev/null 2>&1; then
        echo "asset_check_blocked: winrm:connect requires python3 with pywinrm"
        return 1
    fi
    if [[ -z "$host" || -z "$user" || -z "$password" ]]; then
        echo "asset_check_blocked: winrm:connect requires target=host user= password="
        return 1
    fi
    if timeout "$timeout" _queue_asset_winrm_python connect "$host" "$user" "$password" "" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: winrm:connect failed for $host"
    return 1
}

queue_asset_check_winrm_run_command() {
    local token="$1" host="$2"; shift 2 || true
    local user password cmd timeout
    user="$(_queue_asset_winrm_param user "$@" || true)"
    password="$(_queue_asset_winrm_param password "$@" || true)"
    cmd="$(_queue_asset_winrm_param cmd "$@" || echo "hostname")"
    timeout="$(_queue_asset_winrm_param timeout "$@" || echo "$_WINRM_TIMEOUT")"
    if ! command -v python3 >/dev/null 2>&1; then
        echo "asset_check_blocked: winrm:run_command requires python3 with pywinrm"
        return 1
    fi
    if [[ -z "$host" || -z "$user" || -z "$password" ]]; then
        echo "asset_check_blocked: winrm:run_command requires target=host user= password="
        return 1
    fi
    if timeout "$timeout" _queue_asset_winrm_python run_command "$host" "$user" "$password" "$cmd" >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: winrm:run_command failed for $host"
    return 1
}
