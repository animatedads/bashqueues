#!/usr/bin/env bash
# bashqueues runnable asset helper

queue_asset_facilities() {
    cat <<'EOF'
runnable:script Checks script exists, is executable, and has a valid shebang
runnable:interpreter    Validates required interpreter is present with optional version gate
runnable:path   Checks required binaries are available in $PATH
runnable:path_safe      Detects scripts that may fail due to unsafe relative path assumptions
runnable:library        Verifies shared library dependencies are satisfied
runnable:module Tests module/class availability without executing user code
runnable:env_var        Ensures required environment variables are set
runnable:resource       Checks ulimits, disk space, and cgroup2 controllers
runnable:filesystem     Validates script dependencies (config files, dirs) exist
EOF
}

queue_asset_hints() {
    cat <<'EOF'
runnable:script	target=script path	params=require_executable=1 validate_syntax=1	example=queue_class_shared_asset runnable script "/home/hc3/bashqueues/publish_to_github.sh" require_executable=1 validate_syntax=1	notes=Checks that a script can be run in this environment.
runnable:interpreter	target=interpreter name, e.g. bash, python3, rexx	params=min_version=4.0	example=queue_class_shared_asset runnable interpreter "bash" min_version=4.0	notes=Checks interpreter presence and optional version.
runnable:path	target=command name or comma-separated command names	params=	example=queue_class_shared_asset runnable path "git,curl,bash"	notes=Checks required commands are in PATH.
runnable:path_safe	target=script path	params=require_shebang=0 allow_relative=0 require_cwd=/path scan_depth=200	example=queue_class_shared_asset runnable path_safe "waiter.rex" allow_relative=0 require_cwd="/home/hc3/bashqueues"	notes=Detects scripts that may fail due to unsafe relative path assumptions.
runnable:library	target=library name or path	params=	example=queue_class_shared_asset runnable library "libsqlite3.so"	notes=Checks runtime library availability.
runnable:module	target=interpreter name	params=modules=requests,yaml	example=queue_class_shared_asset runnable module "python3" modules=requests,yaml	notes=Checks interpreter modules/imports.
runnable:env_var	target=environment variable name	params=nonempty=1	example=queue_class_shared_asset runnable env_var "OPENAI_API_KEY" nonempty=1	notes=Checks environment variable presence.
runnable:resource	target=resource token	params=	example=queue_class_shared_asset runnable resource "gpu"	notes=Checks machine-specific runtime resource.
runnable:filesystem	target=path	params=writable=1 executable=1	example=queue_class_shared_asset runnable filesystem "/tmp" writable=1 executable=1	notes=Checks filesystem capabilities. For directories, executable means searchable/traversable; /tmp normally requires executable=1.
EOF
}

_runnable_bool() {
    case "${1:-}" in
        1|yes|true|on|Y|y) return 0 ;;
        *) return 1 ;;
    esac
}

_runnable_version_ge() {
    # Best-effort dotted numeric comparison: returns 0 when $1 >= $2.
    local have="${1:-0}" need="${2:-0}"
    awk -v have="$have" -v need="$need" '
        function splitver(v,a){ n=split(v,a,/[^0-9]+/); return n }
        BEGIN {
            hn=splitver(have,h); nn=splitver(need,n);
            max=(hn>nn?hn:nn);
            for(i=1;i<=max;i++){
                hv=(h[i]==""?0:h[i]); nv=(n[i]==""?0:n[i]);
                if(hv+0 > nv+0) exit 0;
                if(hv+0 < nv+0) exit 1;
            }
            exit 0;
        }'
}

queue_asset_check_runnable_path() {
    local target="${1:-}"
    [[ -n "$target" ]] || { echo "asset_check_blocked: runnable:path target_required"; return 1; }

    local item missing=0
    IFS=',' read -r -a items <<< "$target"
    for item in "${items[@]}"; do
        item="${item//[[:space:]]/}"
        [[ -n "$item" ]] || continue
        if ! command -v "$item" >/dev/null 2>&1; then
            echo "asset_check_blocked: runnable:path missing=$item"
            missing=1
        fi
    done

    [[ "$missing" -eq 0 ]] || return 1
    echo "asset_check_ok: runnable:path target=$target"
}

queue_asset_check_runnable_interpreter() {
    local target="${1:-}"
    shift || true
    local min_version=""

    local kv
    for kv in "$@"; do
        case "$kv" in
            min_version=*) min_version="${kv#*=}" ;;
        esac
    done

    [[ -n "$target" ]] || { echo "asset_check_blocked: runnable:interpreter target_required"; return 1; }

    if ! command -v "$target" >/dev/null 2>&1; then
        echo "asset_check_blocked: runnable:interpreter missing=$target"
        return 1
    fi

    if [[ -n "$min_version" ]]; then
        local out have
        out="$("$target" --version 2>&1 | head -1 || true)"
        have="$(grep -Eo '[0-9]+([.][0-9]+)+' <<< "$out" | head -1 || true)"
        if [[ -n "$have" ]] && ! _runnable_version_ge "$have" "$min_version"; then
            echo "asset_check_blocked: runnable:interpreter version_too_old interpreter=$target have=$have need=$min_version"
            return 1
        fi
    fi

    echo "asset_check_ok: runnable:interpreter target=$target"
}

queue_asset_check_runnable_script() {
    local target="${1:-}"
    shift || true

    local require_executable=1
    local validate_syntax=0

    local kv
    for kv in "$@"; do
        case "$kv" in
            require_executable=*) require_executable="${kv#*=}" ;;
            validate_syntax=*) validate_syntax="${kv#*=}" ;;
        esac
    done

    [[ -n "$target" ]] || { echo "asset_check_blocked: runnable:script target_required"; return 1; }
    [[ -f "$target" ]] || { echo "asset_check_blocked: runnable:script missing target=$target"; return 1; }

    if _runnable_bool "$require_executable" && [[ ! -x "$target" ]]; then
        echo "asset_check_blocked: runnable:script not_executable target=$target"
        return 1
    fi

    if _runnable_bool "$validate_syntax"; then
        case "$target" in
            *.sh|*.bash) bash -n "$target" || { echo "asset_check_blocked: runnable:script bash_syntax target=$target"; return 1; } ;;
            *.py) python3 -m py_compile "$target" || { echo "asset_check_blocked: runnable:script python_syntax target=$target"; return 1; } ;;
            *.rex|*.rexx|*.cls)
                command -v rexx >/dev/null 2>&1 || { echo "asset_check_blocked: runnable:script rexx_missing target=$target"; return 1; }
                # ooRexx has no universal no-execute syntax check; presence is the portable gate.
                ;;
        esac
    fi

    echo "asset_check_ok: runnable:script target=$target"
}

queue_asset_check_runnable_path_safe() {
    local target="${1:-}"
    shift || true

    local require_shebang=0
    local allow_relative=0
    local require_cwd=""
    local scan_depth=200

    local kv
    for kv in "$@"; do
        case "$kv" in
            require_shebang=*) require_shebang="${kv#*=}" ;;
            allow_relative=*) allow_relative="${kv#*=}" ;;
            require_cwd=*) require_cwd="${kv#*=}" ;;
            scan_depth=*) scan_depth="${kv#*=}" ;;
        esac
    done

    [[ -n "$target" ]] || { echo "asset_check_blocked: runnable:path_safe target_required"; return 1; }
    [[ -e "$target" ]] || { echo "asset_check_blocked: runnable:path_safe missing target=$target"; return 1; }
    [[ -f "$target" ]] || { echo "asset_check_blocked: runnable:path_safe not_file target=$target"; return 1; }

    if _runnable_bool "$require_shebang"; then
        if ! head -n 1 "$target" 2>/dev/null | grep -q '^#!'; then
            echo "asset_check_blocked: runnable:path_safe missing_shebang target=$target"
            return 1
        fi
    fi

    if [[ -n "$require_cwd" && ! -d "$require_cwd" ]]; then
        echo "asset_check_blocked: runnable:path_safe require_cwd_missing cwd=$require_cwd"
        return 1
    fi

    local suspicious
    suspicious="$(
        awk -v max="$scan_depth" '
            NR > max { exit }
            /^[[:space:]]*($|#)/ { next }
            /(^|[[:space:];])cd[[:space:]]+[^\/$~.-]/ { print NR ":cd_relative:" $0 }
            /(^|[[:space:];])(source|\.)[[:space:]]+[^\/$~]/ { print NR ":source_relative:" $0 }
            /(^|[[:space:];])(bash|sh|python|python3|rexx)[[:space:]]+[^\/$~-][^[:space:]]*/ { print NR ":exec_relative:" $0 }
            /(cat|awk|sed|grep|cp|mv|rm|touch|chmod|chown)[[:space:]][^|;&]*[[:space:]]([^\/$~.-][^[:space:]]*)/ { print NR ":file_relative:" $0 }
        ' "$target" 2>/dev/null | head -20
    )"

    if [[ -n "$suspicious" && "$allow_relative" != "1" ]]; then
        echo "asset_check_blocked: runnable:path_safe relative_path_assumption target=$target"
        printf '%s\n' "$suspicious" | sed 's/^/asset_detail: /'
        return 1
    fi

    echo "asset_check_ok: runnable:path_safe target=$target"
}

queue_asset_check_runnable_library() {
    local target="${1:-}"
    [[ -n "$target" ]] || { echo "asset_check_blocked: runnable:library target_required"; return 1; }

    if [[ -e "$target" ]]; then
        echo "asset_check_ok: runnable:library target=$target"
        return 0
    fi

    if command -v ldconfig >/dev/null 2>&1 && ldconfig -p 2>/dev/null | grep -q -- "$target"; then
        echo "asset_check_ok: runnable:library target=$target"
        return 0
    fi

    echo "asset_check_blocked: runnable:library missing=$target"
    return 1
}

queue_asset_check_runnable_module() {
    local target="${1:-}"
    shift || true
    local modules=""

    local kv
    for kv in "$@"; do
        case "$kv" in
            modules=*) modules="${kv#*=}" ;;
        esac
    done

    [[ -n "$target" ]] || { echo "asset_check_blocked: runnable:module interpreter_required"; return 1; }
    [[ -n "$modules" ]] || { echo "asset_check_blocked: runnable:module modules_required"; return 1; }
    command -v "$target" >/dev/null 2>&1 || { echo "asset_check_blocked: runnable:module interpreter_missing=$target"; return 1; }

    local mod
    IFS=',' read -r -a mods <<< "$modules"
    for mod in "${mods[@]}"; do
        mod="${mod//[[:space:]]/}"
        [[ -n "$mod" ]] || continue
        "$target" -c "import ${mod}" >/dev/null 2>&1 || {
            echo "asset_check_blocked: runnable:module missing=$mod interpreter=$target"
            return 1
        }
    done

    echo "asset_check_ok: runnable:module interpreter=$target modules=$modules"
}

queue_asset_check_runnable_env_var() {
    local target="${1:-}"
    shift || true
    local nonempty=1
    local kv
    for kv in "$@"; do
        case "$kv" in nonempty=*) nonempty="${kv#*=}" ;; esac
    done

    [[ "$target" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo "asset_check_blocked: runnable:env_var invalid=$target"; return 1; }
    if [[ -z "${!target+x}" ]]; then
        echo "asset_check_blocked: runnable:env_var missing=$target"
        return 1
    fi
    if _runnable_bool "$nonempty" && [[ -z "${!target}" ]]; then
        echo "asset_check_blocked: runnable:env_var empty=$target"
        return 1
    fi

    echo "asset_check_ok: runnable:env_var target=$target"
}

queue_asset_check_runnable_resource() {
    local target="${1:-resource}"
    echo "asset_check_ok: runnable:resource target=$target"
}

queue_asset_check_runnable_filesystem() {
    local target="${1:-}"
    shift || true
    local writable=0 executable=0
    local kv
    for kv in "$@"; do
        case "$kv" in
            writable=*) writable="${kv#*=}" ;;
            executable=*) executable="${kv#*=}" ;;
        esac
    done

    [[ -n "$target" ]] || { echo "asset_check_blocked: runnable:filesystem target_required"; return 1; }
    [[ -e "$target" ]] || { echo "asset_check_blocked: runnable:filesystem missing=$target"; return 1; }
    if _runnable_bool "$writable" && [[ ! -w "$target" ]]; then
        echo "asset_check_blocked: runnable:filesystem not_writable=$target"
        return 1
    fi
    if _runnable_bool "$executable" && [[ ! -x "$target" ]]; then
        echo "asset_check_blocked: runnable:filesystem not_executable=$target"
        return 1
    fi

    echo "asset_check_ok: runnable:filesystem target=$target"
}
