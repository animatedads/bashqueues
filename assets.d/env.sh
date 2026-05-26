#!/usr/bin/env bash
# bashqueues asset plugin: env
# Execution environment profile gates.  This is intentionally separate from
# sandbox/seccomp: sandbox says what a job may do; env says which world it is in.

queue_asset_facilities() {
    cat <<'FACILITIES'
env:profile_valid	Blocks dispatch unless the named execution environment profile exists and is valid
env:profile_required	Blocks dispatch unless the class/job selected the expected execution environment
env:secret_scope	Blocks dispatch unless the profile exposes the expected secrets scope
env:endpoint_scope	Blocks dispatch unless the profile exposes the expected endpoint scope
env:chroot_available	Blocks dispatch unless a required chroot root exists for the profile/path
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
env:profile_valid	target=profile name or _	params=none	example=queue_class_shared_asset env profile_valid live	notes=Checks $QUEUEBASH_ROOT/envs.d/<profile>.env. Target _ uses CLASS_EXEC_ENV or EXEC_ENV.
env:profile_required	target=expected profile	params=none	example=queue_class_shared_asset env profile_required live	notes=Compares the expected profile with CLASS_EXEC_ENV/CLASS_DEFAULT_EXEC_ENV/EXEC_ENV.
env:secret_scope	target=expected scope	params=profile=NAME	example=queue_class_shared_asset env secret_scope live profile=live	notes=Ensures profile secret scope matches the class requirement.
env:endpoint_scope	target=expected scope	params=profile=NAME	example=queue_class_shared_asset env endpoint_scope live profile=live	notes=Ensures profile endpoint scope matches the class requirement.
env:chroot_available	target=profile name or path	params=profile=NAME required=0|1	example=queue_class_shared_asset env chroot_available live required=1	notes=Phase-1 validation only; actual runner chroot enforcement is a later release.
EOF_HINTS
}

queue_asset_param() {
    local key="$1" p
    shift || true
    for p in "$@"; do
        case "$p" in "$key="*) printf '%s\n' "${p#*=}"; return 0 ;; esac
    done
    return 1
}

_queue_asset_env_root() { printf '%s\n' "${QUEUEBASH_ROOT:-$HOME/.queuebash}"; }
_queue_asset_env_profile_from_context() { printf '%s\n' "${CLASS_EXEC_ENV:-${CLASS_DEFAULT_EXEC_ENV:-${EXEC_ENV:-}}}"; }
_queue_asset_env_valid_name() { [[ "${1:-}" =~ ^[A-Za-z0-9_.-]+$ ]]; }
_queue_asset_env_file() {
    local profile="$1"
    _queue_asset_env_valid_name "$profile" || return 2
    printf '%s/envs.d/%s.env\n' "$(_queue_asset_env_root)" "$profile"
}

_queue_asset_env_load_profile() {
    local profile="$1" file
    file="$(_queue_asset_env_file "$profile")" || { echo "asset_check_blocked: env:profile invalid_profile_name=$profile"; return 2; }
    [[ -f "$file" ]] || { echo "asset_check_blocked: env:profile profile_not_found profile=$profile file=$file"; return 1; }
    if ! bash -n "$file" >/dev/null 2>&1; then
        echo "asset_check_blocked: env:profile syntax_error profile=$profile file=$file"
        return 1
    fi
    EXEC_ENV_NAME="" EXEC_ENV_LABEL="" EXEC_ENV_CHROOT_MODE="" EXEC_ENV_CHROOT_ROOT=""
    EXEC_ENV_SECRET_SCOPE="" EXEC_ENV_ENDPOINT_SCOPE="" EXEC_ENV_DATA_SCOPE=""
    # shellcheck disable=SC1090
    source "$file" >/dev/null 2>&1 || { echo "asset_check_blocked: env:profile source_failed profile=$profile file=$file"; return 1; }
    [[ -n "${EXEC_ENV_NAME:-}" ]] || EXEC_ENV_NAME="$profile"
    if [[ "$EXEC_ENV_NAME" != "$profile" ]]; then
        echo "asset_check_blocked: env:profile name_mismatch requested=$profile declared=$EXEC_ENV_NAME"
        return 1
    fi
    return 0
}

queue_asset_check_env_profile_valid() {
    local profile="${1:-}"
    [[ "$profile" == "_" || -z "$profile" ]] && profile="$(_queue_asset_env_profile_from_context)"
    [[ -n "$profile" ]] || { echo "asset_check_blocked: env:profile_valid no_profile_selected"; return 1; }
    _queue_asset_env_load_profile "$profile" || return 1
    echo "asset_check_ok: env:profile_valid profile=$profile label=${EXEC_ENV_LABEL:-}"
}

queue_asset_check_env_profile_required() {
    local expected="${1:-}" selected
    selected="$(_queue_asset_env_profile_from_context)"
    [[ -n "$expected" ]] || { echo "asset_check_blocked: env:profile_required expected_required"; return 1; }
    [[ -n "$selected" ]] || { echo "asset_check_blocked: env:profile_required no_profile_selected expected=$expected"; return 1; }
    if [[ "$selected" != "$expected" ]]; then
        echo "asset_check_blocked: env:profile_required expected=$expected selected=$selected"
        return 1
    fi
    _queue_asset_env_load_profile "$selected" || return 1
    echo "asset_check_ok: env:profile_required profile=$selected"
}

queue_asset_check_env_secret_scope() {
    local expected="${1:-}" profile
    shift || true
    profile="$(queue_asset_param profile "$@" || true)"
    [[ -n "$profile" ]] || profile="$(_queue_asset_env_profile_from_context)"
    [[ -n "$expected" && -n "$profile" ]] || { echo "asset_check_blocked: env:secret_scope expected_or_profile_missing"; return 1; }
    _queue_asset_env_load_profile "$profile" || return 1
    if [[ "${EXEC_ENV_SECRET_SCOPE:-}" != "$expected" ]]; then
        echo "asset_check_blocked: env:secret_scope expected=$expected actual=${EXEC_ENV_SECRET_SCOPE:-} profile=$profile"
        return 1
    fi
    echo "asset_check_ok: env:secret_scope profile=$profile scope=$expected"
}

queue_asset_check_env_endpoint_scope() {
    local expected="${1:-}" profile
    shift || true
    profile="$(queue_asset_param profile "$@" || true)"
    [[ -n "$profile" ]] || profile="$(_queue_asset_env_profile_from_context)"
    [[ -n "$expected" && -n "$profile" ]] || { echo "asset_check_blocked: env:endpoint_scope expected_or_profile_missing"; return 1; }
    _queue_asset_env_load_profile "$profile" || return 1
    if [[ "${EXEC_ENV_ENDPOINT_SCOPE:-}" != "$expected" ]]; then
        echo "asset_check_blocked: env:endpoint_scope expected=$expected actual=${EXEC_ENV_ENDPOINT_SCOPE:-} profile=$profile"
        return 1
    fi
    echo "asset_check_ok: env:endpoint_scope profile=$profile scope=$expected"
}

queue_asset_check_env_chroot_available() {
    local target="${1:-}" profile required root
    shift || true
    required="$(queue_asset_param required "$@" || echo 0)"
    profile="$(queue_asset_param profile "$@" || true)"
    if [[ -n "$profile" || -z "$target" || "$target" == "_" || "$target" =~ ^[A-Za-z0-9_.-]+$ ]]; then
        [[ -n "$profile" ]] || profile="${target:-$(_queue_asset_env_profile_from_context)}"
        [[ "$profile" == "_" ]] && profile="$(_queue_asset_env_profile_from_context)"
        [[ -n "$profile" ]] || { echo "asset_check_blocked: env:chroot_available no_profile_selected"; return 1; }
        _queue_asset_env_load_profile "$profile" || return 1
        root="${EXEC_ENV_CHROOT_ROOT:-}"
        if [[ "${EXEC_ENV_CHROOT_MODE:-off}" == "off" && "$required" != "1" ]]; then
            echo "asset_check_ok: env:chroot_available profile=$profile mode=off"
            return 0
        fi
    else
        root="$target"
        profile="path"
    fi
    [[ -n "$root" ]] || { echo "asset_check_blocked: env:chroot_available chroot_root_missing profile=$profile"; return 1; }
    [[ -d "$root" ]] || { echo "asset_check_blocked: env:chroot_available chroot_root_missing path=$root profile=$profile"; return 1; }
    echo "asset_check_ok: env:chroot_available profile=$profile path=$root"
}
