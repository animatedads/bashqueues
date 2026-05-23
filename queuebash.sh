#!/usr/bin/env bash
# queuebash.sh - native Bash queue manager
# Source this from ~/.bashrc or ~/.bash_profile.
# priorities, hooks, exact-name grouping, bash completion, overdir/overfiles.

# Keep normal interactive guard if this file is used as a full .bashrc.
# Set QUEUEBASH_ALLOW_NONINTERACTIVE=1 before sourcing to use in scripts/tests.
if [[ -z "${QUEUEBASH_ALLOW_NONINTERACTIVE:-}" ]]; then
    case $- in
        *i*) ;;
        *) return 0 2>/dev/null || exit 0 ;;
    esac
fi

# Preserve a simple default prompt if caller has none.
: "${PS1:='\u@\h:\w> '}"

QUEUEBASH_VERSION="0.9.0"

# -------------------------------------------------------------------
# overdir / overfiles
# -------------------------------------------------------------------

_over_quote_cmd() {
    printf ' %q' "$@"
}

overdir() {
    local dryrun=0

    if [[ "$1" == "--help" || "$1" == "-h" || "$#" -eq 0 ]]; then
        cat <<'EOF'
Usage:
  overdir [--dryrun] <directory|dirspec...> <command... using {1}>

Runs the command once for each matching directory.

Placeholder:
  {1} = current directory path

Examples:
  overdir ~/Downloads ls -la "{1}"
  overdir --dryrun "~/Downloads/import/*" python forensic_helper.py --ingest "{1}" --yaml tblisi.yaml

Notes:
  Quote globs/filespecs if you want overdir to expand them internally.
  Quote "{1}" to preserve spaces in paths.
EOF
        return 0
    fi

    if [[ "$1" == "--dryrun" ]]; then
        dryrun=1
        shift
    fi

    if [[ "$#" -lt 2 ]]; then
        echo "Usage: overdir [--dryrun] <directory|dirspec...> <command... using {1}>"
        echo "Try: overdir --help"
        return 2
    fi

    local targets=()
    while [[ "$#" -gt 0 ]]; do
        local a="${1/#\~/$HOME}"

        if [[ -d "$a" ]]; then
            targets+=( "$a" )
            shift
            continue
        fi

        local matches=()
        local m
        while IFS= read -r m; do
            [[ -d "$m" ]] && matches+=( "$m" )
        done < <(compgen -G "$a")

        if [[ "${#matches[@]}" -gt 0 ]]; then
            targets+=( "${matches[@]}" )
            shift
            continue
        fi

        break
    done

    if [[ "${#targets[@]}" -eq 0 ]]; then
        echo "overdir: no directories matched" >&2
        return 1
    fi

    if [[ "$#" -eq 0 ]]; then
        echo "overdir: missing command" >&2
        return 2
    fi

    local cmd=( "$@" )
    local dir
    for dir in "${targets[@]}"; do
        echo "=== $dir ==="
        local args=()
        local x
        for x in "${cmd[@]}"; do
            args+=( "${x//\{1\}/$dir}" )
        done

        if [[ "$dryrun" -eq 1 ]]; then
            printf 'DRYRUN:'
            printf ' %q' "${args[@]}"
            printf '\n'
        else
            "${args[@]}"
        fi
    done
}

overfiles() {
    local dryrun=0

    if [[ "$1" == "--help" || "$1" == "-h" || "$#" -eq 0 ]]; then
        cat <<'EOF'
Usage:
  overfiles [--dryrun] <file|filespec|directory...> <command... using {1}>

Runs the command once for each matching file.

Placeholder:
  {1} = current file path

Examples:
  overfiles "../*.zip" unzip "{1}"
  overfiles --dryrun "../*.zip" unzip "{1}"
  overfiles "../*.zip" bash -c 'mkdir -p "${1%.zip}" && unzip -o "$1" -d "${1%.zip}"' _ "{1}"

Notes:
  Quote globs/filespecs if you want overfiles to expand them internally.
  Quote "{1}" to preserve spaces in paths.
EOF
        return 0
    fi

    if [[ "$1" == "--dryrun" ]]; then
        dryrun=1
        shift
    fi

    if [[ "$#" -lt 2 ]]; then
        echo "Usage: overfiles [--dryrun] <file|filespec|directory...> <command... using {1}>"
        echo "Try: overfiles --help"
        return 2
    fi

    local targets=()
    while [[ "$#" -gt 0 ]]; do
        local a="${1/#\~/$HOME}"

        if [[ -e "$a" ]]; then
            targets+=( "$a" )
            shift
            continue
        fi

        local matches=()
        local m
        while IFS= read -r m; do
            [[ -e "$m" ]] && matches+=( "$m" )
        done < <(compgen -G "$a")

        if [[ "${#matches[@]}" -gt 0 ]]; then
            targets+=( "${matches[@]}" )
            shift
            continue
        fi

        break
    done

    if [[ "${#targets[@]}" -eq 0 ]]; then
        echo "overfiles: no files/directories matched" >&2
        return 1
    fi

    if [[ "$#" -eq 0 ]]; then
        echo "overfiles: missing command" >&2
        return 2
    fi

    local cmd=( "$@" )
    local files=()
    local t

    for t in "${targets[@]}"; do
        if [[ -d "$t" ]]; then
            local f
            while IFS= read -r -d '' f; do
                files+=( "$f" )
            done < <(find "$t" -mindepth 1 -maxdepth 1 -type f -print0)
        elif [[ -f "$t" ]]; then
            files+=( "$t" )
        fi
    done

    if [[ "${#files[@]}" -eq 0 ]]; then
        echo "overfiles: no files found" >&2
        return 1
    fi

    local file
    for file in "${files[@]}"; do
        echo "=== $file ==="
        local args=()
        local x
        for x in "${cmd[@]}"; do
            args+=( "${x//\{1\}/$file}" )
        done

        if [[ "$dryrun" -eq 1 ]]; then
            printf 'DRYRUN:'
            printf ' %q' "${args[@]}"
            printf '\n'
        else
            "${args[@]}"
        fi
    done
}

# -------------------------------------------------------------------
# queue / queuemgr
# -------------------------------------------------------------------

_queue_root() {
    echo "${QUEUEBASH_ROOT:-$HOME/.queuebash}"
}

_queue_init() {
    local root="$(_queue_root)"
    local default_class="${QUEUEBASH_DEFAULT_CLASS:-DEFAULT}"
    local default_file="$root/classes/$default_class.env"

    mkdir -p "$root"/{pending,running,paused,done,failed,interrupted,cancelled,deleted,logs,workers,outputs,streams,helpers,classes,class.d,assets.d,claims/classes,claims/assets}

    if [[ ! -f "$default_file" ]]; then
        cat > "$default_file" <<'EOF'
# bashqueues default class
# Every job has a class. Jobs submitted without --class use this one.
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_SHARED_ASSETS=""
CLASS_EXCLUSIVE_ASSETS=""

# Optional dynamic preflight hooks:
# CLASS_PREFLIGHT_PLUGINS=""
# CLASS_PREFLIGHT_FUNC=""
# CLASS_PREFLIGHT_CMD=""
EOF
    fi

    if [[ ! -f "$root/assets.d/path.sh" ]]; then
        cat > "$root/assets.d/path.sh" <<'EOF'
# bashqueues standard path asset checks

queue_asset_facilities() {
    cat <<'FACILITIES'
path:exists	Checks that a filesystem path exists
path:mount	Checks that a path is currently a mountpoint
path:freespace	Checks that a directory has at least min_gb/min_mb/min_kb free
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

queue_asset_check_path_exists() {
    local token="$1"
    local target="$2"
    shift 2 || true

    if [[ -e "$target" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: path does not exist: $target"
    return 1
}

queue_asset_check_path_mount() {
    local token="$1"
    local target="$2"
    shift 2 || true

    if mountpoint -q -- "$target" 2>/dev/null; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: path is not a mountpoint: $target"
    return 1
}

queue_asset_check_path_freespace() {
    local token="$1"
    local target="$2"
    shift 2 || true

    local min_gb min_mb min_kb avail_kb need_kb

    min_gb="$(queue_asset_param min_gb "$@" || true)"
    min_mb="$(queue_asset_param min_mb "$@" || true)"
    min_kb="$(queue_asset_param min_kb "$@" || true)"

    if [[ ! -d "$target" ]]; then
        echo "asset_check_blocked: freespace path is not a directory: $target"
        return 1
    fi

    if [[ -n "$min_gb" ]]; then
        need_kb=$(( min_gb * 1024 * 1024 ))
    elif [[ -n "$min_mb" ]]; then
        need_kb=$(( min_mb * 1024 ))
    elif [[ -n "$min_kb" ]]; then
        need_kb="$min_kb"
    else
        echo "asset_check_blocked: path:freespace requires min_gb=, min_mb=, or min_kb=: $token"
        return 1
    fi

    avail_kb="$(df -Pk -- "$target" 2>/dev/null | awk 'NR==2 {print $4}')"
    if [[ -z "$avail_kb" || ! "$avail_kb" =~ ^[0-9]+$ ]]; then
        echo "asset_check_blocked: unable to read free space for: $target"
        return 1
    fi

    if (( avail_kb < need_kb )); then
        echo "asset_check_blocked: insufficient freespace target=$target available_kb=$avail_kb required_kb=$need_kb"
        return 1
    fi

    echo "asset_check_ok: path:freespace target=$target available_kb=$avail_kb required_kb=$need_kb"
    return 0
}
EOF
    fi

}

_queue_now() {
    date +"%Y%m%d_%H%M%S"
}

_queue_id() {
    # Include nanoseconds and PID to avoid collisions during rapid batch submission.
    printf "%s_%s_%06d_%d" "$(_queue_now)" "$(date +%N)" "$RANDOM" "$$"
}

_queue_job_name() {
    local f="$1"
    grep '^JOB_NAME=' "$f" 2>/dev/null | cut -d= -f2- | xargs printf '%s' 2>/dev/null
}

_queue_job_pri() {
    local f="$1"
    local pri
    pri="$(grep '^PRIORITY=' "$f" 2>/dev/null | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
    pri="${pri:-10}"
    pri="${pri//[^0-9-]/}"
    [[ -z "$pri" ]] && pri=10
    printf '%s\n' "$pri"
}

_queue_job_id_and_names_for_completion() {
    local root="$(_queue_root)"
    local state f id name
    for state in pending running paused done failed interrupted cancelled deleted; do
        for f in "$root/$state"/*.job; do
            [[ -e "$f" ]] || continue
            id="$(basename "$f" .job)"
            name="$(_queue_job_name "$f")"
            printf '%s\n' "$id"
            [[ -n "$name" ]] && printf '%s\n' "$name"
        done
    done | sort -u
}

_queue_find_jobs() {
    # Exact QID wins; exact job name next; QID prefix last.
    # No job-name prefix matching.
    local needle="$1"
    local root="$(_queue_root)"
    local state f id name
    local exact_qid=()
    local exact_name=()
    local qid_prefix=()

    [[ -z "$needle" ]] && return 1

    for state in pending running paused done failed interrupted cancelled deleted; do
        for f in "$root/$state"/*.job; do
            [[ -e "$f" ]] || continue
            id="$(basename "$f" .job)"
            name="$(_queue_job_name "$f")"

            if [[ "$id" == "$needle" ]]; then
                exact_qid+=( "$f" )
            elif [[ "$name" == "$needle" ]]; then
                exact_name+=( "$f" )
            elif [[ "$id" == "$needle"* ]]; then
                qid_prefix+=( "$f" )
            fi
        done
    done

    if [[ "${#exact_qid[@]}" -gt 0 ]]; then
        printf '%s\n' "${exact_qid[@]}"
    elif [[ "${#exact_name[@]}" -gt 0 ]]; then
        printf '%s\n' "${exact_name[@]}"
    elif [[ "${#qid_prefix[@]}" -gt 0 ]]; then
        printf '%s\n' "${qid_prefix[@]}"
    else
        return 1
    fi
}

_queue_print_matches() {
    local f id state name
    for f in "$@"; do
        [[ -e "$f" ]] || continue
        id="$(basename "$f" .job)"
        state="$(basename "$(dirname "$f")")"
        name="$(_queue_job_name "$f")"
        printf "  %-24s %-10s %s\n" "$id" "$state" "$name" >&2
    done
}

_queue_exact_name_count() {
    local target="$1"
    shift
    local f name count=0
    for f in "$@"; do
        name="$(_queue_job_name "$f")"
        [[ "$name" == "$target" ]] && count=$((count + 1))
    done
    printf '%s\n' "$count"
}

_queue_job_array_summary() {
    local file="$1"
    local varname="$2"

    [[ -f "$file" ]] || return 0

    (
        source "$file" 2>/dev/null || exit 0
        local -n arr="$varname" 2>/dev/null || exit 0
        local out=()
        local item

        for item in "${arr[@]}"; do
            [[ -n "$item" ]] && out+=( "$item" )
        done

        if [[ "${#out[@]}" -gt 0 ]]; then
            printf "%q" "${out[0]}"
            local i
            for ((i=1; i<${#out[@]}; i++)); do
                printf " %q" "${out[$i]}"
            done
        fi
    )
}

_queue_job_has_array() {
    local file="$1"
    local varname="$2"

    [[ -f "$file" ]] || return 1

    (
        source "$file" 2>/dev/null || exit 1
        local -n arr="$varname" 2>/dev/null || exit 1
        local item

        for item in "${arr[@]}"; do
            [[ -n "$item" ]] && exit 0
        done

        exit 1
    )
}

_queue_set_job_array() {
    local file="$1"
    local varname="$2"
    shift 2

    local tmp
    tmp="$(mktemp)"

    if grep -q "^${varname}=" "$file"; then
        grep -v "^${varname}=" "$file" > "$tmp"
    else
        cat "$file" > "$tmp"
    fi

    {
        printf '%s=(' "$varname"
        printf ' %q' "$@"
        printf ' )\n'
    } >> "$tmp"

    mv "$tmp" "$file"
}

_queue_dep_token_done() {
    local token="$1"
    local root="$(_queue_root)"
    local f name id

    [[ -z "$token" ]] && return 1

    # Direct QID match.
    if [[ -f "$root/done/$token.job" ]]; then
        return 0
    fi

    # Exact job-name match in done/.
    for f in "$root/done"/*.job; do
        [[ -e "$f" ]] || continue
        name="$(_queue_job_name "$f")"
        [[ "$name" == "$token" ]] && return 0
    done

    return 1
}

_queue_dep_token_failed_or_cancelled() {
    local token="$1"
    local root="$(_queue_root)"
    local state f name

    for state in failed interrupted cancelled deleted; do
        [[ -f "$root/$state/$token.job" ]] && return 0
        for f in "$root/$state"/*.job; do
            [[ -e "$f" ]] || continue
            name="$(_queue_job_name "$f")"
            [[ "$name" == "$token" ]] && return 0
        done
    done

    return 1
}

_queue_job_dependency_tokens() {
    local f="$1"
    local value=""

    # Preferred path: source the job file, because DEPENDS_AFTER_SUCCESS is now
    # written as one shell-quoted string assignment.
    value="$(
        source "$f" 2>/dev/null
        printf '%s' "${DEPENDS_AFTER_SUCCESS:-}"
    )"

    if [[ -n "$value" ]]; then
        printf '%s\n' "$value"
        return 0
    fi

    # Compatibility fallback for early 0.6.0 job files that may contain an
    # unsafe unquoted line like: DEPENDS_AFTER_SUCCESS=foo bar
    grep '^DEPENDS_AFTER_SUCCESS=' "$f" 2>/dev/null | tail -1 | sed 's/^DEPENDS_AFTER_SUCCESS=//'
}

_queue_job_dependencies_satisfied() {
    local f="$1"
    local deps dep
    deps="$(_queue_job_dependency_tokens "$f" || true)"
    [[ -z "$deps" ]] && return 0

    for dep in $deps; do
        _queue_dep_token_done "$dep" || return 1
    done

    return 0
}

_queue_job_dependencies_status() {
    local f="$1"
    local deps dep
    deps="$(_queue_job_dependency_tokens "$f" || true)"
    [[ -z "$deps" ]] && { echo "none"; return 0; }

    for dep in $deps; do
        if _queue_dep_token_done "$dep"; then
            echo "$dep:done"
        elif _queue_dep_token_failed_or_cancelled "$dep"; then
            echo "$dep:blocked"
        else
            echo "$dep:waiting"
        fi
    done
}

_queue_job_dependencies_blocked() {
    local f="$1"
    local deps dep
    deps="$(_queue_job_dependency_tokens "$f" || true)"
    [[ -z "$deps" ]] && return 1

    for dep in $deps; do
        _queue_dep_token_done "$dep" && continue
        _queue_dep_token_failed_or_cancelled "$dep" && return 0
    done

    return 1
}

_queue_now_epoch() {
    date +%s
}

_queue_parse_delay_seconds() {
    local spec="$1"
    local n unit total=0 rest

    [[ -z "$spec" ]] && return 1

    if [[ "$spec" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$spec"
        return 0
    fi

    rest="$spec"
    while [[ -n "$rest" ]]; do
        if [[ "$rest" =~ ^([0-9]+)([smhdw])(.*)$ ]]; then
            n="${BASH_REMATCH[1]}"
            unit="${BASH_REMATCH[2]}"
            rest="${BASH_REMATCH[3]}"
            case "$unit" in
                s) total=$((total + n)) ;;
                m) total=$((total + n * 60)) ;;
                h) total=$((total + n * 3600)) ;;
                d) total=$((total + n * 86400)) ;;
                w) total=$((total + n * 604800)) ;;
            esac
        else
            return 1
        fi
    done

    printf '%s\n' "$total"
}

_queue_parse_at_epoch() {
    local spec="$1"
    local epoch today candidate

    [[ -z "$spec" ]] && return 1

    if [[ "$spec" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$spec"
        return 0
    fi

    if [[ "$spec" =~ ^[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?$ ]]; then
        today="$(date +%Y-%m-%d)"
        candidate="$(date -d "$today $spec" +%s 2>/dev/null)" || return 1
        if (( candidate <= $(_queue_now_epoch) )); then
            candidate="$(date -d "tomorrow $spec" +%s 2>/dev/null)" || return 1
        fi
        printf '%s\n' "$candidate"
        return 0
    fi

    epoch="$(date -d "$spec" +%s 2>/dev/null)" || return 1
    printf '%s\n' "$epoch"
}

_queue_job_not_before_epoch() {
    local f="$1"
    local nb rb
    nb="$(grep '^NOT_BEFORE_EPOCH=' "$f" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
    rb="$(grep '^RETRY_NOT_BEFORE_EPOCH=' "$f" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
    nb="${nb:-0}"
    rb="${rb:-0}"
    [[ "$nb" =~ ^[0-9]+$ ]] || nb=0
    [[ "$rb" =~ ^[0-9]+$ ]] || rb=0
    if (( rb > nb )); then
        printf '%s\n' "$rb"
    else
        printf '%s\n' "$nb"
    fi
}

_queue_job_schedule_due() {
    local f="$1"
    local due
    due="$(_queue_job_not_before_epoch "$f")"
    (( due <= $(_queue_now_epoch) ))
}

_queue_job_schedule_status() {
    local f="$1"
    local due now remain when
    due="$(_queue_job_not_before_epoch "$f")"
    now="$(_queue_now_epoch)"
    when="$(date -d "@$due" -Is 2>/dev/null || echo "$due")"
    if (( due <= now )); then
        echo "due"
    else
        remain=$((due - now))
        echo "waiting ${remain}s until $when"
    fi
}

# -------------------------------------------------------------------
# Queue classes and cooperative resource claims
# -------------------------------------------------------------------

_queue_class_name_for_job() {
    local f="$1"
    local class
    class="$(grep '^JOB_CLASS=' "$f" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
    printf '%s\n' "${class:-${QUEUEBASH_DEFAULT_CLASS:-DEFAULT}}"
}

_queue_class_safe_token() {
    local x="$1"
    x="${x//[^A-Za-z0-9_.:-]/_}"
    printf '%s\n' "$x"
}

_queue_class_file() {
    local class="$1"
    local root="$(_queue_root)"
    if [[ -f "$class" ]]; then
        printf '%s\n' "$class"
    else
        printf '%s/classes/%s.env\n' "$root" "$class"
    fi
}


_queue_class_plugin_path() {
    local name="$1"
    local root="$(_queue_root)"
    if [[ -f "$name" ]]; then
        printf '%s\n' "$name"
    else
        printf '%s/class.d/%s\n' "$root" "$name"
    fi
}


_queue_asset_check_function_name() {
    local family="$1"
    local check="$2"
    family="${family//[^A-Za-z0-9_]/_}"
    check="${check//[^A-Za-z0-9_]/_}"
    printf 'queue_asset_check_%s_%s\n' "$family" "$check"
}

_queue_asset_helper_path() {
    local family="$1"
    local root="$(_queue_root)"
    if [[ -f "$family" ]]; then
        printf '%s\n' "$family"
    else
        printf '%s/assets.d/%s.sh\n' "$root" "$family"
    fi
}

_queue_asset_facility_is_published() {
    local family="$1"
    local check="$2"
    local facility="${family}:${check}"

    if declare -F queue_asset_facilities >/dev/null 2>&1; then
        queue_asset_facilities | awk '{print $1}' | grep -Fxq "$facility"
        return "$?"
    fi

    return 1
}

_queue_asset_scan_facilities() {
    local root="$(_queue_root)"
    local plugin
    shopt -s nullglob
    for plugin in "$root/assets.d"/*.sh; do
        [[ -f "$plugin" ]] || continue
        (
            source "$plugin" >/dev/null 2>&1 || exit 0
            if declare -F queue_asset_facilities >/dev/null 2>&1; then
                queue_asset_facilities
            fi
        )
    done
    shopt -u nullglob
}

_queue_asset_implied_preflight_one() {
    local token="$1"
    local family check target helper func
    local -a parts params

    [[ "$token" == *:*:* ]] || return 0

    IFS=':' read -r -a parts <<< "$token"
    family="${parts[0]:-}"
    check="${parts[1]:-}"
    target="${parts[2]:-}"

    [[ -n "$family" && -n "$check" && -n "$target" ]] || return 0

    helper="$(_queue_asset_helper_path "$family")"
    func="$(_queue_asset_check_function_name "$family" "$check")"

    # No helper means claim-only token.
    [[ -f "$helper" ]] || return 0

    (
        source "$helper" || exit 40

        # Plugin must publish before queue manager invokes.
        _queue_asset_facility_is_published "$family" "$check" || exit 41

        declare -F "$func" >/dev/null 2>&1 || exit 42

        params=()
        if ((${#parts[@]} > 3)); then
            params=("${parts[@]:3}")
        fi

        "$func" "$token" "$target" "${params[@]}"
    )
}

_queue_asset_implied_preflight_for_class() {
    local asset rc

    for asset in $CLASS_EXCLUSIVE_ASSETS $CLASS_SHARED_ASSETS; do
        [[ -z "$asset" ]] && continue
        _queue_asset_implied_preflight_one "$asset"
        rc="$?"
        case "$rc" in
            0) ;;
            41)
                echo "asset_preflight_blocked: unpublished_facility asset=$asset"
                return "$rc"
                ;;
            42)
                echo "asset_preflight_blocked: missing_check_function asset=$asset"
                return "$rc"
                ;;
            *)
                echo "asset_preflight_blocked: asset=$asset rc=$rc"
                return "$rc"
                ;;
        esac
    done

    return 0
}

_queue_class_dynamic_preflight() {
    local f="$1"
    local cmd func plugin plugin_path rc

    for plugin in ${CLASS_PREFLIGHT_PLUGINS:-}; do
        plugin_path="$(_queue_class_plugin_path "$plugin")"
        if [[ ! -f "$plugin_path" ]]; then
            echo "class_preflight_blocked: plugin_not_found plugin=$plugin path=$plugin_path"
            return 41
        fi
        source "$plugin_path"
    done

    for func in ${CLASS_PREFLIGHT_FUNC:-} ${CLASS_PREFLIGHT_FUNCS:-}; do
        [[ -z "$func" ]] && continue
        if ! declare -F "$func" >/dev/null 2>&1; then
            echo "class_preflight_blocked: func_not_found func=$func"
            return 42
        fi
        "$func"
        rc="$?"
        if [[ "$rc" -ne 0 ]]; then
            echo "class_preflight_blocked: func_failed func=$func rc=$rc"
            return "$rc"
        fi
    done

    for cmd in ${CLASS_PREFLIGHT_CMD:-} ${CLASS_PREFLIGHT_CMDS:-}; do
        [[ -z "$cmd" ]] && continue
        if [[ "$cmd" == */* ]]; then
            [[ -x "$cmd" ]] || { echo "class_preflight_blocked: cmd_not_executable cmd=$cmd"; return 43; }
            "$cmd"
        else
            command -v "$cmd" >/dev/null 2>&1 || { echo "class_preflight_blocked: cmd_not_found cmd=$cmd"; return 44; }
            "$cmd"
        fi
        rc="$?"
        if [[ "$rc" -ne 0 ]]; then
            echo "class_preflight_blocked: cmd_failed cmd=$cmd rc=$rc"
            return "$rc"
        fi
    done

    return 0
}

_queue_claim_lock_acquire() {
    local root="$(_queue_root)" lock i
    lock="$root/claims/.lock"
    mkdir -p "$root/claims"
    for i in $(seq 1 100); do
        if mkdir "$lock" 2>/dev/null; then
            printf '%s\n' "$$" > "$lock/pid" 2>/dev/null || true
            date -Is > "$lock/at" 2>/dev/null || true
            return 0
        fi
        sleep 0.02
    done
    return 1
}

_queue_claim_lock_release() {
    rm -rf "$(_queue_root)/claims/.lock" 2>/dev/null || true
}

_queue_class_claim_count() {
    local class="$1" root safe
    root="$(_queue_root)"
    safe="$(_queue_class_safe_token "$class")"
    find "$root/claims/classes" -maxdepth 1 -type d -name "$safe.*.claim" 2>/dev/null | wc -l | tr -d ' '
}

_queue_asset_has_any_claim() {
    local asset="$1" root safe
    root="$(_queue_root)"
    safe="$(_queue_class_safe_token "$asset")"
    find "$root/claims/assets" -maxdepth 1 -type d -name "$safe.*.claim" 2>/dev/null | grep -q .
}

_queue_asset_has_exclusive_claim() {
    local asset="$1" root safe
    root="$(_queue_root)"
    safe="$(_queue_class_safe_token "$asset")"
    find "$root/claims/assets" -maxdepth 1 -type d -name "$safe.exclusive.*.claim" 2>/dev/null | grep -q .
}

_queue_class_load_for_job() {
    local f="$1" class file root default_file
    root="$(_queue_root)"
    class="$(_queue_class_name_for_job "$f")"

    QUEUE_CLASS_NAME="${class:-${QUEUEBASH_DEFAULT_CLASS:-DEFAULT}}"
    QUEUE_CLASS_FILE="$(_queue_class_file "$QUEUE_CLASS_NAME")"

    CLASS_ALLOW_PARALLEL=1
    CLASS_EXCLUSIVE=0
    CLASS_MAX_CONCURRENT=0
    CLASS_SHARED_ASSETS=""
    CLASS_EXCLUSIVE_ASSETS=""
    CLASS_ASSETS=""
    CLASS_PREFLIGHT_FUNC=""
    CLASS_PREFLIGHT_FUNCS=""
    CLASS_PREFLIGHT_CMD=""
    CLASS_PREFLIGHT_CMDS=""
    CLASS_PREFLIGHT_PLUGINS=""

    if [[ ! -f "$QUEUE_CLASS_FILE" && "$QUEUE_CLASS_NAME" == "${QUEUEBASH_DEFAULT_CLASS:-DEFAULT}" ]]; then
        default_file="$root/classes/${QUEUEBASH_DEFAULT_CLASS:-DEFAULT}.env"
        mkdir -p "$root/classes" "$root/class.d"
        cat > "$default_file" <<'EOF'
# bashqueues default class
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_SHARED_ASSETS=""
CLASS_EXCLUSIVE_ASSETS=""
EOF
    fi

    if [[ -f "$QUEUE_CLASS_FILE" ]]; then
        source "$QUEUE_CLASS_FILE"
    else
        echo "queue class: class file not found: $QUEUE_CLASS_FILE" >&2
        return 2
    fi

    CLASS_SHARED_ASSETS="${CLASS_SHARED_ASSETS:-${CLASS_ASSETS:-}}"
    CLASS_ALLOW_PARALLEL="${CLASS_ALLOW_PARALLEL:-1}"
    CLASS_EXCLUSIVE="${CLASS_EXCLUSIVE:-0}"
    CLASS_MAX_CONCURRENT="${CLASS_MAX_CONCURRENT:-0}"
    CLASS_EXCLUSIVE_ASSETS="${CLASS_EXCLUSIVE_ASSETS:-}"
    return 0
}

_queue_class_available() {
    local f="$1"
    local class count max asset rc id name

    class="$(_queue_class_name_for_job "$f")"
    id="$(basename "$f" .job)"
    name="$(_queue_job_name "$f" 2>/dev/null || true)"

    (
        _queue_class_load_for_job "$f" >/dev/null 2>&1 || exit 1
        count="$(_queue_class_claim_count "$QUEUE_CLASS_NAME")"
        max="${CLASS_MAX_CONCURRENT:-0}"
        [[ "$max" =~ ^[0-9]+$ ]] || max=0

        if [[ "${CLASS_EXCLUSIVE:-0}" == "1" || "${CLASS_ALLOW_PARALLEL:-1}" == "0" ]]; then
            (( count == 0 )) || exit 10
        fi
        if (( max > 0 && count >= max )); then
            exit 11
        fi

        for asset in $CLASS_EXCLUSIVE_ASSETS; do
            _queue_asset_has_any_claim "$asset" && exit 12
        done
        for asset in $CLASS_SHARED_ASSETS; do
            _queue_asset_has_exclusive_claim "$asset" && exit 13
        done

        _queue_asset_implied_preflight_for_class || exit 23
        _queue_class_dynamic_preflight "$f" || exit 24
        exit 0
    )
    rc="$?"
    if [[ "$rc" -ne 0 ]]; then
        case "$rc" in
            23) _queue_log_event "resource_blocked" "$id" "$name" "pending" "class=$class reason=asset_preflight" ;;
            24) _queue_log_event "resource_blocked" "$id" "$name" "pending" "class=$class reason=preflight" ;;
            10|11|12|13) _queue_log_event "class_blocked" "$id" "$name" "pending" "class=$class rc=$rc" ;;
            *) _queue_log_event "class_blocked" "$id" "$name" "pending" "class=$class rc=$rc" ;;
        esac
        return 1
    fi
    return 0
}

_queue_class_claim_job() {
    local f="$1" id="$2" root class rc
    root="$(_queue_root)"
    class="$(_queue_class_name_for_job "$f")"

    _queue_claim_lock_acquire || return 1
    (
        local count max asset safe asafe claim
        _queue_class_load_for_job "$f" >/dev/null || exit 10

        count="$(_queue_class_claim_count "$QUEUE_CLASS_NAME")"
        max="${CLASS_MAX_CONCURRENT:-0}"
        [[ "$max" =~ ^[0-9]+$ ]] || max=0

        if [[ "${CLASS_EXCLUSIVE:-0}" == "1" || "${CLASS_ALLOW_PARALLEL:-1}" == "0" ]]; then
            (( count == 0 )) || exit 20
        fi
        if (( max > 0 && count >= max )); then
            exit 21
        fi

        for asset in $CLASS_EXCLUSIVE_ASSETS; do
            _queue_asset_has_any_claim "$asset" && exit 22
        done
        for asset in $CLASS_SHARED_ASSETS; do
            _queue_asset_has_exclusive_claim "$asset" && exit 23
        done

        safe="$(_queue_class_safe_token "$QUEUE_CLASS_NAME")"
        claim="$root/claims/classes/$safe.$id.claim"
        mkdir -p "$claim"
        printf '%s\n' "$id" > "$claim/job_id"
        printf '%s\n' "$QUEUE_CLASS_NAME" > "$claim/class"
        printf '%s\n' "$QUEUE_CLASS_FILE" > "$claim/class_file"
        date -Is > "$claim/claimed_at"

        for asset in $CLASS_EXCLUSIVE_ASSETS; do
            asafe="$(_queue_class_safe_token "$asset")"
            claim="$root/claims/assets/$asafe.exclusive.$id.claim"
            mkdir -p "$claim"
            printf '%s\n' "$id" > "$claim/job_id"
            printf '%s\n' "$asset" > "$claim/asset"
            printf '%s\n' "exclusive" > "$claim/mode"
            date -Is > "$claim/claimed_at"
        done
        for asset in $CLASS_SHARED_ASSETS; do
            asafe="$(_queue_class_safe_token "$asset")"
            claim="$root/claims/assets/$asafe.shared.$id.claim"
            mkdir -p "$claim"
            printf '%s\n' "$id" > "$claim/job_id"
            printf '%s\n' "$asset" > "$claim/asset"
            printf '%s\n' "shared" > "$claim/mode"
            date -Is > "$claim/claimed_at"
        done
    )
    rc="$?"
    _queue_claim_lock_release

    if [[ "$rc" -eq 0 ]]; then
        {
            printf 'JOB_CLASS_CLAIMED=%q\n' "$class"
            printf 'JOB_CLASS_CLAIMED_AT=%q\n' "$(date -Is)"
        } >> "$f" 2>/dev/null || true
        _queue_log_event "class_claimed" "$id" "$(_queue_job_name "$f")" "running" "class=$class"
        return 0
    fi
    return 1
}

_queue_class_release_claims() {
    local id="$1" root
    root="$(_queue_root)"
    [[ -z "$id" ]] && return 0
    rm -rf "$root/claims/classes/"*".$id.claim" "$root/claims/assets/"*".$id.claim" 2>/dev/null || true
}

_queue_cleanup_stale_claims() {
    local root="$(_queue_root)" claim id
    for claim in "$root/claims/classes"/*.claim "$root/claims/assets"/*.claim; do
        [[ -d "$claim" ]] || continue
        id="$(cat "$claim/job_id" 2>/dev/null || true)"
        if [[ -z "$id" || ! -f "$root/running/$id.job" ]]; then
            rm -rf "$claim" 2>/dev/null || true
            echo "FIX removed stale class/resource claim: $claim"
        fi
    done
}


_queue_next_job() {
    local root="$(_queue_root)"
    local best=""
    local best_pri="-999999"
    local best_id=""
    local f id pri

    for f in "$root/pending"/*.job; do
        [[ -e "$f" ]] || continue

        _queue_job_retry_due "$f" || continue
        _queue_job_schedule_due "$f" || continue
        _queue_job_dependencies_satisfied "$f" || continue
        _queue_class_available "$f" || continue

        id="$(basename "$f" .job)"
        pri="$(_queue_job_pri "$f")"

        if (( pri > best_pri )); then
            best="$f"
            best_pri="$pri"
            best_id="$id"
        elif (( pri == best_pri )); then
            if [[ -z "$best_id" || "$id" < "$best_id" ]]; then
                best="$f"
                best_id="$id"
            fi
        fi
    done

    [[ -n "$best" ]] && printf '%s\n' "$best"
}

_queue_extract_dryrun() {
    # Usage:
    #   local dryrun=0
    #   _queue_extract_dryrun "$@"  # prints cleaned args, returns dryrun via global QUEUE_DRYRUN
    # This is intentionally simple: callers use it through explicit loops below.
    :
}

_queue_dryrun_print() {
    printf 'DRYRUN:'
    printf ' %q' "$@"
    printf '\n'
}

_queue_clone_job_to_pending() {
    local src_job="$1"
    local new_id="$2"
    local note="$3"
    local root="$(_queue_root)"
    local dest="$root/pending/$new_id.job"

    (
        source "$src_job" 2>/dev/null || exit 1

        {
            printf 'JOB_ID=%q\n' "$new_id"
            printf 'JOB_NAME=%q\n' "$JOB_NAME"
            printf 'PRIORITY=%q\n' "${PRIORITY:-10}"
            printf 'RETRIES_MAX=%q\n' "${RETRIES_MAX:-0}"
            printf 'RETRIES_DONE=%q\n' "${RETRIES_DONE:-0}"
            printf 'RETRY_BACKOFF=%q\n' "${RETRY_BACKOFF:-0}"
            printf 'RETRY_NOT_BEFORE_EPOCH=%q\n' "0"
            printf 'CPU_LIMIT=%q\n' "${CPU_LIMIT:-}"
            printf 'MEM_LIMIT=%q\n' "${MEM_LIMIT:-}"
            printf 'MAX_LOG_SIZE_BYTES=%q\n' "${MAX_LOG_SIZE_BYTES:-${QUEUEBASH_MAX_LOG_SIZE_BYTES:-52428800}}"
            printf 'ALLOW_LARGE_LOG=%q\n' "${ALLOW_LARGE_LOG:-0}"
            printf 'RUNNER=%q\n' "${RUNNER:-${QUEUEBASH_RUNNER:-auto}}"
            [[ -n "${JOB_CLASS:-}" ]] && printf 'JOB_CLASS=%q\n' "$JOB_CLASS"
            [[ -n "${DEPENDS_AFTER_SUCCESS:-}" ]] && printf 'DEPENDS_AFTER_SUCCESS=%q\n' "$DEPENDS_AFTER_SUCCESS"
            [[ -n "${INHERIT_ENV_FROM:-}" ]] && printf 'INHERIT_ENV_FROM=%q\n' "$INHERIT_ENV_FROM"
            printf 'SUBMITTED_AT=%q\n' "$(date -Is)"
            printf 'PWD_AT_SUBMIT=%q\n' "$PWD_AT_SUBMIT"
            printf 'RESUBMITTED_FROM=%q\n' "$JOB_ID"
            printf 'RESUBMITTED_AT=%q\n' "$(date -Is)"
            [[ -n "$note" ]] && printf 'RESUBMIT_NOTE=%q\n' "$note"

            printf 'COMMAND=('
            printf ' %q' "${COMMAND[@]}"
            printf ' )\n'

            printf 'ON_SUCCESS=('
            printf ' %q' "${ON_SUCCESS[@]}"
            printf ' )\n'

            printf 'ON_FAILURE=('
            printf ' %q' "${ON_FAILURE[@]}"
            printf ' )\n'

            printf 'ON_RETRY_FAILURE=('
            printf ' %q' "${ON_RETRY_FAILURE[@]}"
            printf ' )\n'
        } > "$dest"
    )
}

_queue_child_pids_recursive() {
    local parent="$1"
    local child

    [[ -z "$parent" ]] && return 0

    for child in $(pgrep -P "$parent" 2>/dev/null); do
        printf '%s\n' "$child"
        _queue_child_pids_recursive "$child"
    done
}

_queue_pid_report_for_job() {
    local job="$1"

    [[ -f "$job" ]] || return 1

    (
        source "$job" 2>/dev/null || exit 1

        echo "Job: ${JOB_ID:-$(basename "$job" .job)}"
        echo "Name: ${JOB_NAME:-}"
        echo "Recorded RUN_PID: ${RUN_PID:-}"
        echo "Recorded RUN_PGID: ${RUN_PGID:-}"
        echo "Run started: ${RUN_STARTED_AT:-}"

        if [[ -n "${RUN_PID:-}" ]]; then
            if kill -0 "$RUN_PID" 2>/dev/null; then
                echo
                echo "Live process tree:"
                ps -o pid,ppid,pgid,stat,etime,pcpu,pmem,comm,args -p "$RUN_PID" 2>/dev/null || true

                local kids
                kids="$(_queue_child_pids_recursive "$RUN_PID" | xargs echo)"
                if [[ -n "$kids" ]]; then
                    echo
                    echo "Live child processes:"
                    # shellcheck disable=SC2086
                    ps -o pid,ppid,pgid,stat,etime,pcpu,pmem,comm,args -p $kids 2>/dev/null || true
                else
                    echo
                    echo "Live child processes: none found"
                fi
            else
                echo
                echo "RUN_PID is not currently live."
            fi
        fi
    )
}

_queue_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

_queue_log_event() {
    local event="$1"
    local job_id="${2:-}"
    local job_name="${3:-}"
    local state="${4:-}"
    local extra="${5:-}"
    local root="$(_queue_root)"
    local ts

    mkdir -p "$root"
    ts="$(date -Is)"

    {
        printf '{"ts":"%s","event":"%s","job_id":"%s","job_name":"%s","state":"%s"' \
            "$(_queue_json_escape "$ts")" \
            "$(_queue_json_escape "$event")" \
            "$(_queue_json_escape "$job_id")" \
            "$(_queue_json_escape "$job_name")" \
            "$(_queue_json_escape "$state")"
        if [[ -n "$extra" ]]; then
            printf ',"detail":"%s"' "$(_queue_json_escape "$extra")"
        fi
        printf '}\n'
    } >> "$root/events.jsonl"
}

_queue_job_file_state() {
    local f="$1"
    basename "$(dirname "$f")"
}

_queue_tail_log_for_job() {
    local f="$1"
    local id="$2"
    local lines="${3:-${QUEUEBASH_TAIL_LINES:-40}}"
    local follow="${4:-1}"
    local from_start="${5:-0}"
    local state log

    [[ "$lines" =~ ^[0-9]+$ ]] || lines=40

    state="$(basename "$(dirname "$f")")"
    log="$(_queue_log_existing_path "$id")"

    if [[ ! -f "$log" ]]; then
        echo "queue tail: no log yet for $id ($f)" >&2
        return 1
    fi

    if [[ "$from_start" -eq 1 ]]; then
        if [[ "$state" == "running" && "$log" != *.gz && "$follow" -eq 1 ]]; then
            echo "=== tailing live from start: $log ==="
            tail -n +1 -f "$log"
        else
            echo "=== log from start: $log ==="
            _queue_log_cat "$log"
        fi
        return 0
    fi

    if [[ "$state" == "running" && "$log" != *.gz ]]; then
        if [[ "$follow" -eq 1 ]]; then
            echo "=== tailing live: $log (last $lines lines; Ctrl+C to stop) ==="
            tail -n "$lines" -f "$log"
        else
            echo "=== live log tail: $log (last $lines lines; no follow) ==="
            tail -n "$lines" -- "$log"
        fi
    else
        echo "=== completed/compressed log tail: $log (last $lines lines) ==="
        _queue_log_tail "$log" "$lines"
    fi
}


_queue_epoch_now() {
    date +%s
}

_queue_job_retry_due() {
    local f="$1"
    local not_before now
    not_before="$(grep '^RETRY_NOT_BEFORE_EPOCH=' "$f" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
    not_before="${not_before:-0}"
    now="$(_queue_epoch_now)"
    [[ "$not_before" =~ ^[0-9]+$ ]] || not_before=0
    (( not_before <= now ))
}

_queue_clone_retry_to_pending() {
    local src_job="$1"
    local new_id="$2"
    local retry_done="$3"
    local not_before="$4"
    local root="$(_queue_root)"
    local dest="$root/pending/$new_id.job"

    (
        source "$src_job" 2>/dev/null || exit 1

        {
            printf 'JOB_ID=%q\n' "$new_id"
            printf 'JOB_NAME=%q\n' "$JOB_NAME"
            printf 'PRIORITY=%q\n' "${PRIORITY:-10}"
            printf 'SUBMITTED_AT=%q\n' "$(date -Is)"
            printf 'PWD_AT_SUBMIT=%q\n' "$PWD_AT_SUBMIT"
            printf 'RETRY_OF=%q\n' "$JOB_ID"
            printf 'RETRIES_MAX=%q\n' "${RETRIES_MAX:-0}"
            printf 'RETRIES_DONE=%q\n' "$retry_done"
            printf 'RETRY_BACKOFF=%q\n' "${RETRY_BACKOFF:-0}"
            printf 'RETRY_NOT_BEFORE_EPOCH=%q\n' "$not_before"
            printf 'CPU_LIMIT=%q\n' "${CPU_LIMIT:-}"
            printf 'MEM_LIMIT=%q\n' "${MEM_LIMIT:-}"
            [[ -n "${MAX_LOG_SIZE_BYTES:-}" ]] && printf 'MAX_LOG_SIZE_BYTES=%q\n' "$MAX_LOG_SIZE_BYTES"
            [[ -n "${ALLOW_LARGE_LOG:-}" ]] && printf 'ALLOW_LARGE_LOG=%q\n' "$ALLOW_LARGE_LOG"
            [[ -n "${LOG_OVERFLOW_POLICY:-}" ]] && printf 'LOG_OVERFLOW_POLICY=%q\n' "$LOG_OVERFLOW_POLICY"
            [[ -n "${RUNNER:-}" ]] && printf 'RUNNER=%q\n' "$RUNNER"
            [[ -n "${DEPENDS_AFTER_SUCCESS:-}" ]] && printf 'DEPENDS_AFTER_SUCCESS=%q\n' "$DEPENDS_AFTER_SUCCESS"
            [[ -n "${INHERIT_ENV_FROM:-}" ]] && printf 'INHERIT_ENV_FROM=%q\n' "$INHERIT_ENV_FROM"

            printf 'COMMAND=('
            printf ' %q' "${COMMAND[@]}"
            printf ' )\n'

            printf 'ON_SUCCESS=('
            printf ' %q' "${ON_SUCCESS[@]}"
            printf ' )\n'

            printf 'ON_FAILURE=('
            printf ' %q' "${ON_FAILURE[@]}"
            printf ' )\n'
        } > "$dest"
    )
}

_queue_should_retry_failed_job() {
    local f="$1"
    local max done
    max="$(grep '^RETRIES_MAX=' "$f" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
    done="$(grep '^RETRIES_DONE=' "$f" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
    max="${max:-0}"
    done="${done:-0}"
    [[ "$max" =~ ^[0-9]+$ ]] || max=0
    [[ "$done" =~ ^[0-9]+$ ]] || done=0
    (( done < max ))
}

_queue_systemd_supported() {
    command -v systemd-run >/dev/null 2>&1 || return 1
    [[ -n "${XDG_RUNTIME_DIR:-}" || -d /run/systemd/system ]] || return 1
    return 0
}

_queuemgr_repl_complete() {
    local line point prefix before first cur
    line="${READLINE_LINE:-}"
    point="${READLINE_POINT:-0}"
    before="${line:0:point}"

    # Current token/prefix.
    cur="${before##* }"
    first="${before%% *}"
    [[ "$before" == "$first" ]] && first=""

    local commands="workers worker jobs r rd r2 r3 r4 r5 r6 r7 r8 s show t tail stream pid pids p prio priority pause pd unp unpause unpd os hooks ok fail c cancel kd kill d delete dd df u undelete ud uf rs resubmit rsd sched scheduled schedule stat stats ev events f filter n name st state a all cd cf ci cid cc ccd cdel gz gzip-logs compress-logs clog clean-logs cleanlogs log-clean logs-clean q quit help ?"

    local words matches
    if [[ -z "$first" ]]; then
        words="$commands"
    else
        case "$first" in
            st|state)
                words="all pending running paused done failed interrupted cancelled deleted"
                ;;
            f|filter|n|name|s|show|t|tail|pid|pids|p|prio|priority|pause|pd|unp|unpause|unpd|os|hooks|ok|fail|c|cancel|kd|kill|d|delete|dd|df|u|undelete|ud|uf|rs|resubmit|rsd)
                words="$(_queue_job_id_and_names_for_completion)"
                ;;
            ev|events)
                words="5 10 20 50 100"
                ;;
            r|rd)
                words=""
                ;;
            *)
                words="$commands"
                ;;
        esac
    fi

    mapfile -t matches < <(compgen -W "$words" -- "$cur")

    if [[ "${#matches[@]}" -eq 1 ]]; then
        local replacement="${matches[0]}"
        READLINE_LINE="${line:0:$((point - ${#cur}))}${replacement}${line:point}"
        READLINE_POINT=$((point - ${#cur} + ${#replacement}))
    elif [[ "${#matches[@]}" -gt 1 ]]; then
        printf '\n'
        printf '%s\n' "${matches[@]}" | column 2>/dev/null || printf '%s\n' "${matches[@]}"
        printf 'queuemgr> %s' "$READLINE_LINE"
    fi
}

_queue_job_log_max_bytes() {
    local f="$1"
    local v
    v="$(grep '^MAX_LOG_SIZE_BYTES=' "$f" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
    v="${v:-${QUEUEBASH_MAX_LOG_SIZE_BYTES:-52428800}}"
    [[ "$v" =~ ^[0-9]+$ ]] || v=52428800
    printf '%s\n' "$v"
}

_queue_parse_size_to_bytes() {
    local v="$1"
    local n unit
    [[ -z "$v" ]] && { echo 0; return; }

    if [[ "$v" =~ ^([0-9]+)([KkMmGg])?[Bb]?$ ]]; then
        n="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[2]}"
        case "$unit" in
            K|k) echo $((n * 1024)) ;;
            M|m) echo $((n * 1024 * 1024)) ;;
            G|g) echo $((n * 1024 * 1024 * 1024)) ;;
            *) echo "$n" ;;
        esac
    else
        echo 0
    fi
}

_queue_log_size_bytes() {
    local log="$1"
    [[ -f "$log" ]] || { echo 0; return; }
    wc -c < "$log" 2>/dev/null | tr -d '[:space:]'
}

_queue_append_summary_to_job() {
    local job="$1"
    local exit_code="$2"
    local log="$3"
    local root="$(_queue_root)"

    [[ -f "$job" ]] || return 0

    local started finished start_epoch finish_epoch duration log_bytes
    started="$(grep '^RUN_STARTED_AT=' "$job" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
    finished="$(date -Is)"

    start_epoch="$(date -d "$started" +%s 2>/dev/null || echo 0)"
    finish_epoch="$(date +%s)"
    if [[ "$start_epoch" =~ ^[0-9]+$ && "$start_epoch" -gt 0 ]]; then
        duration=$((finish_epoch - start_epoch))
    else
        duration=0
    fi

    log_bytes="$(_queue_log_size_bytes "$log")"

    {
        echo "EXEC_FINISHED_AT=$(printf '%q' "$finished")"
        echo "EXIT_CODE=$(printf '%q' "$exit_code")"
        echo "DURATION_SECONDS=$(printf '%q' "$duration")"
        echo "LOG_BYTES=$(printf '%q' "$log_bytes")"
    } >> "$job"
}

_queue_systemd_user_service_supported() {
    command -v systemd-run >/dev/null 2>&1 || return 1

    # systemd-run --user --pipe --wait --collect creates a transient user service and waits for its exit code.
    [[ -n "${XDG_RUNTIME_DIR:-}" ]] || return 1

    return 0
}

_queue_limit_status_text() {
    local cpu="${1:-}"
    local mem="${2:-}"

    if [[ -z "$cpu" && -z "$mem" ]]; then
        echo "none"
    elif _queue_systemd_user_service_supported; then
        echo "systemd-run-user-service-pipe"
    else
        echo "requested-but-not-enforced-systemd-run-user-service-pipe-unavailable"
    fi
}

_queue_auto_required_file_keys_from_env() {
    local var base bytes_var sha_var

    # Any inherited variable with KEY_SHA256 and KEY_BYTES metadata is treated
    # as a file hand-off that must be validated before payload launch.
    for var in ${QUEUEBASH_INHERITED_ENV_KEYS:-}; do
        case "$var" in
            *_SHA256)
                base="${var%_SHA256}"
                bytes_var="${base}_BYTES"
                sha_var="${base}_SHA256"
                if [[ "$base" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && [[ -n "${!base-}" ]] && [[ -n "${!bytes_var-}" ]] && [[ -n "${!sha_var-}" ]]; then
                    printf '%s\n' "$base"
                fi
                ;;
        esac
    done | sort -u
}

_queue_preflight_auto_required_files() {
    local key rc any=0

    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        any=1
        echo "preflight_require_file: $key"

        queue_require_file "$key"
        rc="$?"
        if [[ "$rc" -ne 0 ]]; then
            echo "preflight_require_file_failed: $key rc=$rc"
            return "$rc"
        fi

        echo "preflight_require_file_ok: $key"
    done < <(_queue_auto_required_file_keys_from_env)

    if [[ "$any" -eq 1 ]]; then
        echo "preflight_require_file_complete"
    fi

    return 0
}


_queue_build_payload_command() {
    # Prints NUL-separated argv for the actual process to spawn.
    # We prefer systemd-run for CPU/MEM limits. If no limits are requested,
    # use setsid when available so cancel can signal the process group safely.
    local cpu="${1:-}"
    local mem="${2:-}"
    local cwd="${3:-}"
    local runner="${4:-auto}"
    shift 4

    if [[ "$runner" == "systemd" ]]; then
        if _queue_systemd_user_service_supported; then
            printf '%s\0' systemd-run --user --pipe --wait --collect

            # systemd-run does not reliably preserve exported bash functions.
            # queue_output is therefore installed as an external helper command
            # and PATH / queue env are passed explicitly to the transient unit.
            local env_name env_val
            for env_name in PATH QUEUEBASH_JOB_ID QUEUEBASH_OUTPUT_ENV QUEUEBASH_ENV_OUT QUEUEBASH_STREAM_FIFO QUEUEBASH_HELPER_DIR QUEUEBASH_INHERITED_ENV_FROM QUEUEBASH_INHERITED_ENV_KEYS ${QUEUEBASH_INHERITED_ENV_KEYS:-}; do
                [[ "$env_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
                env_val="${!env_name-}"
                [[ -n "$env_val" ]] && printf '%s\0' "--setenv=${env_name}=${env_val}"
            done

            [[ -n "$cwd" ]] && printf '%s\0' --working-directory="$cwd"
            [[ -n "$cpu" ]] && printf '%s\0' -p "CPUQuota=${cpu}%"
            [[ -n "$mem" ]] && printf '%s\0' -p "MemoryMax=${mem}"
            printf '%s\0' --
            printf '%s\0' "$@"
            return 0
        fi
    fi

    if command -v setsid >/dev/null 2>&1; then
        printf '%s\0' setsid --
    fi
    printf '%s\0' "$@"
}

_queue_cancel_does_not_run_failure_hook() {
    # Documentation helper:
    # Cancellation is an operator action, not program failure.
    #
    # ON_FAILURE is deliberately reserved for commands that run to completion
    # and return a non-zero exit status. queue cancel/kill move the job record
    # to cancelled and append CANCELLED_* metadata, but they must not execute
    # ON_FAILURE. Otherwise an operator kill could accidentally trigger retry,
    # alert, or cleanup flows intended only for program failure.
    return 0
}

_queue_systemd_probe() {
    local cpu="${1:-50}"
    local mem="${2:-256M}"

    echo "Probe command:"
    printf '  %q' systemd-run --user --pipe --wait --collect -p "CPUQuota=${cpu}%" -p "MemoryMax=${mem}" -- /bin/sh -c 'echo queuebash-systemd-probe-ok; pwd; exit 0'
    echo
    echo

    systemd-run --user --pipe --wait --collect \
        --working-directory="$PWD" \
        -p "CPUQuota=${cpu}%" \
        -p "MemoryMax=${mem}" \
        -- /bin/sh -c 'echo queuebash-systemd-probe-ok; pwd; exit 0'
    local rc="$?"

    echo
    echo "probe_exit_code=$rc"
    return "$rc"
}

_queue_health_print_issue() {
    local level="$1"
    local message="$2"
    printf '[%s] %s\n' "$level" "$message"
}

_queue_job_id_from_file() {
    local f="$1"
    grep '^JOB_ID=' "$f" 2>/dev/null | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null
}

_queue_health_running_is_stale() {
    local f="$1"
    local unit run_pid
    unit="$(_queue_job_systemd_unit "$f" 2>/dev/null || true)"

    if [[ -n "$unit" ]]; then
        if _queue_systemd_unit_active "$unit"; then
            return 1
        fi
        if _queue_systemd_unit_dead "$unit"; then
            return 0
        fi
        # Unknown systemd state: fall through to RUN_PID fallback.
    fi

    run_pid="$(_queue_job_var_value "$f" RUN_PID)"
    [[ -z "$run_pid" ]] && return 2
    kill -0 "$run_pid" 2>/dev/null && return 1
    return 0
}

_queue_mark_interrupted() {
    local f="$1"
    local reason="${2:-stale_running_pid}"
    local root="$(_queue_root)"
    local id name dest

    id="$(basename "$f" .job)"
    name="$(_queue_job_name "$f")"
    dest="$root/interrupted/$id.job"

    {
        echo "INTERRUPTED_AT=$(printf '%q' "$(date -Is)")"
        echo "INTERRUPTED_REASON=$(printf '%q' "$reason")"
        echo "INTERRUPTED_FROM=running"
    } >> "$f"

    mv -f "$f" "$dest"
    _queue_log_event "interrupted" "$id" "$name" "interrupted" "reason=$reason"
    printf 'MOVED: %s (%s) running -> interrupted reason=%s\n' "$id" "$name" "$reason"
}

_queue_job_command() {
    local f="$1"
    grep '^COMMAND=' "$f" 2>/dev/null | sed 's/^COMMAND=( //; s/ )$//'
}

_queue_print_job_table() {
    local idw=6 statew=5 priw=3 namew=4 okw=2 failw=4
    local rows=()
    local f id state pri name ok fail cmd row

    for f in "$@"; do
        [[ -f "$f" ]] || continue
        id="$(basename "$f" .job)"
        state="$(basename "$(dirname "$f")")"
        pri="$(_queue_job_pri "$f")"
        name="$(_queue_job_name "$f")"
        ok="-"
        fail="-"
        _queue_job_has_array "$f" ON_SUCCESS && ok="Y"
        _queue_job_has_array "$f" ON_FAILURE && fail="Y"
        cmd="$(_queue_job_command "$f")"

        rows+=( "$id"$'\t'"$state"$'\t'"$pri"$'\t'"$name"$'\t'"$ok"$'\t'"$fail"$'\t'"$cmd" )

        (( ${#id} > idw )) && idw=${#id}
        (( ${#state} > statew )) && statew=${#state}
        (( ${#pri} > priw )) && priw=${#pri}
        (( ${#name} > namew )) && namew=${#name}
        (( ${#ok} > okw )) && okw=${#ok}
        (( ${#fail} > failw )) && failw=${#fail}
    done

    printf "%-${idw}s  %-${statew}s  %${priw}s  %-${namew}s  %-${okw}s  %-${failw}s  %s\n" \
        "JOB_ID" "STATE" "PRI" "NAME" "OK" "FAIL" "COMMAND"

    for row in "${rows[@]}"; do
        IFS=$'\t' read -r id state pri name ok fail cmd <<< "$row"
        printf "%-${idw}s  %-${statew}s  %${priw}s  %-${namew}s  %-${okw}s  %-${failw}s  %s\n" \
            "$id" "$state" "$pri" "$name" "$ok" "$fail" "$cmd"
    done
}

_queue_runner_for_job() {
    local requested="${1:-auto}"
    local cpu="${2:-}"
    local mem="${3:-}"

    requested="${requested:-${QUEUEBASH_RUNNER:-auto}}"

    case "$requested" in
        direct) echo "direct"; return 0 ;;
        systemd)
            if _queue_systemd_user_service_supported; then
                echo "systemd"
                return 0
            fi
            echo "systemd-unavailable"
            return 1
            ;;
        auto|"")
            # Prefer systemd when available, because it gives us cgroup tracking.
            if _queue_systemd_user_service_supported; then
                echo "systemd"
            else
                echo "direct"
            fi
            return 0
            ;;
        *)
            echo "direct"
            return 0
            ;;
    esac
}

_queue_systemd_unit_clean() {
    local unit="$1"
    unit="${unit%%; invocation ID:*}"
    unit="${unit%% invocation ID:*}"
    unit="$(printf '%s' "$unit" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    printf '%s\n' "$unit"
}

_queue_systemd_unit_state() {
    local unit="$1"
    unit="$(_queue_systemd_unit_clean "$unit")"
    [[ -z "$unit" ]] && return 1
    systemctl --user show "$unit" -p ActiveState --value 2>/dev/null
}

_queue_systemd_unit_substate() {
    local unit="$1"
    unit="$(_queue_systemd_unit_clean "$unit")"
    [[ -z "$unit" ]] && return 1
    systemctl --user show "$unit" -p SubState --value 2>/dev/null
}

_queue_systemd_unit_active() {
    local unit="$1"
    local state
    unit="$(_queue_systemd_unit_clean "$unit")"
    [[ -z "$unit" ]] && return 1
    state="$(_queue_systemd_unit_state "$unit" 2>/dev/null || true)"
    [[ "$state" == "active" || "$state" == "activating" || "$state" == "reloading" ]]
}

_queue_systemd_unit_dead() {
    local unit="$1"
    local state sub
    unit="$(_queue_systemd_unit_clean "$unit")"
    [[ -z "$unit" ]] && return 1
    state="$(_queue_systemd_unit_state "$unit" 2>/dev/null || true)"
    sub="$(_queue_systemd_unit_substate "$unit" 2>/dev/null || true)"
    [[ "$state" == "inactive" || "$state" == "failed" || "$state" == "not-found" || "$sub" == "dead" || "$sub" == "failed" || -z "$state" ]]
}

_queue_systemd_unit_mainpid() {
    local unit="$1"
    unit="$(_queue_systemd_unit_clean "$unit")"
    [[ -z "$unit" ]] && return 1
    systemctl --user show "$unit" -p MainPID --value 2>/dev/null
}

_queue_systemd_unit_pids() {
    local unit="$1"
    unit="$(_queue_systemd_unit_clean "$unit")"
    [[ -z "$unit" ]] && return 1
    systemctl --user status "$unit" --no-pager 2>/dev/null |
        awk '
            /^[[:space:]]*[0-9]+[[:space:]]/ { print $1 }
            /Main PID:/ {
                for (i=1; i<=NF; i++) if ($i == "PID:") print $(i+1)
            }
        ' |
        sed 's/[^0-9].*$//' |
        awk 'NF && !seen[$1]++'
}

_queue_systemd_kill_unit_tree() {
    local unit="$1"
    local sig="${2:-TERM}"
    unit="$(_queue_systemd_unit_clean "$unit")"
    [[ -z "$unit" ]] && return 1

    echo "Sending -$sig to systemd unit $unit"
    systemctl --user kill --kill-whom=all --signal="$sig" "$unit" >/dev/null 2>&1 || \
        systemctl --user kill --signal="$sig" "$unit" >/dev/null 2>&1 || true

    if [[ "$sig" == "TERM" || "$sig" == "SIGTERM" ]]; then
        systemctl --user stop "$unit" >/dev/null 2>&1 || true
    fi
    return 0
}

_queue_systemd_unit_from_log() {
    local log="$1"
    [[ -f "$log" ]] || return 1
    grep -m1 '^Running as unit:' "$log" 2>/dev/null | sed 's/^Running as unit:[[:space:]]*//; s/[[:space:]]*$//'
}

_queue_record_systemd_unit_if_seen() {
    local job="$1"
    local log="$2"
    local unit
    unit="$(_queue_systemd_unit_from_log "$log" || true)"
    [[ -z "$unit" ]] && return 0
    if ! grep -q '^SYSTEMD_UNIT=' "$job" 2>/dev/null; then
        printf 'SYSTEMD_UNIT=%q\n' "$unit" >> "$job"
    fi
}

_queue_job_systemd_unit() {
    local f="$1"
    local unit
    unit="$(grep '^SYSTEMD_UNIT=' "$f" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
    if [[ -z "$unit" ]]; then
        local id root log
        id="$(basename "$f" .job)"
        root="$(_queue_root)"
        log="$root/logs/$id.log"
        unit="$(_queue_systemd_unit_from_log "$log" || true)"
    fi
    unit="$(_queue_systemd_unit_clean "$unit")"
    printf '%s\n' "$unit"
}

_queue_show_systemd_metrics_for_job() {
    local f="$1"
    local unit
    unit="$(_queue_job_systemd_unit "$f")"

    if [[ -z "$unit" ]]; then
        echo "No SYSTEMD_UNIT recorded/found for $(basename "$f" .job)"
        return 1
    fi

    echo "Unit: $unit"
    echo

    systemctl --user show "$(_queue_systemd_unit_clean "$unit")" \
        -p Id \
        -p ActiveState \
        -p SubState \
        -p Result \
        -p MainPID \
        -p ControlGroup \
        -p CPUAccounting \
        -p CPUQuotaPerSecUSec \
        -p MemoryAccounting \
        -p MemoryMax \
        -p MemoryCurrent \
        -p TasksCurrent \
        -p ExecMainCode \
        -p ExecMainStatus \
        2>/dev/null || {
            echo "systemctl --user show failed for $unit"
            return 1
        }
}

# -------------------------------------------------------------------
# IPC helpers: env-drop outputs and live stream taps
# -------------------------------------------------------------------
_queue_output_env_path(){ local id="$1" root="$(_queue_root)"; printf '%s/outputs/%s.env\n' "$root" "$id"; }
_queue_stream_fifo_path(){ local id="$1" root="$(_queue_root)"; printf '%s/streams/%s.fifo\n' "$root" "$id"; }
_queue_stream_pid_path(){ local id="$1" root="$(_queue_root)"; printf '%s/streams/%s.tail.pid\n' "$root" "$id"; }
_queue_cleanup_stream_fifo(){
    local id="$1" fifo pidfile pid
    [[ -z "$id" ]] && return 0
    fifo="$(_queue_stream_fifo_path "$id")"; pidfile="$(_queue_stream_pid_path "$id")"
    if [[ -f "$pidfile" ]]; then
        pid="$(cat "$pidfile" 2>/dev/null || true)"
        [[ "$pid" =~ ^[0-9]+$ ]] && kill "$pid" >/dev/null 2>&1 || true
        rm -f -- "$pidfile" 2>/dev/null || true
    fi
    rm -f -- "$fifo" 2>/dev/null || true
}
_queue_cleanup_stale_ipc(){
    local root="$(_queue_root)" f base id pid
    shopt -s nullglob
    for f in "$root/streams"/*.fifo "$root/streams"/*.tail.pid; do
        [[ -e "$f" ]] || continue
        base="$(basename "$f")"; id="${base%.fifo}"; id="${id%.tail.pid}"
        if [[ ! -f "$root/running/$id.job" ]]; then
            if [[ "$f" == *.tail.pid ]]; then
                pid="$(cat "$f" 2>/dev/null || true)"
                [[ "$pid" =~ ^[0-9]+$ ]] && kill "$pid" >/dev/null 2>&1 || true
            fi
            rm -f -- "$f" 2>/dev/null || true
            echo "FIX removed stale IPC stream file: $f"
        fi
    done
    shopt -u nullglob
}
_queue_cleanup_stale_helpers() {
    local root="$(_queue_root)"
    local d id
    shopt -s nullglob
    for d in "$root/helpers"/*; do
        [[ -d "$d" ]] || continue
        id="$(basename "$d")"
        if [[ ! -f "$root/running/$id.job" ]]; then
            rm -rf "$d" 2>/dev/null || true
            echo "FIX removed stale IPC helper dir: $d"
        fi
    done
    shopt -u nullglob
}


_queue_create_stream_fifo_for_job(){ local id="$1" fifo; fifo="$(_queue_stream_fifo_path "$id")"; mkdir -p "$(dirname "$fifo")"; rm -f -- "$fifo" 2>/dev/null || true; mkfifo "$fifo" 2>/dev/null || return 1; printf '%s\n' "$fifo"; }
_queue_ipc_helper_dir() {
    local id="$1"
    local root="$(_queue_root)"
    printf '%s/helpers/%s/bin\n' "$root" "$id"
}

_queue_install_ipc_helpers() {
    local id="$1"
    local bindir helper

    bindir="$(_queue_ipc_helper_dir "$id")"
    mkdir -p "$bindir"

    helper="$bindir/queue_output"
    cat > "$helper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

key="${1:-}"
value="${2:-}"
out="${QUEUEBASH_OUTPUT_ENV:-${QUEUEBASH_ENV_OUT:-}}"

if [[ -z "$out" ]]; then
    echo "queue_output: QUEUEBASH_OUTPUT_ENV is not set; this must run inside a queue job" >&2
    exit 2
fi

if [[ -z "$key" || ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "queue_output: invalid key: $key" >&2
    exit 2
fi

mkdir -p "$(dirname "$out")"
printf 'export %s=%q\n' "$key" "$value" >> "$out"
EOF
    chmod +x "$helper"

    helper="$bindir/queue_output_file"
    cat > "$helper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

key="${1:-}"
path="${2:-}"
out="${QUEUEBASH_OUTPUT_ENV:-${QUEUEBASH_ENV_OUT:-}}"

if [[ -z "$out" ]]; then
    echo "queue_output_file: QUEUEBASH_OUTPUT_ENV is not set; this must run inside a queue job" >&2
    exit 2
fi

if [[ -z "$key" || ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "queue_output_file: invalid key: $key" >&2
    exit 2
fi

if [[ -z "$path" || ! -f "$path" ]]; then
    echo "queue_output_file: file not found: $path" >&2
    exit 3
fi

if ! command -v sha256sum >/dev/null 2>&1; then
    echo "queue_output_file: sha256sum is required" >&2
    exit 4
fi

bytes="$(wc -c < "$path" | tr -d '[:space:]')"
sha="$(sha256sum -- "$path" | awk '{print $1}')"

if mtime="$(stat -c %Y -- "$path" 2>/dev/null)"; then
    :
elif mtime="$(stat -f %m -- "$path" 2>/dev/null)"; then
    :
else
    mtime=0
fi

mkdir -p "$(dirname "$out")"
{
    printf 'export %s=%q\n' "$key" "$path"
    printf 'export %s_SHA256=%q\n' "$key" "$sha"
    printf 'export %s_BYTES=%q\n' "$key" "$bytes"
    printf 'export %s_MTIME=%q\n' "$key" "$mtime"
} >> "$out"
EOF
    chmod +x "$helper"

    helper="$bindir/queue_require_file"
    cat > "$helper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

key="${1:-}"

if [[ -z "$key" || ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "queue_require_file: invalid key: $key" >&2
    exit 2
fi

path_var="$key"
sha_var="${key}_SHA256"
bytes_var="${key}_BYTES"
mtime_var="${key}_MTIME"

path="${!path_var:-}"
expected_sha="${!sha_var:-}"
expected_bytes="${!bytes_var:-}"
expected_mtime="${!mtime_var:-}"

if [[ -z "$path" ]]; then
    echo "queue_require_file: $path_var is not set" >&2
    exit 10
fi

if [[ ! -f "$path" ]]; then
    echo "queue_require_file: file missing for $path_var: $path" >&2
    exit 11
fi

if [[ -n "$expected_bytes" ]]; then
    actual_bytes="$(wc -c < "$path" | tr -d '[:space:]')"
    if [[ "$actual_bytes" != "$expected_bytes" ]]; then
        echo "queue_require_file: byte size mismatch for $path_var: expected=$expected_bytes actual=$actual_bytes path=$path" >&2
        exit 12
    fi
fi

if [[ -n "$expected_sha" ]]; then
    if ! command -v sha256sum >/dev/null 2>&1; then
        echo "queue_require_file: sha256sum is required for $path_var validation" >&2
        exit 13
    fi

    actual_sha="$(sha256sum -- "$path" | awk '{print $1}')"
    if [[ "$actual_sha" != "$expected_sha" ]]; then
        echo "queue_require_file: sha256 mismatch for $path_var: expected=$expected_sha actual=$actual_sha path=$path" >&2
        exit 14
    fi
fi

if [[ -n "$expected_mtime" && "$expected_mtime" != "0" ]]; then
    if actual_mtime="$(stat -c %Y -- "$path" 2>/dev/null)"; then
        :
    elif actual_mtime="$(stat -f %m -- "$path" 2>/dev/null)"; then
        :
    else
        actual_mtime=""
    fi

    if [[ -n "$actual_mtime" && "$actual_mtime" != "$expected_mtime" ]]; then
        echo "queue_require_file: mtime mismatch for $path_var: expected=$expected_mtime actual=$actual_mtime path=$path" >&2
        exit 15
    fi
fi

exit 0
EOF
    chmod +x "$helper"

    printf '%s\n' "$bindir"
}

_queue_export_job_ipc_env(){
    local id="$1" out fifo helper_dir
    out="$(_queue_output_env_path "$id")"; fifo="$(_queue_stream_fifo_path "$id")"

    helper_dir="$(_queue_install_ipc_helpers "$id")"

    export QUEUEBASH_JOB_ID="$id"
    export QUEUEBASH_OUTPUT_ENV="$out"
    export QUEUEBASH_ENV_OUT="$out"
    export QUEUEBASH_STREAM_FIFO="$fifo"
    export QUEUEBASH_HELPER_DIR="$helper_dir"

    # Make queue_output available as an external command, not only as a shell
    # function. systemd-run does not reliably preserve exported bash functions.
    export PATH="$helper_dir:$PATH"

    mkdir -p "$(dirname "$out")"
    : > "$out"
}

queue_output(){
    local key="${1:-}" value="${2:-}" out="${QUEUEBASH_OUTPUT_ENV:-${QUEUEBASH_ENV_OUT:-}}"
    [[ -z "$out" ]] && { echo "queue_output: QUEUEBASH_OUTPUT_ENV is not set; this must run inside a queue job" >&2; return 2; }
    [[ -z "$key" || ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && { echo "queue_output: invalid key: $key" >&2; return 2; }
    mkdir -p "$(dirname "$out")"; printf 'export %s=%q\n' "$key" "$value" >> "$out"
}
_queue_env_drop_job_name_from_file() {
    local f="$1"
    local JOB_NAME=""
    # Job files are generated by queuebash using shell-safe assignments/arrays.
    # Source in a subshell-safe helper and print only JOB_NAME.
    (
        source "$f" >/dev/null 2>&1 || exit 1
        printf '%s\n' "${JOB_NAME:-}"
    )
}

_queue_env_drop_inherit_tokens_from_file() {
    local f="$1"
    (
        source "$f" >/dev/null 2>&1 || exit 1
        if declare -p INHERIT_ENV_FROM >/dev/null 2>&1; then
            if declare -p INHERIT_ENV_FROM 2>/dev/null | grep -q '^declare \-[^ ]*a'; then
                printf '%s\n' "${INHERIT_ENV_FROM[@]}"
            else
                printf '%s\n' "${INHERIT_ENV_FROM:-}"
            fi
        fi
    )
}

_queue_resolve_env_drop_source_qid(){
    local token="$1"
    local root="$(_queue_root)"
    local f name
    local matches=()

    [[ -z "$token" ]] && return 1

    # Direct QID path.
    if [[ -f "$root/outputs/$token.env" || -f "$root/done/$token.job" ]]; then
        printf '%s\n' "$token"
        return 0
    fi

    # Name path: inherit only from successful completed jobs.
    # Sort by filename for deterministic behaviour. If more than one successful
    # producer has the same name, refuse to guess.
    shopt -s nullglob
    for f in "$root/done"/*.job; do
        [[ -e "$f" ]] || continue
        name="$(_queue_env_drop_job_name_from_file "$f" 2>/dev/null || true)"
        if [[ "$name" == "$token" ]]; then
            matches+=( "$(basename "$f" .job)" )
        fi
    done
    shopt -u nullglob

    if [[ "${#matches[@]}" -eq 1 ]]; then
        printf '%s\n' "${matches[0]}"
        return 0
    fi

    if [[ "${#matches[@]}" -gt 1 ]]; then
        echo "queue worker: env-drop source name '$token' is ambiguous; use a QID" >&2
        return 2
    fi

    return 1
}


_queue_env_drop_keys_from_file() {
    local env_file="$1"
    local line key
    [[ -f "$env_file" ]] || return 0

    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            export\ [A-Za-z_]*=*)
                key="${line#export }"
                key="${key%%=*}"
                if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                    printf '%s\n' "$key"
                fi
                ;;
        esac
    done < "$env_file"
}

_queue_add_inherited_env_key() {
    local key="$1"
    local existing
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 0

    for existing in ${QUEUEBASH_INHERITED_ENV_KEYS:-}; do
        [[ "$existing" == "$key" ]] && return 0
    done

    export QUEUEBASH_INHERITED_ENV_KEYS="${QUEUEBASH_INHERITED_ENV_KEYS:+$QUEUEBASH_INHERITED_ENV_KEYS }$key"
}

_queue_source_env_drop_if_requested(){
    local f="$1"
    local env_id env_file qid
    local found_any=0

    while IFS= read -r env_id; do
        [[ -z "$env_id" ]] && continue
        found_any=1

        qid="$(_queue_resolve_env_drop_source_qid "$env_id" 2>/dev/null || true)"
        if [[ -z "$qid" ]]; then
            echo "queue worker: requested env-drop source is not available: $env_id" >&2
            continue
        fi

        env_file="$(_queue_output_env_path "$qid")"
        if [[ -f "$env_file" ]]; then
            export QUEUEBASH_INHERITED_ENV_FROM="${QUEUEBASH_INHERITED_ENV_FROM:+$QUEUEBASH_INHERITED_ENV_FROM }$qid"

            local _queue_env_key
            while IFS= read -r _queue_env_key; do
                _queue_add_inherited_env_key "$_queue_env_key"
            done < <(_queue_env_drop_keys_from_file "$env_file")

            # shellcheck disable=SC1090
            source "$env_file"

            for _queue_env_key in ${QUEUEBASH_INHERITED_ENV_KEYS:-}; do
                export "$_queue_env_key"
            done
        else
            echo "queue worker: requested env-drop not found: $env_file" >&2
        fi
    done < <(_queue_env_drop_inherit_tokens_from_file "$f" 2>/dev/null || true)

    return 0
}

_queue_stream_job_log_to_fifo(){ local id="$1" log="$2" fifo="$3" pidfile="$4"; ( tail -n 0 -f "$log" > "$fifo" 2>/dev/null ) & printf '%s\n' "$!" > "$pidfile"; }


_queue_log_plain_path() {
    local id="$1"
    local root="$(_queue_root)"
    printf '%s/logs/%s.log\n' "$root" "$id"
}

_queue_log_gz_path() {
    local id="$1"
    local root="$(_queue_root)"
    printf '%s/logs/%s.log.gz\n' "$root" "$id"
}

_queue_job_stream_temp_cleanup() {
    local id="$1"
    local root="$(_queue_root)"
    [[ -z "$id" ]] && return 0

    rm -f -- \
        "$root/logs/.${id}.stdout.fifo" \
        "$root/logs/.${id}.stderr.fifo" \
        "$root/logs/.${id}.stdout.suppressed" \
        "$root/logs/.${id}.stderr.suppressed" \
        2>/dev/null || true
    _queue_cleanup_stream_fifo "$id"
    _queue_class_release_claims "$id"
    rm -rf "$root/helpers/$id" 2>/dev/null || true
}

_queue_cleanup_stale_stream_temps() {
    local root="$(_queue_root)"
    local f base id

    shopt -s nullglob
    for f in "$root/logs"/.*.stdout.fifo "$root/logs"/.*.stderr.fifo "$root/logs"/.*.stdout.suppressed "$root/logs"/.*.stderr.suppressed; do
        [[ -e "$f" ]] || continue
        base="$(basename "$f")"
        id="$base"
        id="${id#.}"
        id="${id%.stdout.fifo}"
        id="${id%.stderr.fifo}"
        id="${id%.stdout.suppressed}"
        id="${id%.stderr.suppressed}"

        if [[ ! -f "$root/running/$id.job" ]]; then
            rm -f -- "$f" 2>/dev/null || true
            echo "FIX removed stale stream temp: $f"
        fi
    done
    shopt -u nullglob
}

_queue_log_existing_path() {
    local id="$1"
    local plain gz
    plain="$(_queue_log_plain_path "$id")"
    gz="$(_queue_log_gz_path "$id")"

    if [[ -f "$plain" ]]; then
        printf '%s\n' "$plain"
    elif [[ -f "$gz" ]]; then
        printf '%s\n' "$gz"
    else
        printf '%s\n' "$plain"
    fi
}

_queue_log_cat() {
    local path="$1"
    if [[ "$path" == *.gz ]]; then
        gzip -cd -- "$path"
    else
        cat -- "$path"
    fi
}

_queue_log_tail() {
    local path="$1"
    local lines="${2:-120}"

    if [[ "$path" == *.gz ]]; then
        gzip -cd -- "$path" | tail -n "$lines"
    else
        tail -n "$lines" -- "$path"
    fi
}

_queue_maybe_gzip_log() {
    local id="$1"
    local job="$2"
    local root="$(_queue_root)"
    local plain="$root/logs/$id.log"
    local gz="$root/logs/$id.log.gz"

    [[ "${QUEUEBASH_GZIP_LOGS:-1}" == "1" ]] || return 0
    command -v gzip >/dev/null 2>&1 || return 0
    [[ -f "$plain" ]] || return 0
    [[ -f "$gz" ]] && return 0

    gzip -f -- "$plain"
    if [[ -f "$gz" && -f "$job" ]]; then
        {
            printf 'LOG_COMPRESSED=%q\n' "1"
            printf 'LOG_COMPRESSED_AT=%q\n' "$(date -Is)"
            printf 'LOG_PATH=%q\n' "$gz"
        } >> "$job"
        _queue_log_event "log_compressed" "$id" "$(_queue_job_name "$job")" "$(basename "$(dirname "$job")")" "path=$gz"
    fi
}

_queue_maybe_gzip_completed_job_log() {
    local id="$1"
    local job="$2"
    local state

    [[ -f "$job" ]] || return 0
    state="$(basename "$(dirname "$job")")"

    case "$state" in
        done|failed)
            _queue_maybe_gzip_log "$id" "$job"
            ;;
        *)
            return 0
            ;;
    esac
}


_queue_compress_completed_logs() {
    local root="$(_queue_root)"
    local state f id
    for state in done failed; do
        for f in "$root/$state"/*.job; do
            [[ -e "$f" ]] || continue
            id="$(basename "$f" .job)"
            _queue_maybe_gzip_log "$id" "$f"
        done
    done
}

_queue_job_log_policy() {
    local f="$1"
    local v
    v="$(grep '^LOG_OVERFLOW_POLICY=' "$f" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
    v="${v:-${QUEUEBASH_LOG_OVERFLOW_POLICY:-stderr-only}}"
    case "$v" in
        stderr-only|stderr|drain|kill|allow) printf '%s\n' "$v" ;;
        *) printf '%s\n' "stderr-only" ;;
    esac
}

_queue_log_overflow_marker_path() {
    local id="$1"
    local stream="$2"
    local root="$(_queue_root)"
    printf '%s/logs/.%s.%s.suppressed\n' "$root" "$id" "$stream"
}

_queue_mark_log_stream_suppressed() {
    local id="$1"
    local job="$2"
    local log="$3"
    local stream="$4"
    local size="$5"
    local cap="$6"
    local marker ts

    marker="$(_queue_log_overflow_marker_path "$id" "$stream")"
    [[ -e "$marker" ]] && return 0
    : > "$marker" 2>/dev/null || true
    ts="$(date -Is)"

    {
        echo
        if [[ "$stream" == "stdout" ]]; then
            echo "LOG_OVERFLOW_WARNING: stdout log cap reached at ${size} bytes; stdout is now suppressed, stderr continues until next cutoff ${cap}."
        else
            echo "LOG_OVERFLOW_WARNING: stderr log cap reached at ${size} bytes; stderr is now suppressed too, streams are drained to protect the process."
        fi
        echo "LOG_OVERFLOW_AT=$ts"
    } >> "$log" 2>/dev/null || true

    {
        printf 'LOG_OVERFLOW=%q\n' "1"
        printf 'LOG_OVERFLOW_AT=%q\n' "$ts"
        printf 'LOG_OVERFLOW_BYTES=%q\n' "$size"
        printf 'LOG_OVERFLOW_CAP=%q\n' "$cap"
        if [[ "$stream" == "stdout" ]]; then
            printf 'LOG_STDOUT_SUPPRESSED=%q\n' "1"
            printf 'LOG_STDOUT_SUPPRESSED_AT=%q\n' "$ts"
            printf 'LOG_STDERR_ONLY_FROM_BYTES=%q\n' "$size"
        else
            printf 'LOG_STDERR_SUPPRESSED=%q\n' "1"
            printf 'LOG_STDERR_SUPPRESSED_AT=%q\n' "$ts"
        fi
    } >> "$job" 2>/dev/null || true

    _queue_log_event "log_${stream}_suppressed" "$id" "$(_queue_job_name "$job")" "running" "bytes=$size cap=$cap"
}

_queue_stream_logger() {
    local id="$1"
    local job="$2"
    local log="$3"
    local stream="$4"
    local max_bytes="$5"

    local cap first_cap second_cap policy line size

    policy="$(_queue_job_log_policy "$job")"
    cap="${max_bytes:-0}"
    [[ "$cap" =~ ^[0-9]+$ ]] || cap=0
    first_cap="$cap"
    second_cap=$((cap * 2))

    # Drain first, log second. Never close the child's stdout/stderr early.
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$cap" -le 0 || "$policy" == "allow" ]]; then
            printf '%s\n' "$line" >> "$log"
            continue
        fi

        size="$(_queue_log_size_bytes "$log")"
        size="${size:-0}"
        [[ "$size" =~ ^[0-9]+$ ]] || size=0

        case "$stream" in
            stdout)
                if (( size < first_cap )); then
                    printf '%s\n' "$line" >> "$log"
                else
                    _queue_mark_log_stream_suppressed "$id" "$job" "$log" "stdout" "$size" "$first_cap"
                fi
                ;;
            stderr)
                if (( size < second_cap )); then
                    printf '%s\n' "$line" >> "$log"
                else
                    _queue_mark_log_stream_suppressed "$id" "$job" "$log" "stderr" "$size" "$second_cap"
                fi
                ;;
            *)
                printf '%s\n' "$line" >> "$log"
                ;;
        esac
    done

    return 0
}

_queue_wait_stream_loggers() {
    local stdout_pid="${1:-}"
    local stderr_pid="${2:-}"

    [[ -n "$stdout_pid" ]] && wait "$stdout_pid" >/dev/null 2>&1 || true
    [[ -n "$stderr_pid" ]] && wait "$stderr_pid" >/dev/null 2>&1 || true
}

_queue_log_worker_record() {
    local use_stream_logger="${1:-0}"
    local log="$2"
    shift 2

    if [[ "$use_stream_logger" == "1" ]]; then
        printf '%s\n' "$@" >> "$log"
    else
        printf '%s\n' "$@"
    fi
}


_queue_log_watchdog() {
    local id="$1"
    local job="$2"
    local log="$3"
    local watched_pid="$4"
    local max_bytes="$5"
    local root="$(_queue_root)"

    [[ -z "$max_bytes" ]] && return 0
    [[ "$max_bytes" =~ ^[0-9]+$ ]] || return 0
    [[ "$max_bytes" -le 0 ]] && return 0

    local size unit pgid effective_pid
    while true; do
        unit="$(_queue_systemd_unit_from_log "$log" 2>/dev/null || true)"
        if [[ -n "$unit" ]] && _queue_systemd_unit_active "$unit"; then
            effective_pid="$(_queue_systemd_unit_mainpid "$unit")"
        else
            effective_pid="$watched_pid"
        fi

        if ! kill -0 "$effective_pid" 2>/dev/null; then
            break
        fi
        if [[ -f "$log" ]]; then
            size="$(wc -c < "$log" 2>/dev/null | tr -d '[:space:]')"
            size="${size:-0}"
            if [[ "$size" =~ ^[0-9]+$ && "$size" -gt "$max_bytes" ]]; then
                {
                    echo
                    echo "LOG_OVERFLOW_ERROR: log size ${size} exceeded cap ${max_bytes}; terminating job"
                    echo "LOG_OVERFLOW_AT=$(date -Is)"
                } >> "$log" 2>/dev/null || true

                {
                    printf 'LOG_OVERFLOW=%q\n' "1"
                    printf 'LOG_OVERFLOW_AT=%q\n' "$(date -Is)"
                    printf 'LOG_OVERFLOW_BYTES=%q\n' "$size"
                    printf 'LOG_OVERFLOW_CAP=%q\n' "$max_bytes"
                } >> "$job" 2>/dev/null || true

                _queue_log_event "log_overflow_kill" "$id" "$(_queue_job_name "$job")" "running" "bytes=$size cap=$max_bytes pid=$watched_pid"

                unit="$(_queue_systemd_unit_from_log "$log" 2>/dev/null || true)"
                if [[ -n "$unit" ]]; then
                    systemctl --user stop "$unit" >/dev/null 2>&1 || true
                fi

                pgid="$(ps -o pgid= -p "$effective_pid" 2>/dev/null | tr -d '[:space:]')"
                if [[ -n "$pgid" ]]; then
                    kill -TERM "-$pgid" >/dev/null 2>&1 || true
                fi
                kill -TERM "$effective_pid" >/dev/null 2>&1 || true

                sleep 2

                if kill -0 "$effective_pid" 2>/dev/null; then
                    if [[ -n "$unit" ]]; then
                        systemctl --user kill "$unit" >/dev/null 2>&1 || true
                    fi
                    [[ -n "$pgid" ]] && kill -KILL "-$pgid" >/dev/null 2>&1 || true
                    kill -KILL "$effective_pid" >/dev/null 2>&1 || true
                fi

                return 0
            fi
        fi
        sleep "${QUEUEBASH_LOG_WATCH_INTERVAL:-1}"
    done
}

_queue_job_var_value() {
    local f="$1"
    local key="$2"
    grep "^${key}=" "$f" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null
}

_queue_human_bytes() {
    local b="${1:-0}"
    [[ "$b" =~ ^[0-9]+$ ]] || { echo "$b"; return; }

    if (( b >= 1073741824 )); then
        awk -v b="$b" 'BEGIN { printf "%.2fG", b/1073741824 }'
    elif (( b >= 1048576 )); then
        awk -v b="$b" 'BEGIN { printf "%.2fM", b/1048576 }'
    elif (( b >= 1024 )); then
        awk -v b="$b" 'BEGIN { printf "%.2fK", b/1024 }'
    else
        printf "%sB" "$b"
    fi
}

_queue_explain_job() {
    local f="$1"
    local root="$(_queue_root)"
    local id state log log_display unit runner runner_used cpu mem maxlog largelog overflow pid pgid cmd pwd submit started finished exit_code duration log_bytes compressed log_path

    id="$(basename "$f" .job)"
    state="$(basename "$(dirname "$f")")"

    runner="$(_queue_job_var_value "$f" RUNNER)"
    runner="${runner:-${QUEUEBASH_RUNNER:-auto}}"
    runner_used="$(_queue_job_var_value "$f" RUNNER_USED)"
    if [[ -z "$runner_used" && "$state" == "pending" ]]; then
        runner_used="not-started"
    else
        runner_used="${runner_used:-unknown}"
    fi
    cpu="$(_queue_job_var_value "$f" CPU_LIMIT)"
    mem="$(_queue_job_var_value "$f" MEM_LIMIT)"
    runner_planned="$(_queue_runner_for_job "$runner" "$cpu" "$mem" 2>/dev/null || echo unknown)"
    maxlog="$(_queue_job_var_value "$f" MAX_LOG_SIZE_BYTES)"
    largelog="$(_queue_job_var_value "$f" ALLOW_LARGE_LOG)"
    overflow="$(_queue_job_var_value "$f" LOG_OVERFLOW)"
    pid="$(_queue_job_var_value "$f" RUN_PID)"
    pgid="$(_queue_job_var_value "$f" RUN_PGID)"
    unit="$(_queue_job_systemd_unit "$f" 2>/dev/null || true)"

    pwd="$(_queue_job_var_value "$f" PWD_AT_SUBMIT)"
    submit="$(_queue_job_var_value "$f" SUBMITTED_AT)"
    started="$(_queue_job_var_value "$f" RUN_STARTED_AT)"
    finished="$(_queue_job_var_value "$f" EXEC_FINISHED_AT)"
    exit_code="$(_queue_job_var_value "$f" EXIT_CODE)"
    duration="$(_queue_job_var_value "$f" DURATION_SECONDS)"
    log_bytes="$(_queue_job_var_value "$f" LOG_BYTES)"
    compressed="$(_queue_job_var_value "$f" LOG_COMPRESSED)"
    log_path="$(_queue_job_var_value "$f" LOG_PATH)"
    cmd="$(_queue_job_command "$f" 2>/dev/null || grep '^COMMAND=' "$f" | sed 's/^COMMAND=( //; s/ )$//')"

    log="$(_queue_log_existing_path "$id" 2>/dev/null || printf '%s/logs/%s.log\n' "$root" "$id")"
    if [[ -n "$log_path" ]]; then
        log_display="$log_path"
    else
        log_display="$log"
    fi

    echo "=============================================================================="
    echo "QUEUEBASH EXPLAIN: $id"
    echo "=============================================================================="
    printf "%-20s %s\n" "state:" "$state"
    printf "%-20s %s\n" "name:" "$(_queue_job_name "$f")"
    printf "%-20s %s\n" "command:" "$cmd"
    printf "%-20s %s\n" "submit directory:" "$pwd"
    printf "%-20s %s\n" "submitted:" "$submit"
    printf "%-20s %s\n" "started:" "${started:-not-started}"
    printf "%-20s %s\n" "finished:" "${finished:-not-finished}"
    [[ -n "$exit_code" ]] && printf "%-20s %s\n" "exit code:" "$exit_code"
    [[ -n "$duration" ]] && printf "%-20s %ss\n" "duration:" "$duration"
    schedule_status="$(_queue_job_schedule_status "$f" 2>/dev/null || echo due)"
    printf "%-20s %s\n" "schedule:" "$schedule_status"
    echo

    echo "Runner"
    printf "  %-18s %s\n" "requested:" "$runner"
    if [[ "$state" == "pending" ]]; then
        printf "  %-18s %s\n" "planned:" "$runner_planned"
    fi
    printf "  %-18s %s\n" "used:" "$runner_used"
    if [[ "$runner_used" == "systemd" || -n "$unit" ]]; then
        printf "  %-18s %s\n" "systemd unit:" "${unit:-not-recorded-yet}"
    fi
    if [[ -n "$pid" ]]; then
        if [[ -n "$unit" || "$runner_used" == "systemd" ]]; then
            printf "  %-18s %s\n" "RUN_PID:" "$pid (systemd-run client)"
        else
            printf "  %-18s %s\n" "RUN_PID:" "$pid"
        fi
    fi
    [[ -n "$pgid" ]] && printf "  %-18s %s\n" "RUN_PGID:" "$pgid"
    effective_pid="$(_queue_job_effective_pid "$f" 2>/dev/null || true)"
    [[ -n "$effective_pid" ]] && printf "  %-18s %s\n" "payload PID:" "$effective_pid"
    if [[ "$state" == "running" && -n "$unit" ]] && _queue_systemd_unit_dead "$unit"; then
        printf "  %-18s %s\n" "WARNING:" "job marked running but systemd unit is inactive/dead; run: queue health --fix"
    fi
    echo

    echo "Resources"
    printf "  %-18s %s\n" "CPU limit:" "${cpu:-none}"
    printf "  %-18s %s\n" "memory limit:" "${mem:-none}"
    if [[ -n "$unit" && "$runner_used" == "systemd" ]]; then
        echo "  systemd metrics:"
        systemctl --user show "$(_queue_systemd_unit_clean "$unit")" \
            -p ActiveState \
            -p SubState \
            -p MainPID \
            -p ControlGroup \
            -p CPUQuotaPerSecUSec \
            -p MemoryMax \
            -p MemoryCurrent \
            -p TasksCurrent 2>/dev/null | sed 's/^/    /' || echo "    unavailable"
    fi
    echo

    echo "Log"
    printf "  %-18s %s\n" "path:" "$log_display"
    [[ -n "$log_bytes" ]] && printf "  %-18s %s (%s bytes)\n" "final size:" "$(_queue_human_bytes "$log_bytes")" "$log_bytes"
    [[ -n "$maxlog" ]] && printf "  %-18s %s (%s bytes)\n" "cap:" "$(_queue_human_bytes "$maxlog")" "$maxlog"
    printf "  %-18s %s\n" "compressed:" "${compressed:-0}"
    printf "  %-18s %s\n" "large-log opt-in:" "${largelog:-0}"
    if [[ "${overflow:-0}" == "1" ]]; then
        printf "  %-18s %s\n" "overflow:" "YES"
        printf "  %-18s %s\n" "overflow bytes:" "$(_queue_job_var_value "$f" LOG_OVERFLOW_BYTES)"
        printf "  %-18s %s\n" "overflow cap:" "$(_queue_job_var_value "$f" LOG_OVERFLOW_CAP)"
    else
        printf "  %-18s %s\n" "overflow:" "no"
    fi
    echo

    echo "Dependencies"
    _queue_job_dependencies_status "$f" | sed 's/^/  /'

    echo

    echo "Cancellation model"
    if [[ "$state" == "pending" || "$state" == "paused" ]]; then
        echo "  job has not started yet; cancel/delete moves the job record without signalling a process."
    elif [[ "$runner_used" == "systemd" || -n "$unit" ]]; then
        echo "  systemd job: queue cancel/kill targets SYSTEMD_UNIT and does not PGID-fallback."
    else
        echo "  direct job: queue cancel/kill uses RUN_PGID/RUN_PID."
    fi
}

_queue_job_effective_pid() {
    local f="$1"
    local unit pid
    unit="$(_queue_job_systemd_unit "$f" 2>/dev/null || true)"
    if [[ -n "$unit" ]]; then
        if _queue_systemd_unit_active "$unit"; then
            pid="$(_queue_systemd_unit_mainpid "$unit")"
            if [[ -n "$pid" && "$pid" != "0" ]]; then
                printf '%s\n' "$pid"
                return 0
            fi
        fi
        # For systemd jobs RUN_PID is the systemd-run client, not the payload.
        return 1
    fi
    _queue_job_var_value "$f" RUN_PID
}

_queue_job_is_live() {
    local f="$1"
    local unit pid
    unit="$(_queue_job_systemd_unit "$f" 2>/dev/null || true)"
    if [[ -n "$unit" ]] && _queue_systemd_unit_active "$unit"; then
        return 0
    fi
    pid="$(_queue_job_var_value "$f" RUN_PID)"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

_queue_stop_job_payload() {
    local f="$1"
    local sig="${2:-TERM}"
    local unit run_pid run_pgid effective_pid

    unit="$(_queue_job_systemd_unit "$f" 2>/dev/null || true)"
    if [[ -n "$unit" ]] && _queue_systemd_unit_active "$unit"; then
        if [[ "$sig" == "KILL" || "$sig" == "9" || "$sig" == "-9" ]]; then
            systemctl --user kill --signal=KILL "$unit" >/dev/null 2>&1 || true
        else
            systemctl --user stop "$unit" >/dev/null 2>&1 || true
        fi
        return 0
    fi

    run_pid="$(_queue_job_var_value "$f" RUN_PID)"
    run_pgid="$(_queue_job_var_value "$f" RUN_PGID)"

    if [[ -n "$run_pgid" ]]; then
        kill "-$sig" "-$run_pgid" >/dev/null 2>&1 || true
    fi
    if [[ -n "$run_pid" ]]; then
        kill "-$sig" "$run_pid" >/dev/null 2>&1 || true
    fi
}

_queue_parse_age_seconds() {
    local spec="$1"
    _queue_parse_delay_seconds "$spec"
}

_queue_log_file_id() {
    local path="$1"
    local base
    base="$(basename "$path")"
    case "$base" in
        *.log.gz) base="${base%.log.gz}" ;;
        *.log) base="${base%.log}" ;;
        *.gz) base="${base%.gz}" ;;
    esac
    printf '%s\n' "$base"
}

_queue_log_job_state_for_id() {
    local id="$1"
    local root="$(_queue_root)"
    local state
    for state in pending running paused done failed interrupted cancelled deleted; do
        if [[ -f "$root/$state/$id.job" ]]; then
            printf '%s\n' "$state"
            return 0
        fi
    done
    printf '%s\n' "orphan"
}

_queue_log_job_name_for_id() {
    local id="$1"
    local root="$(_queue_root)"
    local state
    for state in pending running paused done failed interrupted cancelled deleted; do
        if [[ -f "$root/$state/$id.job" ]]; then
            _queue_job_name "$root/$state/$id.job"
            return 0
        fi
    done
    printf '%s\n' "-"
}

_queue_clean_logs_usage() {
    cat <<'EOF'
Usage:
  queue clean-logs [options]

Options:
  --dryrun, --dry-run       show what would be removed; do not delete
  --force, -f              actually remove matching logs
  --older-than AGE         only logs older than AGE: 30s, 10m, 2h, 7d, 4w
  --state STATE            only logs whose job is in STATE
                           states: done failed interrupted cancelled deleted orphan all
  --orphan                 same as --state orphan
  --all                    include all states; otherwise defaults to safe completed states
  --include-running        allow running logs to match; dangerous
  --verbose                show skipped reasons
EOF
}

_queue_log_job_file_for_id() {
    local id="$1"
    local root="$(_queue_root)"
    local state
    for state in pending running paused done failed interrupted cancelled deleted; do
        if [[ -f "$root/$state/$id.job" ]]; then
            printf '%s\n' "$root/$state/$id.job"
            return 0
        fi
    done
    return 1
}

_queue_mark_log_cleaned() {
    local id="$1"
    local path="$2"
    local bytes="$3"
    local state="$4"
    local job
    local ts

    ts="$(date -Is)"
    job="$(_queue_log_job_file_for_id "$id" 2>/dev/null || true)"

    if [[ -n "$job" && -f "$job" ]]; then
        {
            printf 'LOG_CLEANED=%q\n' "1"
            printf 'LOG_CLEANED_AT=%q\n' "$ts"
            printf 'LOG_CLEANED_PATH=%q\n' "$path"
            printf 'LOG_CLEANED_BYTES=%q\n' "$bytes"
        } >> "$job"
    fi

    _queue_log_event "log_cleaned" "$id" "$(_queue_log_job_name_for_id "$id")" "$state" "path=$path bytes=$bytes"
}

_queue_clean_logs() {
    local root="$(_queue_root)"
    local logs="$root/logs"
    local dryrun=1
    local force=0
    local older_than=""
    local older_seconds=0
    local state_filter=""
    local include_all=0
    local include_running=0
    local verbose=0

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --dryrun|--dry-run|-n) dryrun=1; shift ;;
            --force|-f|--delete) force=1; dryrun=0; shift ;;
            --older-than|--older)
                [[ -z "${2:-}" ]] && { echo "queue clean-logs: --older-than needs an age" >&2; return 2; }
                older_than="$2"
                older_seconds="$(_queue_parse_age_seconds "$older_than")" || { echo "queue clean-logs: invalid age '$older_than'" >&2; return 2; }
                shift 2
                ;;
            --state)
                [[ -z "${2:-}" ]] && { echo "queue clean-logs: --state needs a value" >&2; return 2; }
                state_filter="$2"
                shift 2
                ;;
            --orphan|--orphans) state_filter="orphan"; shift ;;
            --all) include_all=1; state_filter="all"; shift ;;
            --include-running) include_running=1; shift ;;
            --verbose|-v) verbose=1; shift ;;
            --help|-h) _queue_clean_logs_usage; return 0 ;;
            *) echo "queue clean-logs: unknown option: $1" >&2; _queue_clean_logs_usage >&2; return 2 ;;
        esac
    done

    [[ -d "$logs" ]] || { echo "No logs directory: $logs"; return 0; }

    local now cutoff path id state name eligible count=0 bytes=0 removed=0 skipped=0 size mtime
    now="$(_queue_now_epoch 2>/dev/null || date +%s)"
    if [[ "$older_seconds" =~ ^[0-9]+$ && "$older_seconds" -gt 0 ]]; then
        cutoff=$((now - older_seconds))
    else
        cutoff=0
    fi

    if [[ "$force" -eq 1 ]]; then
        echo "Cleaning matching logs..."
    else
        echo "DRYRUN: previewing matching logs. Use --force to delete."
    fi
    echo "Root: $root"
    [[ -n "$older_than" ]] && echo "Older than: $older_than"
    [[ -n "$state_filter" ]] && echo "State filter: $state_filter"
    echo

    shopt -s nullglob
    for path in "$logs"/*.log "$logs"/*.log.gz; do
        [[ -f "$path" ]] || continue
        id="$(_queue_log_file_id "$path")"
        state="$(_queue_log_job_state_for_id "$id")"
        name="$(_queue_log_job_name_for_id "$id")"
        eligible=1

        if [[ "$state" == "running" && "$include_running" -ne 1 ]]; then
            eligible=0
            [[ "$verbose" -eq 1 ]] && echo "SKIP running: $path"
        fi

        if [[ "$eligible" -eq 1 ]]; then
            if [[ -n "$state_filter" && "$state_filter" != "all" && "$state" != "$state_filter" ]]; then
                eligible=0
                [[ "$verbose" -eq 1 ]] && echo "SKIP state=$state not $state_filter: $path"
            elif [[ -z "$state_filter" && "$include_all" -ne 1 ]]; then
                case "$state" in
                    done|failed|interrupted|cancelled|deleted|orphan) ;;
                    *) eligible=0; [[ "$verbose" -eq 1 ]] && echo "SKIP unsafe state=$state: $path" ;;
                esac
            fi
        fi

        if [[ "$eligible" -eq 1 && "$cutoff" -gt 0 ]]; then
            mtime="$(stat -c %Y "$path" 2>/dev/null || stat -f %m "$path" 2>/dev/null || echo 0)"
            if [[ "$mtime" -gt "$cutoff" ]]; then
                eligible=0
                [[ "$verbose" -eq 1 ]] && echo "SKIP new: $path"
            fi
        fi

        if [[ "$eligible" -ne 1 ]]; then
            skipped=$((skipped + 1))
            continue
        fi

        size="$(stat -c %s "$path" 2>/dev/null || stat -f %z "$path" 2>/dev/null || echo 0)"
        bytes=$((bytes + size))
        count=$((count + 1))

        if [[ "$dryrun" -eq 1 ]]; then
            printf 'WOULD_REMOVE %10s  %-12s %-18s %s\n' "$size" "$state" "$name" "$path"
        else
            printf 'REMOVE       %10s  %-12s %-18s %s\n' "$size" "$state" "$name" "$path"
            _queue_mark_log_cleaned "$id" "$path" "$size" "$state"
            rm -f -- "$path"
            removed=$((removed + 1))
        fi
    done
    shopt -u nullglob

    echo
    echo "Matched logs: $count"
    echo "Matched bytes: $bytes"
    echo "Removed logs: $removed"
    echo "Skipped logs: $skipped"
}

# -------------------------------------------------------------------
# Health / integrity helpers
# -------------------------------------------------------------------

_queue_health_state_dirs() {
    printf '%s\n' pending running paused done failed interrupted cancelled deleted logs workers outputs streams
}

_queue_health_has_command() {
    command -v "$1" >/dev/null 2>&1
}

_queue_health_df_space() {
    local root="$1"
    df -Pk "$root" 2>/dev/null | awk 'NR==2 { print $4 }'
}

_queue_health_df_inodes() {
    local root="$1"
    df -Pi "$root" 2>/dev/null | awk 'NR==2 { print $4 }'
}

_queue_health_job_files() {
    local root="$(_queue_root)"
    find "$root"/pending "$root"/running "$root"/paused "$root"/done "$root"/failed "$root"/interrupted "$root"/cancelled "$root"/deleted \
        -type f -name '*.job' 2>/dev/null
}

_queue_health_job_value() {
    local f="$1"
    local key="$2"
    grep "^${key}=" "$f" 2>/dev/null | tail -1 | cut -d= -f2- | sed "s/^'//; s/'$//"
}

_queue_health_validate_job_file() {
    local f="$1"
    local errors=0
    local id name prio

    id="$(_queue_health_job_value "$f" JOB_ID)"
    name="$(_queue_health_job_value "$f" JOB_NAME)"
    prio="$(_queue_health_job_value "$f" PRIORITY)"

    if [[ -z "$id" ]]; then
        echo "BAD missing JOB_ID: $f"
        errors=$((errors + 1))
    fi
    if [[ -z "$name" ]]; then
        echo "BAD missing JOB_NAME: $f"
        errors=$((errors + 1))
    fi
    if [[ -z "$prio" ]]; then
        echo "BAD missing PRIORITY: $f"
        errors=$((errors + 1))
    elif [[ ! "$prio" =~ ^-?[0-9]+$ ]]; then
        echo "BAD non-integer PRIORITY=$prio: $f"
        errors=$((errors + 1))
    fi
    if ! grep -q '^COMMAND=(' "$f" 2>/dev/null; then
        echo "BAD missing COMMAND array: $f"
        errors=$((errors + 1))
    fi

    return "$errors"
}

_queue_health_running_is_stale2() {
    local f="$1"
    local unit run_pid
    unit="$(_queue_job_systemd_unit "$f" 2>/dev/null || true)"

    if [[ -n "$unit" ]]; then
        if _queue_systemd_unit_active "$unit"; then
            return 1
        fi
        if _queue_systemd_unit_dead "$unit"; then
            return 0
        fi
        # Unknown systemd state: fall through to RUN_PID fallback.
    fi

    run_pid="$(_queue_health_job_value "$f" RUN_PID)"
    [[ -z "$run_pid" ]] && return 0
    kill -0 "$run_pid" 2>/dev/null && return 1
    return 0
}

_queue_health_mark_interrupted() {
    local f="$1"
    local root="$(_queue_root)"
    local id name dest
    id="$(basename "$f" .job)"
    name="$(_queue_job_name "$f" 2>/dev/null || echo "-")"
    dest="$root/interrupted/$id.job"

    {
        printf 'INTERRUPTED_AT=%q\n' "$(date -Is)"
        printf 'INTERRUPTED_REASON=%q\n' "stale-running-detected-by-health"
        printf 'INTERRUPTED_FROM=%q\n' "running"
    } >> "$f"

    mv "$f" "$dest"
    _queue_job_stream_temp_cleanup "$id"
    _queue_log_event "interrupted" "$id" "$name" "interrupted" "reason=stale-running-detected-by-health"
}

_queue_health_clean_dead_workers() {
    local root="$(_queue_root)"
    local dir="$root/workers"
    local f pid

    [[ -d "$dir" ]] || return 0

    for f in "$dir"/*.pid; do
        [[ -e "$f" ]] || continue
        pid="$(cat "$f" 2>/dev/null || true)"
        if [[ -z "$pid" || ! "$pid" =~ ^[0-9]+$ || ! -d "/proc/$pid" ]]; then
            rm -f -- "$f"
            echo "FIX removed dead worker pid file: $f"
        fi
    done

    return 0
}

_queue_health_dependency_tokens_for_file() {
    local f="$1"
    _queue_job_dependency_tokens "$f" 2>/dev/null || true
}

_queue_health_dependency_exists_any_state() {
    local token="$1"
    local root="$(_queue_root)"
    local state f

    [[ -z "$token" ]] && return 1

    for state in pending running paused done failed interrupted cancelled deleted; do
        [[ -f "$root/$state/$token.job" ]] && return 0
        for f in "$root/$state"/*.job; do
            [[ -e "$f" ]] || continue
            [[ "$(_queue_job_name "$f" 2>/dev/null || true)" == "$token" ]] && return 0
        done
    done

    return 1
}

_queue_health_pending_dependency_warnings() {
    local root="$(_queue_root)"
    local f dep deps name any=0

    for f in "$root/pending"/*.job; do
        [[ -e "$f" ]] || continue
        name="$(_queue_job_name "$f" 2>/dev/null || echo "-")"
        deps="$(_queue_health_dependency_tokens_for_file "$f")"
        [[ -z "$deps" ]] && continue

        for dep in $deps; do
            if _queue_dep_token_done "$dep"; then
                continue
            elif _queue_dep_token_failed_or_cancelled "$dep"; then
                echo "WARN dependency blocked: $(basename "$f" .job) ($name) waits on failed/cancelled/interrupted/deleted $dep"
                any=1
            elif ! _queue_health_dependency_exists_any_state "$dep"; then
                echo "WARN dependency missing: $(basename "$f" .job) ($name) waits on unknown $dep"
                any=1
            else
                echo "INFO dependency waiting: $(basename "$f" .job) ($name) waits on $dep"
                any=1
            fi
        done
    done

    [[ "$any" -eq 0 ]] && echo "OK no pending dependency warnings"
    return 0
}

_queue_health_pending_cycle_warnings() {
    local root="$(_queue_root)"
    local f name deps dep depfile depdeps dep2 any=0

    for f in "$root/pending"/*.job; do
        [[ -e "$f" ]] || continue
        name="$(_queue_job_name "$f" 2>/dev/null || echo "")"
        deps="$(_queue_health_dependency_tokens_for_file "$f")"
        [[ -z "$deps" ]] && continue

        for dep in $deps; do
            if [[ "$dep" == "$name" || "$dep" == "$(basename "$f" .job)" ]]; then
                echo "WARN dependency self-cycle: $(basename "$f" .job) ($name) waits on $dep"
                any=1
                continue
            fi

            depfile=""
            if [[ -f "$root/pending/$dep.job" ]]; then
                depfile="$root/pending/$dep.job"
            else
                for depfile in "$root/pending"/*.job; do
                    [[ -e "$depfile" ]] || { depfile=""; break; }
                    if [[ "$(_queue_job_name "$depfile" 2>/dev/null || true)" == "$dep" ]]; then
                        break
                    fi
                    depfile=""
                done
            fi

            [[ -z "$depfile" || ! -f "$depfile" ]] && continue
            depdeps="$(_queue_health_dependency_tokens_for_file "$depfile")"

            for dep2 in $depdeps; do
                if [[ "$dep2" == "$name" || "$dep2" == "$(basename "$f" .job)" ]]; then
                    echo "WARN dependency 2-node cycle: $(basename "$f" .job) ($name) <-> $(basename "$depfile" .job) ($(_queue_job_name "$depfile" 2>/dev/null || echo "-"))"
                    any=1
                fi
            done
        done
    done

    [[ "$any" -eq 0 ]] && echo "OK no simple dependency cycles detected"
    return 0
}

_queue_health_report() {
    local fix=0
    local deep=0
    local root="$(_queue_root)"
    local errors=0 warnings=0
    local d space_k inodes f stale_count=0 bad_count=0

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --fix) fix=1; shift ;;
            --deep) deep=1; shift ;;
            --help|-h)
                cat <<'EOF'
Usage:
  queue health [--fix] [--deep] [--deep]

Checks:
  queue root and state directories
  logs and events.jsonl writability
  free disk space and inodes
  required/supporting commands: gzip, setsid, systemd-run
  malformed job files
  stale running jobs
  dead worker pid files
  blocked/missing dependencies
  basic dependency cycles with --deep

Safe fixes:
  create missing state/log/worker directories
  remove dead worker pid files
  move definitely stale running jobs to interrupted
EOF
                return 0
                ;;
            *)
                echo "queue health: unknown option: $1" >&2
                return 2
                ;;
        esac
    done

    echo "=== queuebash health ==="
    echo "root: $root"
    echo

    if [[ ! -d "$root" ]]; then
        echo "BAD root missing: $root"
        errors=$((errors + 1))
        if [[ "$fix" -eq 1 ]]; then
            mkdir -p "$root"
            echo "FIX created root: $root"
            errors=$((errors - 1))
        fi
    fi

    if [[ -d "$root" && ! -w "$root" ]]; then
        echo "BAD root not writable: $root"
        errors=$((errors + 1))
    else
        echo "OK root writable"
    fi

    for d in $(_queue_health_state_dirs); do
        if [[ ! -d "$root/$d" ]]; then
            echo "BAD missing directory: $root/$d"
            errors=$((errors + 1))
            if [[ "$fix" -eq 1 ]]; then
                mkdir -p "$root/$d"
                echo "FIX created directory: $root/$d"
                errors=$((errors - 1))
            fi
        else
            echo "OK directory: $d"
        fi
    done

    echo

    if [[ -d "$root" ]]; then
        if touch "$root/.health_write_test" 2>/dev/null; then
            rm -f "$root/.health_write_test"
            echo "OK root write test"
        else
            echo "BAD root write test failed"
            errors=$((errors + 1))
        fi

        if [[ -e "$root/events.jsonl" && ! -w "$root/events.jsonl" ]]; then
            echo "BAD events.jsonl not writable"
            errors=$((errors + 1))
        else
            if touch "$root/events.jsonl" 2>/dev/null; then
                echo "OK events.jsonl writable"
            else
                echo "BAD cannot touch events.jsonl"
                errors=$((errors + 1))
            fi
        fi

        space_k="$(_queue_health_df_space "$root")"
        inodes="$(_queue_health_df_inodes "$root")"
        echo "INFO free disk KB: ${space_k:-unknown}"
        echo "INFO free inodes: ${inodes:-unknown}"

        if [[ "$space_k" =~ ^[0-9]+$ && "$space_k" -lt 102400 ]]; then
            echo "WARN low disk space under queue root: ${space_k}KB"
            warnings=$((warnings + 1))
        fi
        if [[ "$inodes" =~ ^[0-9]+$ && "$inodes" -lt 1000 && "$inodes" -ne 0 ]]; then
            echo "WARN low free inodes under queue root: $inodes"
            warnings=$((warnings + 1))
        fi
    fi

    echo
    _queue_health_has_command gzip && echo "OK gzip available" || { echo "WARN gzip not available; log compression disabled"; warnings=$((warnings + 1)); }
    _queue_health_has_command setsid && echo "OK setsid available" || { echo "WARN setsid not available; direct runner process-group isolation reduced"; warnings=$((warnings + 1)); }
    _queue_health_has_command systemd-run && echo "OK systemd-run available" || echo "INFO systemd-run not available; direct runner only"

    echo
    echo "=== job metadata ==="
    while IFS= read -r f; do
        if ! _queue_health_validate_job_file "$f"; then
            bad_count=$((bad_count + 1))
        fi
    done < <(_queue_health_job_files)
    if [[ "$bad_count" -eq 0 ]]; then
        echo "OK no malformed job files found"
    else
        echo "BAD malformed job files: $bad_count"
        errors=$((errors + bad_count))
    fi

    echo
    echo "=== running jobs ==="
    for f in "$root/running"/*.job; do
        [[ -e "$f" ]] || continue
        if _queue_health_running_is_stale2 "$f"; then
            echo "BAD stale running job: $f"
            stale_count=$((stale_count + 1))
            if [[ "$fix" -eq 1 ]]; then
                _queue_health_mark_interrupted "$f"
                echo "FIX moved stale running job to interrupted: $(basename "$f")"
                stale_count=$((stale_count - 1))
            fi
        fi
    done
    if [[ "$stale_count" -eq 0 ]]; then
        echo "OK no stale running jobs"
    else
        errors=$((errors + stale_count))
    fi

    if [[ "$fix" -eq 1 ]]; then
        echo
        echo "=== worker pid cleanup ==="
        _queue_health_clean_dead_workers || true
        echo
        echo "=== stream temp cleanup ==="
        _queue_cleanup_stale_stream_temps || true
        echo
        echo "=== IPC stream cleanup ==="
        _queue_cleanup_stale_ipc || true
        echo
        echo "=== IPC helper cleanup ==="
        _queue_cleanup_stale_helpers || true
        echo
        echo "=== class/resource claim cleanup ==="
        _queue_cleanup_stale_claims || true
    fi

    echo
    echo "=== dependency status ==="
    _queue_health_pending_dependency_warnings || true

    if [[ "$deep" -eq 1 ]]; then
        echo
        echo "=== deep dependency cycle hints ==="
        _queue_health_pending_cycle_warnings || true
    fi

    echo
    echo "Health summary: errors=$errors warnings=$warnings fix=$fix deep=$deep"

    [[ "$errors" -eq 0 ]]
}

_queue_restore_print_non_deleted_matches() {
    local target="$1"
    local root="$(_queue_root)"
    local state f id name any=0

    for state in pending running paused done failed interrupted cancelled; do
        for f in "$root/$state"/*.job; do
            [[ -e "$f" ]] || continue
            id="$(basename "$f" .job)"
            name="$(_queue_job_name "$f" 2>/dev/null || true)"
            if [[ "$id" == "$target" || "$name" == "$target" || "$id" == "$target"* ]]; then
                if [[ "$any" -eq 0 ]]; then
                    echo "queue undelete: no matching deleted job: $target" >&2
                    echo "but matching job(s) exist outside deleted/:" >&2
                    echo "matches:" >&2
                    any=1
                fi
                printf '  %-34s %-12s %s\n' "$id" "$state" "$name" >&2
            fi
        done
    done

    if [[ "$any" -eq 1 ]]; then
        echo "Nothing restored. restore/undelete only operates on deleted/ jobs." >&2
        echo "Use: queue list --state deleted --name '$target'" >&2
        return 0
    fi

    return 1
}

_queue_help() {
    cat <<'EOF'
Usage:
  queue [--dryrun] <command...>
  queue submit <name> [--dryrun] [--priority N|-p N] [--on-success <cmd...>] [--on-retry-failure <cmd...>] [--on-failure <cmd...>] -- <command...>

  queue list [--state all|pending|running|paused|done|failed|interrupted|cancelled|deleted] [--name TEXT] [--filter TEXT]
  queue ls   [--state all|pending|running|paused|done|failed|interrupted|cancelled|deleted] [--name TEXT] [--filter TEXT]
  queue find <text>
  queue show <qid|exact-job-name> [--tail N|--full]
  queue tail <qid|exact-job-name>
  queue pids <qid|exact-job-name>
  queue metrics <qid|exact-job-name>
  queue explain <qid|exact-job-name>
  queue deps <qid|exact-job-name>
  queue waiting
  queue hooks <qid|exact-job-name>

  queue onsuccess <qid|exact-job-name> -- <command...>
  queue on-success <qid|exact-job-name> -- <command...>
  queue onok <qid|exact-job-name> -- <command...>
  queue onfailure <qid|exact-job-name> -- <command...>
  queue on-failure <qid|exact-job-name> -- <command...>
  queue onfail <qid|exact-job-name> -- <command...>

  queue priority <qid|exact-job-name> <priority>
  queue dynamic-prio <qid|exact-job-name> <priority> [--force] [--dryrun]
  queue prio     <qid|exact-job-name> <priority> [--force]

  queue pause   <qid|exact-job-name> [--force] [--dryrun]
  queue unpause <qid|exact-job-name> [--dryrun]
  queue resume  <qid|exact-job-name> [--dryrun]
  queue release <qid|exact-job-name> [--dryrun]

  queue delete   <qid|exact-job-name> [--force] [--dryrun]
  queue rm       <qid|exact-job-name> [--force] [--dryrun]
  queue undelete <qid|exact-job-name> [pending|done|failed] [--force]
  queue restore  <qid|exact-job-name> [pending|done|failed] [--force] [--dryrun]

  queue health [--fix] [--deep]
  queue compress-logs
  queue clean-logs [--dryrun] [--older-than AGE] [--state STATE] [--force]
  queue stats [--name exact-job-name] [--today]
  queue watch [--interval SEC]
  queue events [--tail N]

  queue run [--workers N] [--detach] [--dryrun]
  queue start [--workers N]

  queue clear done [--dryrun]
  queue clear failed [--dryrun]
  queue clear paused [--dryrun]
  queue clear deleted [--dryrun]
  queue clear all [--dryrun]

  queue limits
  queue version
  queue help

Matching rules:
  Exact QID                 -> one job
  Unique QID prefix         -> one job
  Ambiguous QID prefix      -> refused unless the command supports --force
  Exact job name            -> group operation for priority/show/hooks/pause/delete/undelete
  Job-name prefix/substr    -> never used for mutating commands

Runtime PID tracking:
  Running jobs store RUN_PID, RUN_PGID, and RUN_STARTED_AT in the job file.
  queue pids <job> shows the recorded PID and any live child processes.
  queue cancel/kill use RUN_PGID where safe to signal the process group.

Health/recovery:
  queue health reports queue integrity, dead worker PID files, and stale running jobs.
  queue health --fix creates missing directories, removes dead worker records, and moves stale running jobs to interrupted.

Structured audit:
  State transitions and operator actions append JSONL records to ~/.queuebash/events.jsonl.
  queue stats summarizes queue states; queue events shows recent audit records.

States:
  pending   waiting to run
  running   currently claimed by a worker
  paused    held; workers will not run it
  done      completed successfully
  failed    completed with non-zero exit
  interrupted worker/session died while job was running
  cancelled operator cancelled or killed
  deleted   marked deleted; can be undeleted

Batch 2:
  --retries N and --backoff SEC automatically requeue transient failures.
  --cpu PCT and --mem SIZE request systemd-run resource limits when available.

Priority:
  Higher number runs first.
  Suggested: 100 urgent, 50 high, 10 normal/default, 0 low.
  Exact job name updates all jobs with that exact name.

Log compression:
  Completed job logs are gzipped by default: QUEUEBASH_GZIP_LOGS=1.
  Set QUEUEBASH_GZIP_LOGS=0 to keep completed logs as plain .log files.
  queue show/tail read .log and .log.gz automatically.

Log cap enforcement:
  Default max log size is QUEUEBASH_MAX_LOG_SIZE_BYTES or 50MB.
  Default overflow policy is stderr-only: stdout is suppressed at the first cap,
  stderr continues until the next cap, and both streams are drained so the child
  process does not receive a broken pipe.
  Use --log-overflow kill for strict termination behaviour.
  Use --allow-large-log or --max-log-size SIZE when huge logs are intentional.

Log safety:
  queue submit accepts --max-log-size SIZE and --log-overflow stderr-only|kill|allow.
  Default is QUEUEBASH_MAX_LOG_SIZE_BYTES or 52428800 bytes.

Execution summaries:
  Completed jobs append EXIT_CODE, DURATION_SECONDS, LOG_BYTES, and EXEC_FINISHED_AT.

Dry run:
  queue --dryrun <command...> previews a mutating action without changing files.
  Most mutating commands also accept --dryrun after the command or at the end.

Cancellation semantics:
  queue cancel/kill move jobs to cancelled and do NOT run ON_FAILURE.
  ON_FAILURE is only for a command that exits non-zero by itself.
  Future ON_CANCEL support should be separate from ON_FAILURE.

Hooks:
  Hooks run after the main job has moved to done or failed.
  Use command + arguments, not a single quoted executable name.

Examples:
  queue submit unzip001 --priority 50 -- unzip ../file.zip

  queue submit ingest_tblisi -- \
    python forensic_helper.py --ingest ./dir --yaml tblisi.yaml

  queue onsuccess ingest_tblisi -- echo complete
  queue onfailure ingest_tblisi -- echo failed
  queue hooks ingest_tblisi

  queue list --state pending
  queue list --state paused
  queue list --name tblisi
  queue list --filter unzip

  queue show unzip001
  queue tail unzip001
  queue pids unzip001
  queue stats
  queue events --tail 20
  queue priority unzip001 100

  queue pause unzip001
  queue unpause unzip001

  queue delete unzip001
  queue undelete unzip001
  queue resubmit failed_job_name
  queue clear deleted

  queue run --workers 4

Queue manager:
  queuemgr
  queuemgr --state pending
  queuemgr --name tblisi
  queuemgr --filter unzip

  Inside queuemgr:
    r     run one worker in foreground
    rd    dryrun one worker
    r4    run four workers in foreground
    rd4   dryrun four workers
    start detached workers from the shell with: queue start --workers 4

Notes:
  Jobs are stored in ~/.queuebash by default.
  Set QUEUEBASH_ROOT=/some/path to use another queue root.

  For shell syntax in hooks, use bash -c:
    queue onsuccess myjob -- bash -c 'echo complete && date'
EOF
}

# -------------------------------------------------------------------
# Submit-time name binding for env-drop inheritance
# -------------------------------------------------------------------

_queue_job_name_from_file_source() {
    local f="$1"
    (
        source "$f" >/dev/null 2>&1 || exit 1
        printf '%s\n' "${JOB_NAME:-}"
    )
}

_queue_find_exact_name_qids_in_state() {
    local name="$1"
    local state="$2"
    local root="$(_queue_root)"
    local f jname

    shopt -s nullglob
    for f in "$root/$state"/*.job; do
        [[ -e "$f" ]] || continue
        jname="$(_queue_job_name_from_file_source "$f" 2>/dev/null || true)"
        if [[ "$jname" == "$name" ]]; then
            basename "$f" .job
        fi
    done
    shopt -u nullglob
}

_queue_bind_submit_reference_to_qid() {
    local token="$1"
    local root="$(_queue_root)"
    local matches=()
    local qid

    [[ -z "$token" ]] && return 1

    # Already a visible QID.
    for state in pending running paused done failed interrupted cancelled deleted; do
        if [[ -f "$root/$state/$token.job" ]]; then
            printf '%s\n' "$token"
            return 0
        fi
    done

    # Prefer exactly one not-yet-complete/live match. This is the common pipeline:
    # submit producer; submit consumer --inherit-env-from producer.
    for state in pending running paused; do
        while IFS= read -r qid; do
            [[ -n "$qid" ]] && matches+=( "$qid" )
        done < <(_queue_find_exact_name_qids_in_state "$token" "$state")
    done

    if [[ "${#matches[@]}" -eq 1 ]]; then
        printf '%s\n' "${matches[0]}"
        return 0
    fi
    if [[ "${#matches[@]}" -gt 1 ]]; then
        echo "queue submit: name '$token' matches multiple pending/running jobs; use a QID" >&2
        return 2
    fi

    # If there is no active match, allow exactly one successful historical match.
    while IFS= read -r qid; do
        [[ -n "$qid" ]] && matches+=( "$qid" )
    done < <(_queue_find_exact_name_qids_in_state "$token" "done")

    if [[ "${#matches[@]}" -eq 1 ]]; then
        printf '%s\n' "${matches[0]}"
        return 0
    fi
    if [[ "${#matches[@]}" -gt 1 ]]; then
        echo "queue submit: name '$token' matches multiple completed jobs; use a QID" >&2
        return 2
    fi

    # No current match. Keep the original token so legacy dependency waiting can
    # still handle producer submitted later. Env-drop inheritance will resolve at
    # dispatch if the name becomes unique.
    printf '%s\n' "$token"
    return 0
}

_queue_array_contains() {
    local needle="$1"
    shift
    local x
    for x in "$@"; do
        [[ "$x" == "$needle" ]] && return 0
    done
    return 1
}


queue() {
    _queue_init

    local root="$(_queue_root)"
    local dryrun=0

    if [[ "$1" == "--dryrun" || "$1" == "-n" ]]; then
        dryrun=1
        shift
    fi

    local cmd="$1"
    shift || true

    case "$cmd" in

        limits|limit-check)
            local do_probe=0
            local probe_cpu=50
            local probe_mem=256M

            while [[ "$#" -gt 0 ]]; do
                case "$1" in
                    --probe) do_probe=1; shift ;;
                    --cpu) probe_cpu="${2:-50}"; shift 2 ;;
                    --mem|--memory) probe_mem="${2:-256M}"; shift 2 ;;
                    *) shift ;;
                esac
            done

            echo "systemd-run: $(command -v systemd-run 2>/dev/null || echo missing)"
            echo "XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR:-}"
            if _queue_systemd_user_service_supported; then
                echo "resource limits: available via systemd-run --user --pipe --wait --collect"
                if [[ "$do_probe" -eq 1 ]]; then
                    echo
                    _queue_systemd_probe "$probe_cpu" "$probe_mem"
                    return "$?"
                fi
                return 0
            else
                echo "resource limits: NOT available in this shell/session"
                echo "CPU_LIMIT/MEM_LIMIT will be recorded and warned, but not enforced."
                return 1
            fi
            ;;


        version|--version|-V)
            echo "queuebash $QUEUEBASH_VERSION"
            ;;
        help|--help|-h|"")
            _queue_help
            ;;


        submit-in|in)
            local delay_spec="$1"
            [[ -z "$delay_spec" ]] && { echo "Usage: queue submit-in <delay> <name> [options] -- <command...>" >&2; return 2; }
            shift

            local delay_seconds
            delay_seconds="$(_queue_parse_delay_seconds "$delay_spec")" || {
                echo "queue submit-in: invalid delay '$delay_spec' (use e.g. 30s, 10m, 2h, 1d, 1h30m)" >&2
                return 2
            }

            QUEUEBASH_SUBMIT_NOT_BEFORE_EPOCH="$(( $(_queue_now_epoch) + delay_seconds ))" \
            QUEUEBASH_SUBMIT_SCHEDULE_LABEL="in $delay_spec" \
                queue submit "$@"
            ;;

        submit-at|at)
            local at_spec="$1"
            [[ -z "$at_spec" ]] && { echo "Usage: queue submit-at <time> <name> [options] -- <command...>" >&2; return 2; }
            shift

            local at_epoch
            at_epoch="$(_queue_parse_at_epoch "$at_spec")" || {
                echo "queue submit-at: invalid time '$at_spec' (use e.g. 23:30 or '2026-05-22 23:30')" >&2
                return 2
            }

            QUEUEBASH_SUBMIT_NOT_BEFORE_EPOCH="$at_epoch" \
            QUEUEBASH_SUBMIT_SCHEDULE_LABEL="at $at_spec" \
                queue submit "$@"
            ;;

        submit|submit-in|submit-at|in|at)
            local priority=10
            local retries_max=0
            local retry_backoff=0
            local cpu_limit=""
            local mem_limit=""
            local runner="${QUEUEBASH_RUNNER:-auto}"
            local max_log_size="${QUEUEBASH_MAX_LOG_SIZE_BYTES:-52428800}"
            local allow_large_log=0
            local log_overflow_policy="${QUEUEBASH_LOG_OVERFLOW_POLICY:-stderr-only}"
            local depends_after_success=()
            local inherit_env_from=()
            local job_class=""
            local deps_join=""
            local not_before_epoch="${QUEUEBASH_SUBMIT_NOT_BEFORE_EPOCH:-0}"
            local schedule_label="${QUEUEBASH_SUBMIT_SCHEDULE_LABEL:-}"
            local local_dryrun="$dryrun"
            local name="$1"
            shift || true

            if [[ -z "$name" ]]; then
                echo "Usage: queue submit <name> [--priority N|-p N] [--max-log-size SIZE] [--retries N] [--backoff SEC] [--cpu PCT] [--mem SIZE] [--on-success <cmd...>] [--on-retry-failure <cmd...>] [--on-failure <cmd...>] -- <command...>" >&2
                return 2
            fi

            local on_success=()
            local on_failure=()
            local on_retry_failure=()

            while [[ "$#" -gt 0 ]]; do
                case "$1" in
                    --dryrun|-n)
                        local_dryrun=1
                        shift
                        ;;
                    --priority|-p)
                        [[ -z "$2" ]] && { echo "queue submit: --priority needs a value" >&2; return 2; }
                        priority="$2"
                        shift 2
                        ;;
                    --retries)
                        [[ -z "$2" ]] && { echo "queue submit: --retries needs a value" >&2; return 2; }
                        retries_max="$2"
                        shift 2
                        ;;
                    --backoff|--retry-delay)
                        [[ -z "$2" ]] && { echo "queue submit: --backoff needs a value" >&2; return 2; }
                        retry_backoff="$2"
                        shift 2
                        ;;
                    --cpu)
                        [[ -z "$2" ]] && { echo "queue submit: --cpu needs a value" >&2; return 2; }
                        cpu_limit="$2"
                        shift 2
                        ;;
                    --mem|--memory)
                        [[ -z "$2" ]] && { echo "queue submit: --mem needs a value" >&2; return 2; }
                        mem_limit="$2"
                        shift 2
                        ;;
                    --max-log-size)
                        [[ -z "$2" ]] && { echo "queue submit: --max-log-size needs a value" >&2; return 2; }
                        max_log_size="$(_queue_parse_size_to_bytes "$2")"
                        [[ "$max_log_size" -gt 0 ]] || { echo "queue submit: invalid --max-log-size: $2" >&2; return 2; }
                        shift 2
                        ;;
                    --allow-large-log|--no-log-cap)
                        allow_large_log=1
                        max_log_size=0
                        log_overflow_policy="allow"
                        shift
                        ;;
                    --log-overflow|--log-overflow-policy)
                        [[ -z "$2" ]] && { echo "queue submit: $1 needs a value: stderr-only|kill|allow" >&2; return 2; }
                        case "$2" in
                            stderr-only|stderr|drain) log_overflow_policy="stderr-only" ;;
                            kill) log_overflow_policy="kill" ;;
                            allow) log_overflow_policy="allow"; allow_large_log=1; max_log_size=0 ;;
                            *) echo "queue submit: invalid $1: $2" >&2; return 2 ;;
                        esac
                        shift 2
                        ;;
                    --after-success|--after|--depends-on)
                        [[ -z "$2" ]] && { echo "queue submit: $1 needs a QID or exact job name" >&2; return 2; }
                        depends_after_success+=( "$2" )
                        shift 2
                        ;;
                    --inherit-env-from|--inherit-env)
                        [[ -z "$2" ]] && { echo "queue submit: $1 needs a source job QID/name" >&2; return 2; }

                        local _raw_inherit _inherit_dep _bound_ref
                        IFS=',' read -r -a _raw_inherit <<< "$2"

                        for _inherit_dep in "${_raw_inherit[@]}"; do
                            [[ -z "$_inherit_dep" ]] && continue
                            _bound_ref="$(_queue_bind_submit_reference_to_qid "$_inherit_dep")" || return 2

                            inherit_env_from+=( "$_bound_ref" )

                            # Env inheritance implies after-success dependency.
                            # Bind to QID when possible to avoid historical name ambiguity.
                            if ! _queue_array_contains "$_bound_ref" "${depends_after_success[@]}"; then
                                depends_after_success+=( "$_bound_ref" )
                            fi
                        done
                        shift 2
                        ;;
                    --class|--queue-class)
                        [[ -z "$2" ]] && { echo "queue submit: $1 needs a class name" >&2; return 2; }
                        job_class="$2"
                        shift 2
                        ;;
                    --runner)
                        [[ -z "$2" ]] && { echo "queue submit: --runner needs a value: auto|systemd|direct" >&2; return 2; }
                        runner="$2"
                        shift 2
                        ;;
                    --on-success)
                        shift
                        on_success=()
                        while [[ "$#" -gt 0 && "$1" != "--on-failure" && "$1" != "--priority" && "$1" != "-p" && "$1" != "--" ]]; do
                            on_success+=( "$1" )
                            shift
                        done
                        ;;
                    --on-retry-failure|--on-attempt-failure)
                        shift
                        on_retry_failure=()
                        while [[ "$#" -gt 0 && "$1" != "--on-success" && "$1" != "--on-failure" && "$1" != "--on-retry-failure" && "$1" != "--on-attempt-failure" && "$1" != "--priority" && "$1" != "-p" && "$1" != "--" ]]; do
                            on_retry_failure+=( "$1" )
                            shift
                        done
                        ;;
                    --on-failure)
                        shift
                        on_failure=()
                        while [[ "$#" -gt 0 && "$1" != "--on-success" && "$1" != "--on-retry-failure" && "$1" != "--on-attempt-failure" && "$1" != "--priority" && "$1" != "-p" && "$1" != "--" ]]; do
                            on_failure+=( "$1" )
                            shift
                        done
                        ;;
                    --)
                        shift
                        break
                        ;;
                    *)
                        echo "queue submit: unexpected argument before -- : $1" >&2
                        echo "Usage: queue submit <name> [--priority N|-p N] [--retries N] [--backoff SEC] [--cpu PCT] [--mem SIZE] [--on-success <cmd...>] [--on-retry-failure <cmd...>] [--on-failure <cmd...>] -- <command...>" >&2
                        return 2
                        ;;
                esac
            done

            [[ "$#" -eq 0 ]] && { echo "queue submit: missing main command" >&2; return 2; }
            [[ "$priority" =~ ^-?[0-9]+$ ]] || priority=10
            [[ "$retries_max" =~ ^[0-9]+$ ]] || retries_max=0
            [[ "$retry_backoff" =~ ^[0-9]+$ ]] || retry_backoff=0

            local dep
            for dep in "${depends_after_success[@]}"; do
                if [[ "$dep" == "$name" ]]; then
                    echo "queue submit: job cannot depend on itself: $name" >&2
                    return 2
                fi
            done

            local id="$(_queue_id)"
            local job="$root/pending/$id.job"

            if [[ "$local_dryrun" -eq 1 ]]; then
                echo "DRYRUN: would submit job:"
                echo "  id:       $id"
                echo "  name:     $name"
                echo "  priority: $priority"
                echo "  retries:  $retries_max"
                echo "  backoff:  $retry_backoff"
                echo "  cpu:      $cpu_limit"
                echo "  mem:      $mem_limit"
                echo "  maxlog:   $max_log_size"
                echo "  largelog: $allow_large_log"
                echo "  runner:   $runner"
                if [[ "${#depends_after_success[@]}" -gt 0 ]]; then
                    printf "  after-success:"
                    printf " %q" "${depends_after_success[@]}"
                    printf "\n"
                fi
                if [[ "${not_before_epoch:-0}" =~ ^[0-9]+$ && "${not_before_epoch:-0}" -gt 0 ]]; then
                    echo "  scheduled: $(date -d "@$not_before_epoch" -Is 2>/dev/null || echo "$not_before_epoch") ${schedule_label:+($schedule_label)}"
                fi
                echo "  state:    pending"
                echo "  jobfile:  $job"
                printf "  command:"
                printf " %q" "$@"
                printf "\n"
                if [[ "${#on_success[@]}" -gt 0 ]]; then
                    printf "  on-success:"
                    printf " %q" "${on_success[@]}"
                    printf "\n"
                fi
                if [[ "${#on_failure[@]}" -gt 0 ]]; then
                    printf "  on-failure:"
                    printf " %q" "${on_failure[@]}"
                    printf "\n"
                fi
                if [[ "${#on_retry_failure[@]}" -gt 0 ]]; then
                    printf "  on-retry-failure:"
                    printf " %q" "${on_retry_failure[@]}"
                    printf "\n"
                fi
                return 0
            fi

            {
                printf 'JOB_ID=%q\n' "$id"
                printf 'JOB_NAME=%q\n' "$name"
                printf 'PRIORITY=%q\n' "$priority"
                printf 'RETRIES_MAX=%q\n' "$retries_max"
                printf 'RETRIES_DONE=%q\n' "0"
                printf 'RETRY_BACKOFF=%q\n' "$retry_backoff"
                printf 'RETRY_NOT_BEFORE_EPOCH=%q\n' "0"
                printf 'NOT_BEFORE_EPOCH=%q\n' "$not_before_epoch"
                [[ -n "$schedule_label" ]] && printf 'SCHEDULE_LABEL=%q\n' "$schedule_label"
                printf 'CPU_LIMIT=%q\n' "$cpu_limit"
                printf 'MEM_LIMIT=%q\n' "$mem_limit"
                printf 'MAX_LOG_SIZE_BYTES=%q\n' "$max_log_size"
                printf 'ALLOW_LARGE_LOG=%q\n' "$allow_large_log"
                printf 'LOG_OVERFLOW_POLICY=%q\n' "$log_overflow_policy"
                printf 'RUNNER=%q\n' "$runner"
                printf 'JOB_CLASS=%q\n' "${job_class:-${QUEUEBASH_DEFAULT_CLASS:-DEFAULT}}"
                if [[ "${#depends_after_success[@]}" -gt 0 ]]; then
                    deps_join="${depends_after_success[*]}"
                    printf 'DEPENDS_AFTER_SUCCESS=%q\n' "$deps_join"
                fi
                if [[ "${#inherit_env_from[@]}" -gt 0 ]]; then
                    printf 'INHERIT_ENV_FROM=%q\n' "${inherit_env_from[*]}"
                fi
                printf 'SUBMITTED_AT=%q\n' "$(date -Is)"
                printf 'PWD_AT_SUBMIT=%q\n' "$PWD"

                printf 'COMMAND=('
                printf ' %q' "$@"
                printf ' )\n'

                printf 'ON_SUCCESS=('
                printf ' %q' "${on_success[@]}"
                printf ' )\n'

                printf 'ON_FAILURE=('
                printf ' %q' "${on_failure[@]}"
                printf ' )\n'

                printf 'ON_RETRY_FAILURE=('
                printf ' %q' "${on_retry_failure[@]}"
                printf ' )\n'
            } > "$job"

            echo "Submitted $id : $name priority=$priority"
            if [[ "${not_before_epoch:-0}" =~ ^[0-9]+$ && "${not_before_epoch:-0}" -gt 0 ]]; then
                echo "  scheduled for: $(date -d "@$not_before_epoch" -Is 2>/dev/null || echo "$not_before_epoch") ${schedule_label:+($schedule_label)}"
            fi
            _queue_log_event "submitted" "$id" "$name" "pending" "priority=$priority"

            if [[ "${#on_success[@]}" -gt 0 ]]; then
                printf "  on-success:"
                printf " %q" "${on_success[@]}"
                printf "\n"
            fi

            if [[ "${#on_failure[@]}" -gt 0 ]]; then
                printf "  on-failure:"
                printf " %q" "${on_failure[@]}"
                printf "\n"
            fi

            if [[ "${#on_retry_failure[@]}" -gt 0 ]]; then
                printf "  on-retry-failure:"
                printf " %q" "${on_retry_failure[@]}"
                printf "\n"
            fi
            ;;

        list|ls)
            local filter_state="all"
            local filter_name=""
            local filter_text=""
            local jobs=()

            while [[ "$#" -gt 0 ]]; do
                case "$1" in
                    --state|-s)
                        filter_state="$2"
                        shift 2
                        ;;
                    --name|-n)
                        filter_name="$2"
                        shift 2
                        ;;
                    --filter|-f)
                        filter_text="$2"
                        shift 2
                        ;;
                    *)
                        break
                        ;;
                esac
            done

            local state f id name pri line
            for state in pending running paused done failed interrupted cancelled deleted; do
                [[ "$filter_state" != "all" && "$filter_state" != "$state" ]] && continue

                for f in "$root/$state"/*.job; do
                    [[ -e "$f" ]] || continue

                    id="$(basename "$f" .job)"
                    name="$(_queue_job_name "$f")"
                    pri="$(_queue_job_pri "$f")"
                    line="$(_queue_job_command "$f")"

                    [[ -n "$filter_name" && "$name" != *"$filter_name"* ]] && continue
                    [[ -n "$filter_text" && "$id $state $pri $name $line" != *"$filter_text"* ]] && continue

                    jobs+=( "$f" )
                done
            done

            _queue_print_job_table "${jobs[@]}"
            ;;

        find)
            local text="$1"
            [[ -z "$text" ]] && { echo "Usage: queue find <text>" >&2; return 2; }
            queue list --filter "$text"
            ;;





        scheduled|schedule)
            local f any=0
            for f in "$root/pending"/*.job; do
                [[ -e "$f" ]] || continue
                if ! _queue_job_schedule_due "$f"; then
                    any=1
                    echo "=============================================================================="
                    echo "Job: $(basename "$f" .job)  Name: $(_queue_job_name "$f")"
                    echo "Schedule: $(_queue_job_schedule_status "$f")"
                    echo "Dependencies:"
                    _queue_job_dependencies_status "$f" | sed 's/^/  /'
                fi
            done
            [[ "$any" -eq 0 ]] && echo "No pending jobs are waiting on schedule."
            return 0
            ;;


        waiting|blocked)
            local f any=0
            for f in "$root/pending"/*.job; do
                [[ -e "$f" ]] || continue
                _queue_job_dependencies_satisfied "$f" && continue
                any=1
                echo "=============================================================================="
                echo "Job: $(basename "$f" .job)  Name: $(_queue_job_name "$f")"
                echo "Dependencies:"
                _queue_job_dependencies_status "$f" | sed 's/^/  /'
            done
            [[ "$any" -eq 0 ]] && echo "No pending jobs are waiting on dependencies."
            return 0
            ;;


        deps|dependencies)
            local target="$1"
            [[ -z "$target" ]] && { echo "Usage: queue deps <qid-or-exact-job-name>" >&2; return 2; }

            local matches=()
            local f
            while IFS= read -r f; do
                matches+=( "$f" )
            done < <(_queue_find_jobs "$target")

            [[ "${#matches[@]}" -eq 0 ]] && { echo "queue deps: no such QID or exact job name: $target" >&2; return 1; }

            local shown=0
            for f in "${matches[@]}"; do
                echo "=============================================================================="
                echo "Job: $(basename "$f" .job)  State: $(basename "$(dirname "$f")")  Name: $(_queue_job_name "$f")"
                echo "Dependencies:"
                _queue_job_dependencies_status "$f" | sed 's/^/  /'
                shown=$((shown + 1))
            done
            echo "Shown dependencies for $shown job(s)."
            ;;


        explain)
            local target="$1"
            [[ -z "$target" ]] && { echo "Usage: queue explain <qid-or-exact-job-name>" >&2; return 2; }

            local matches=()
            local f
            while IFS= read -r f; do
                matches+=( "$f" )
            done < <(_queue_find_jobs "$target")

            [[ "${#matches[@]}" -eq 0 ]] && { echo "queue explain: no such QID or exact job name: $target" >&2; return 1; }

            local exact_name_count
            exact_name_count="$(_queue_exact_name_count "$target" "${matches[@]}")"
            if [[ "$exact_name_count" -eq 0 && "${#matches[@]}" -gt 1 ]]; then
                echo "queue explain: ambiguous QID prefix: $target" >&2
                _queue_print_matches "${matches[@]}"
                return 2
            fi
            local explained=0
            for f in "${matches[@]}"; do
                _queue_explain_job "$f"
                explained=$((explained + 1))
                if [[ "$explained" -lt "${#matches[@]}" ]]; then
                    echo
                fi
            done
            echo
            echo "Explained $explained job(s)."
            ;;


        show)
            local target="$1"
            shift || true
            local show_full=0
            local show_tail=120

            while [[ "$#" -gt 0 ]]; do
                case "$1" in
                    --full) show_full=1; shift ;;
                    --tail|-n) show_tail="${2:-120}"; shift 2 ;;
                    *) shift ;;
                esac
            done

            [[ -z "$target" ]] && { echo "Usage: queue show <qid-or-exact-job-name> [--tail N|--full]" >&2; return 2; }

            local matches=()
            local f
            while IFS= read -r f; do
                matches+=( "$f" )
            done < <(_queue_find_jobs "$target")

            [[ "${#matches[@]}" -eq 0 ]] && { echo "queue show: no such QID or exact job name: $target" >&2; return 1; }

            local exact_name_count
            exact_name_count="$(_queue_exact_name_count "$target" "${matches[@]}")"
            if [[ "$exact_name_count" -eq 0 && "${#matches[@]}" -gt 1 ]]; then
                echo "queue show: ambiguous QID prefix: $target" >&2
                _queue_print_matches "${matches[@]}"
                return 2
            fi

            local shown=0
            local id state log_path
            for f in "${matches[@]}"; do
                id="$(basename "$f" .job)"
                state="$(basename "$(dirname "$f")")"
                echo "=============================================================================="
                echo "JOB: $id   STATE: $state"
                echo "=============================================================================="
                echo "=== $f ==="
                cat "$f"

                log_path="$(_queue_log_existing_path "$id")"
                if [[ -f "$log_path" ]]; then
                    echo
                    echo "=== log: $log_path ==="
                    if [[ "$show_full" -eq 1 ]]; then
                        _queue_log_cat "$log_path"
                    else
                        _queue_log_tail "$log_path" "$show_tail"
                        echo
                        echo "=== showing last $show_tail lines; use queue show $id --full for complete log ==="
                    fi
                fi

                shown=$((shown + 1))
            done
            echo
            echo "Shown $shown job(s)."
            ;;

        tail|follow)
            local lines="${QUEUEBASH_TAIL_LINES:-40}"
            local follow=1
            local from_start=0
            local target=""

            while [[ "$#" -gt 0 ]]; do
                case "$1" in
                    --tail|-n)
                        [[ -z "${2:-}" ]] && { echo "queue tail: $1 requires a line count" >&2; return 2; }
                        lines="$2"
                        shift 2
                        ;;
                    --no-follow|--no-f|--once)
                        follow=0
                        shift
                        ;;
                    --follow|-f)
                        follow=1
                        shift
                        ;;
                    --from-start|--full|--cat)
                        from_start=1
                        shift
                        ;;
                    --help|-h)
                        cat <<'EOF'
Usage:
  queue tail <qid-or-exact-job-name> [--tail N] [--no-follow] [--from-start] [--tail N|-n N] [--no-follow] [--from-start]

Defaults:
  running job: show last 40 lines, then follow
  completed job: show last 40 lines and return

Options:
  --tail N       number of physical log lines to show before following; default 40
  --no-follow   show tail and return, even for running jobs
  --from-start  show from start; follows if job is running
EOF
                        return 0
                        ;;
                    --*)
                        echo "queue tail: unknown option: $1" >&2
                        return 2
                        ;;
                    *)
                        if [[ -z "$target" ]]; then
                            target="$1"
                            shift
                        else
                            echo "queue tail: unexpected argument: $1" >&2
                            return 2
                        fi
                        ;;
                esac
            done

            [[ -z "$target" ]] && { echo "Usage: queue tail <qid-or-exact-job-name> [--tail N] [--no-follow] [--from-start] [--tail N|-n N] [--no-follow] [--from-start]" >&2; return 2; }
            [[ "$lines" =~ ^[0-9]+$ ]] || { echo "queue tail: --tail requires a numeric line count" >&2; return 2; }

            local matches=()
            local running_matches=()
            local f state
            while IFS= read -r f; do
                matches+=( "$f" )
                state="$(_queue_job_file_state "$f")"
                [[ "$state" == "running" ]] && running_matches+=( "$f" )
            done < <(_queue_find_jobs "$target")

            [[ "${#matches[@]}" -eq 0 ]] && { echo "queue tail: no such QID or exact job name: $target" >&2; return 1; }

            local chosen=""
            if [[ "${#running_matches[@]}" -eq 1 ]]; then
                chosen="${running_matches[0]}"
            elif [[ "${#running_matches[@]}" -gt 1 ]]; then
                echo "Multiple running jobs match '$target':"
                local i=1
                for f in "${running_matches[@]}"; do
                    printf "  [%d] %-40s %s\n" "$i" "$(basename "$f" .job)" "$(_queue_job_name "$f")"
                    i=$((i + 1))
                done
                local choice
                read -r -p "Select job [1-${#running_matches[@]}]: " choice
                if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "${#running_matches[@]}" ]]; then
                    chosen="${running_matches[$((choice - 1))]}"
                else
                    echo "queue tail: invalid selection" >&2
                    return 2
                fi
            else
                local exact_name_count
                exact_name_count="$(_queue_exact_name_count "$target" "${matches[@]}")"
                if [[ "$exact_name_count" -eq 0 && "${#matches[@]}" -gt 1 ]]; then
                    echo "queue tail: ambiguous QID prefix: $target" >&2
                    _queue_print_matches "${matches[@]}"
                    return 2
                fi
                if [[ "${#matches[@]}" -gt 1 ]]; then
                    echo "queue tail: multiple non-running jobs named '$target'; use a QID or tail a running job" >&2
                    _queue_print_matches "${matches[@]}"
                    return 2
                fi
                chosen="${matches[0]}"
            fi

            local id
            id="$(basename "$chosen" .job)"
            _queue_tail_log_for_job "$chosen" "$id" "$lines" "$follow" "$from_start"
            ;;



        stream)
            local target="${1:-}"
            [[ -z "$target" ]] && { echo "Usage: queue stream <running-qid-or-name>" >&2; return 2; }
            local running_matches=() f state
            while IFS= read -r f; do state="$(_queue_job_file_state "$f")"; [[ "$state" == "running" ]] && running_matches+=( "$f" ); done < <(_queue_find_jobs "$target")
            [[ "${#running_matches[@]}" -eq 0 ]] && { echo "queue stream: no running job matches: $target" >&2; return 1; }
            local chosen=""
            if [[ "${#running_matches[@]}" -eq 1 ]]; then chosen="${running_matches[0]}"; else
                echo "Multiple running jobs match '$target':"; local i=1 choice
                for f in "${running_matches[@]}"; do printf "  [%d] %-40s %s\n" "$i" "$(basename "$f" .job)" "$(_queue_job_name "$f")"; i=$((i+1)); done
                read -r -p "Select job [1-${#running_matches[@]}]: " choice
                [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "${#running_matches[@]}" ]] || { echo "queue stream: invalid selection" >&2; return 2; }
                chosen="${running_matches[$((choice-1))]}"
            fi
            local id fifo pidfile log oldpid
            id="$(basename "$chosen" .job)"; fifo="$(_queue_stream_fifo_path "$id")"; pidfile="$(_queue_stream_pid_path "$id")"; log="$(_queue_log_existing_path "$id")"
            [[ -p "$fifo" ]] || mkfifo "$fifo"
            if [[ -f "$pidfile" ]]; then oldpid="$(cat "$pidfile" 2>/dev/null || true)"; [[ "$oldpid" =~ ^[0-9]+$ ]] && kill "$oldpid" >/dev/null 2>&1 || true; rm -f -- "$pidfile" 2>/dev/null || true; fi
            _queue_stream_job_log_to_fifo "$id" "$log" "$fifo" "$pidfile"
            echo "=== streaming FIFO tap: $fifo ==="
            cat "$fifo"
            ;;


        assets|facilities)
            local action="${1:-list}"
            case "$action" in
                list|"")
                    echo "=== queue asset facilities ==="
                    _queue_asset_scan_facilities | sort
                    ;;
                show)
                    local family="${2:-}"
                    [[ -z "$family" ]] && { echo "Usage: queue assets show <family>" >&2; return 2; }
                    local helper
                    helper="$(_queue_asset_helper_path "$family")"
                    [[ -f "$helper" ]] || { echo "queue assets: no helper for family: $family ($helper)" >&2; return 1; }
                    echo "=== asset family: $family ==="
                    echo "file: $helper"
                    (
                        source "$helper" >/dev/null 2>&1 || exit 1
                        if declare -F queue_asset_facilities >/dev/null 2>&1; then
                            queue_asset_facilities
                        else
                            echo "No queue_asset_facilities publisher found."
                        fi
                    )
                    ;;
                *)
                    echo "Usage: queue assets list|show <family>" >&2
                    return 2
                    ;;
            esac
            ;;


        class|classes)
            local action="${1:-list}"
            local root="$(_queue_root)"
            case "$action" in
                list|"")
                    echo "=== queue classes ==="
                    mkdir -p "$root/classes"
                    local cf
                    shopt -s nullglob
                    for cf in "$root/classes"/*.env; do
                        basename "$cf" .env
                    done
                    shopt -u nullglob
                    ;;
                show)
                    local cname="${2:-}"
                    [[ -z "$cname" ]] && { echo "Usage: queue class show <class>" >&2; return 2; }
                    local cfile
                    cfile="$(_queue_class_file "$cname")"
                    [[ -f "$cfile" ]] || { echo "queue class: not found: $cname ($cfile)" >&2; return 1; }
                    echo "=== class: $cname ==="
                    echo "file: $cfile"
                    cat "$cfile"
                    ;;
                init)
                    local cname="${2:-}"
                    [[ -z "$cname" ]] && { echo "Usage: queue class init <class>" >&2; return 2; }
                    local cfile
                    cfile="$root/classes/$cname.env"
                    [[ -e "$cfile" ]] && { echo "queue class: already exists: $cfile" >&2; return 1; }
                    cat > "$cfile" <<'EOF'
# bashqueues class definition
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_SHARED_ASSETS=""
CLASS_EXCLUSIVE_ASSETS=""
EOF
                    echo "Created $cfile"
                    ;;
                *)
                    echo "Usage: queue class list|show <class>|init <class>" >&2
                    return 2
                    ;;
            esac
            ;;

        claims|resources)
            local root="$(_queue_root)"
            echo "=== class claims ==="
            find "$root/claims/classes" -mindepth 1 -maxdepth 1 -type d -name '*.claim' -printf '%f\n' 2>/dev/null | sort
            echo
            echo "=== asset claims ==="
            find "$root/claims/assets" -mindepth 1 -maxdepth 1 -type d -name '*.claim' -printf '%f\n' 2>/dev/null | sort
            ;;




        compress-logs|gzip-logs)
            echo "Bulk-compressing completed done/failed logs..."
            _queue_compress_completed_logs
            echo "Done."
            ;;


        health)
            _queue_health_report "$@"
            ;;

        stats)
            local filter_name=""
            local today=0
            while [[ "$#" -gt 0 ]]; do
                case "$1" in
                    --name|-n) filter_name="$2"; shift 2 ;;
                    --today) today=1; shift ;;
                    *) shift ;;
                esac
            done

            local today_prefix
            today_prefix="$(date +%Y-%m-%d)"

            echo "=== Queue statistics ==="
            [[ -n "$filter_name" ]] && echo "name: $filter_name"
            [[ "$today" -eq 1 ]] && echo "submitted: today ($today_prefix)"
            echo "------------------------"

            local state f name submitted count total=0
            for state in pending running paused done failed interrupted cancelled deleted; do
                count=0
                for f in "$root/$state"/*.job; do
                    [[ -e "$f" ]] || continue
                    name="$(_queue_job_name "$f")"
                    submitted="$(grep '^SUBMITTED_AT=' "$f" 2>/dev/null | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
                    [[ -n "$filter_name" && "$name" != "$filter_name" ]] && continue
                    [[ "$today" -eq 1 && "$submitted" != "$today_prefix"* ]] && continue
                    count=$((count + 1))
                done
                total=$((total + count))
                printf "%-10s %6d\n" "$state:" "$count"
            done
            printf "%-10s %6d\n" "total:" "$total"
            ;;

        events)
            local n=20
            if [[ "${1:-}" == "--tail" || "${1:-}" == "-n" ]]; then
                n="$2"
            fi
            [[ "$n" =~ ^[0-9]+$ ]] || n=20
            if [[ -f "$root/events.jsonl" ]]; then
                tail -n "$n" "$root/events.jsonl"
            else
                echo "queue events: no events.jsonl yet"
            fi
            ;;



        unit|metrics|metric)
            local target="$1"
            [[ -z "$target" ]] && { echo "Usage: queue metrics <qid-or-exact-job-name>" >&2; return 2; }

            local matches=()
            local f
            while IFS= read -r f; do
                matches+=( "$f" )
            done < <(_queue_find_jobs "$target")

            [[ "${#matches[@]}" -eq 0 ]] && { echo "queue metrics: no such QID or exact job name: $target" >&2; return 1; }

            local exact_name_count
            exact_name_count="$(_queue_exact_name_count "$target" "${matches[@]}")"
            if [[ "$exact_name_count" -eq 0 && "${#matches[@]}" -gt 1 ]]; then
                echo "queue metrics: ambiguous QID prefix: $target" >&2
                _queue_print_matches "${matches[@]}"
                return 2
            fi
            if [[ "${#matches[@]}" -gt 1 ]]; then
                echo "queue metrics: multiple jobs named '$target'; use a QID" >&2
                _queue_print_matches "${matches[@]}"
                return 2
            fi

            _queue_show_systemd_metrics_for_job "${matches[0]}"
            ;;


        pids|pid|ps)
            local target="$1"
            [[ -z "$target" ]] && { echo "Usage: queue pids <qid-or-exact-job-name>" >&2; return 2; }

            local matches=()
            local f
            while IFS= read -r f; do
                matches+=( "$f" )
            done < <(_queue_find_jobs "$target")

            [[ "${#matches[@]}" -eq 0 ]] && { echo "queue pids: no such QID or exact job name: $target" >&2; return 1; }

            local exact_name_count
            exact_name_count="$(_queue_exact_name_count "$target" "${matches[@]}")"
            if [[ "$exact_name_count" -eq 0 && "${#matches[@]}" -gt 1 ]]; then
                echo "queue pids: ambiguous QID prefix: $target" >&2
                _queue_print_matches "${matches[@]}"
                return 2
            fi

            local shown=0
            local id name run_pid run_pgid unit mainpid effective
            for f in "${matches[@]}"; do
                id="$(basename "$f" .job)"
                name="$(_queue_job_name "$f")"
                run_pid="$(_queue_job_var_value "$f" RUN_PID)"
                run_pgid="$(_queue_job_var_value "$f" RUN_PGID)"
                unit="$(_queue_job_systemd_unit "$f" 2>/dev/null || true)"
                effective="$(_queue_job_effective_pid "$f" 2>/dev/null || true)"

                echo "=============================================================================="
                echo "Job: $id"
                echo "Name: $name"
                echo "Recorded RUN_PID: ${run_pid:-}"
                echo "Recorded RUN_PGID: ${run_pgid:-}"
                echo "Run started: $(_queue_job_var_value "$f" RUN_STARTED_AT)"

                if [[ -n "$unit" ]]; then
                    echo "Systemd unit: $unit"
                    if _queue_systemd_unit_active "$unit"; then
                        mainpid="$(_queue_systemd_unit_mainpid "$unit")"
                        echo "Systemd unit is active."
                        echo "Systemd MainPID: $mainpid"
                        if [[ -n "$mainpid" && "$mainpid" != "0" ]]; then
                            ps -o pid,ppid,pgid,stat,etime,pcpu,pmem,comm,args -p "$mainpid" 2>/dev/null || true
                        fi
                    else
                        echo "Systemd unit is not active."
                    fi
                elif [[ -n "$run_pid" && -d "/proc/$run_pid" ]]; then
                    echo
                    ps -o pid,ppid,pgid,stat,etime,pcpu,pmem,comm,args -p "$run_pid" 2>/dev/null || true
                    if [[ -n "$run_pgid" ]]; then
                        echo
                        echo "Process group $run_pgid:"
                        ps -o pid,ppid,pgid,stat,etime,pcpu,pmem,comm,args -g "$run_pgid" 2>/dev/null || true
                    fi
                else
                    echo
                    echo "No live RUN_PID or active systemd unit found."
                fi

                shown=$((shown + 1))
            done
            echo "Shown PID info for $shown job(s)."
            ;;


        hooks|hook)
            local target="$1"
            [[ -z "$target" ]] && { echo "Usage: queue hooks <qid-or-exact-job-name>" >&2; return 2; }

            local matches=()
            local f
            while IFS= read -r f; do
                matches+=( "$f" )
            done < <(_queue_find_jobs "$target")

            [[ "${#matches[@]}" -eq 0 ]] && { echo "queue hooks: no matching job: $target" >&2; return 1; }

            local exact_name_count
            exact_name_count="$(_queue_exact_name_count "$target" "${matches[@]}")"
            if [[ "$exact_name_count" -eq 0 && "${#matches[@]}" -gt 1 ]]; then
                echo "queue hooks: ambiguous QID prefix: $target" >&2
                _queue_print_matches "${matches[@]}"
                return 2
            fi

            for f in "${matches[@]}"; do
                local id state name
                id="$(basename "$f" .job)"
                state="$(basename "$(dirname "$f")")"
                name="$(_queue_job_name "$f")"
                echo "Job: $id  State: $state  Name: $name"
                echo "on-success: $(_queue_job_array_summary "$f" ON_SUCCESS)"
                echo "on-failure: $(_queue_job_array_summary "$f" ON_FAILURE)"
            done
            ;;

        onsuccess|on-success|onok|on-ok|onfailure|on-failure|onfail|on-fail)
            local hookvar
            local local_dryrun="$dryrun"
            if [[ "$1" == "--dryrun" || "$1" == "-n" ]]; then
                local_dryrun=1
                shift
            fi
            case "$cmd" in
                onsuccess|on-success|onok|on-ok) hookvar="ON_SUCCESS" ;;
                *) hookvar="ON_FAILURE" ;;
            esac

            local target="$1"
            shift || true

            if [[ "$1" == "--dryrun" || "$1" == "-n" ]]; then
                local_dryrun=1
                shift
            fi

            if [[ -z "$target" || "$1" != "--" ]]; then
                echo "Usage: queue $cmd <qid-or-exact-job-name> -- <command...>" >&2
                echo "Use an empty command after -- to clear."
                return 2
            fi
            shift

            local matches=()
            local f
            while IFS= read -r f; do
                matches+=( "$f" )
            done < <(_queue_find_jobs "$target")

            [[ "${#matches[@]}" -eq 0 ]] && { echo "queue $cmd: no matching job: $target" >&2; return 1; }

            local exact_name_count
            exact_name_count="$(_queue_exact_name_count "$target" "${matches[@]}")"
            if [[ "$exact_name_count" -eq 0 && "${#matches[@]}" -gt 1 ]]; then
                echo "queue $cmd: ambiguous QID prefix: $target" >&2
                _queue_print_matches "${matches[@]}"
                return 2
            fi

            local changed=0
            for f in "${matches[@]}"; do
                if [[ "$local_dryrun" -eq 1 ]]; then
                    printf "DRYRUN: would set %s for %s to:" "$hookvar" "$(basename "$f" .job)"
                    printf " %q" "$@"
                    printf "\n"
                else
                    _queue_set_job_array "$f" "$hookvar" "$@"
                    echo "Updated $hookvar for $(basename "$f" .job)"
                fi
                changed=$((changed + 1))
            done
            if [[ "$local_dryrun" -eq 1 ]]; then
                echo "DRYRUN: would update $changed job(s)."
            else
                if [[ "$local_dryrun" -eq 1 ]]; then
                echo "DRYRUN: would update $changed job(s)."
            else
                echo "Updated $changed job(s)."
            fi
            fi
            ;;

        priority|prio|dynamic-prio)
            local local_dryrun="$dryrun"
            local target="$1"
            local new_priority="$2"
            local force=0
            [[ "${3:-}" == "--force" || "${3:-}" == "-f" ]] && force=1
            [[ "${3:-}" == "--dryrun" || "${3:-}" == "-n" ]] && local_dryrun=1
            [[ "${4:-}" == "--dryrun" || "${4:-}" == "-n" ]] && local_dryrun=1
            [[ "${4:-}" == "--force" || "${4:-}" == "-f" ]] && force=1

            if [[ -z "$target" || -z "$new_priority" ]]; then
                echo "Usage: queue priority <qid-or-exact-job-name> <priority> [--force]" >&2
                echo "Exact job name updates all jobs with that exact name." >&2
                return 2
            fi

            [[ "$new_priority" =~ ^-?[0-9]+$ ]] || { echo "queue priority: priority must be an integer" >&2; return 2; }

            local matches=()
            local f
            while IFS= read -r f; do
                matches+=( "$f" )
            done < <(_queue_find_jobs "$target")

            [[ "${#matches[@]}" -eq 0 ]] && { echo "queue priority: no such QID or exact job name: $target" >&2; return 1; }

            local exact_name_count
            exact_name_count="$(_queue_exact_name_count "$target" "${matches[@]}")"
            if [[ "$exact_name_count" -eq 0 && "${#matches[@]}" -gt 1 && "$force" -ne 1 ]]; then
                echo "queue priority: ambiguous QID prefix: $target" >&2
                echo "matches:" >&2
                _queue_print_matches "${matches[@]}"
                echo "Use a fuller QID or --force." >&2
                return 2
            fi

            local changed=0
            for f in "${matches[@]}"; do
                local id
                id="$(basename "$f" .job)"
                if [[ "$local_dryrun" -eq 1 ]]; then
                    echo "DRYRUN: would set priority for $id to $new_priority"
                else
                    if grep -q '^PRIORITY=' "$f"; then
                        sed -i "s/^PRIORITY=.*/PRIORITY=$new_priority/" "$f"
                    else
                        sed -i "/^JOB_NAME=/a PRIORITY=$new_priority" "$f"
                    fi
                    echo "Priority for $id set to $new_priority"
                fi
                changed=$((changed + 1))
            done
            echo "Updated $changed job(s)."
            ;;


        cancel|kill)
            local local_dryrun="$dryrun"
            local target="$1"
            shift || true
            local sig="TERM"
            local force=0

            [[ "$cmd" == "kill" ]] && sig="KILL"

            while [[ "$#" -gt 0 ]]; do
                case "$1" in
                    --signal|-s) sig="$2"; shift 2 ;;
                    --dryrun|-n) local_dryrun=1; shift ;;
                    --force|-f) force=1; shift ;;
                    *) echo "queue $cmd: unexpected argument: $1" >&2; return 2 ;;
                esac
            done

            [[ -z "$target" ]] && { echo "Usage: queue $cmd <qid-or-exact-job-name> [--signal SIG] [--dryrun]" >&2; return 2; }

            local matches=()
            local f
            while IFS= read -r f; do
                matches+=( "$f" )
            done < <(_queue_find_jobs "$target")

            [[ "${#matches[@]}" -eq 0 ]] && { echo "queue $cmd: no matching job: $target" >&2; return 1; }

            local exact_name_count
            exact_name_count="$(_queue_exact_name_count "$target" "${matches[@]}")"
            if [[ "${#matches[@]}" -gt 1 && "$exact_name_count" -eq 0 && "$force" -ne 1 ]]; then
                echo "queue $cmd: ambiguous QID prefix: $target" >&2
                _queue_print_matches "${matches[@]}"
                echo "Use a fuller QID or --force." >&2
                return 2
            fi

            local moved=0
            for f in "${matches[@]}"; do
                local id state dest run_pid run_pgid name self_pgid signal_target unit systemd_targeted
                id="$(basename "$f" .job)"
                state="$(_queue_job_file_state "$f")"
                name="$(_queue_job_name "$f")"
                dest="$root/cancelled/$id.job"
                run_pid="$(grep '^RUN_PID=' "$f" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
                run_pgid="$(grep '^RUN_PGID=' "$f" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
                self_pgid="$(ps -o pgid= -p $$ 2>/dev/null | tr -d '[:space:]')"
                unit="$(_queue_job_systemd_unit "$f" 2>/dev/null || true)"
                systemd_targeted=0

                if [[ "$state" == "cancelled" ]]; then
                    echo "Already cancelled $id"
                    continue
                fi

                signal_target=""
                if [[ "$state" == "running" ]]; then
                    if [[ -n "$run_pgid" && "$run_pgid" != "$self_pgid" && "$run_pgid" != "0" ]]; then
                        signal_target="-$run_pgid"
                    elif [[ -n "$run_pid" ]]; then
                        signal_target="$run_pid"
                    fi
                fi

                if [[ "$local_dryrun" -eq 1 ]]; then
                    if [[ "$state" == "running" ]]; then
                        if [[ -n "$unit" ]]; then
                            echo "DRYRUN: would signal $sig to systemd unit $unit for job $id ($name), then move running -> cancelled"
                        else
                            echo "DRYRUN: would signal $sig to job $id ($name), target=${signal_target:-none}, RUN_PID=$run_pid RUN_PGID=$run_pgid, then move running -> cancelled"
                        fi
                    else
                        echo "DRYRUN: would move $id ($name) from $state -> cancelled without signalling"
                    fi
                    moved=$((moved + 1))
                    continue
                fi

                if [[ "$state" == "running" ]]; then
                    if [[ -n "$unit" ]]; then
                        _queue_systemd_kill_unit_tree "$unit" "$sig" || true
                        systemd_targeted=1
                    fi

                    if [[ "$systemd_targeted" -eq 1 ]]; then
                        # For systemd jobs, RUN_PID is the systemd-run client and RUN_PGID can
                        # be the queue worker's process group. Do not PGID-fallback by default.
                        :
                    elif [[ -n "$signal_target" ]]; then
                        echo "Fallback: sending -$sig to $signal_target for $id ($name)"
                        kill "-$sig" "$signal_target" 2>/dev/null || true
                    else
                        echo "queue $cmd: running job $id has no safe SYSTEMD_UNIT/RUN_PID/RUN_PGID target; moving record only" >&2
                    fi
                fi

                {
                    echo "CANCELLED_AT=$(printf '%q' "$(date -Is)")"
                    echo "CANCELLED_FROM=$(printf '%q' "$state")"
                    echo "CANCEL_SIGNAL=$(printf '%q' "$sig")"
                    [[ -n "$unit" ]] && echo "CANCEL_SYSTEMD_UNIT=$(printf '%q' "$unit")"
                } >> "$f"

                mv -f "$f" "$dest"
                _queue_job_stream_temp_cleanup "$id"
                _queue_log_event "cancelled" "$id" "$name" "cancelled" "from=$state signal=$sig pid=$run_pid pgid=$run_pgid unit=$unit hook=none"
                echo "Moved $id from $state -> cancelled"
                echo "ON_FAILURE was not run; cancellation is operator action, not program failure."
                moved=$((moved + 1))
            done

            [[ "$moved" -gt 0 ]]
            ;;


        pause|hold|delete|del|rm|remove)
            local local_dryrun="$dryrun"
            local target="$1"
            local force=0
            [[ "${2:-}" == "--force" || "${2:-}" == "-f" ]] && force=1
            [[ "${2:-}" == "--dryrun" || "${2:-}" == "-n" ]] && local_dryrun=1
            [[ "${3:-}" == "--force" || "${3:-}" == "-f" ]] && force=1
            [[ "${3:-}" == "--dryrun" || "${3:-}" == "-n" ]] && local_dryrun=1

            [[ -z "$target" ]] && { echo "Usage: queue $cmd <qid-or-exact-job-name> [--force]" >&2; return 2; }

            local matches=()
            local f
            while IFS= read -r f; do
                matches+=( "$f" )
            done < <(_queue_find_jobs "$target")

            [[ "${#matches[@]}" -eq 0 ]] && { echo "queue $cmd: no matching job: $target" >&2; return 1; }

            local exact_name_count
            exact_name_count="$(_queue_exact_name_count "$target" "${matches[@]}")"
            if [[ "${#matches[@]}" -gt 1 && "$exact_name_count" -eq 0 && "$force" -ne 1 ]]; then
                echo "queue $cmd: ambiguous QID prefix: $target" >&2
                echo "matches:" >&2
                _queue_print_matches "${matches[@]}"
                echo "Use a fuller QID or --force." >&2
                return 2
            fi

            local dest_state
            case "$cmd" in
                pause|hold) dest_state="paused" ;;
                *) dest_state="deleted" ;;
            esac

            local moved=0
            for f in "${matches[@]}"; do
                local id state dest
                id="$(basename "$f" .job)"
                state="$(basename "$(dirname "$f")")"
                dest="$root/$dest_state/$id.job"

                if [[ "$state" == "$dest_state" ]]; then
                    echo "Already $dest_state $id"
                    continue
                fi

                if [[ "$state" == "running" && "$force" -ne 1 ]]; then
                    echo "queue $cmd: refusing running job $id without --force" >&2
                    continue
                fi

                if [[ "$cmd" == pause || "$cmd" == hold ]]; then
                    if [[ "$state" != "pending" && "$force" -ne 1 ]]; then
                        echo "queue pause: not pausing $id in state $state without --force" >&2
                        continue
                    fi
                    if [[ "$local_dryrun" -ne 1 ]]; then
                        {
                            echo "PAUSED_AT=$(printf '%q' "$(date -Is)")"
                            echo "PAUSED_FROM=$(printf '%q' "$state")"
                        } >> "$f"
                    fi
                else
                    if [[ "$local_dryrun" -ne 1 ]]; then
                        {
                            echo "DELETED_AT=$(printf '%q' "$(date -Is)")"
                            echo "DELETED_FROM=$(printf '%q' "$state")"
                        } >> "$f"
                    fi
                fi

                if [[ "$local_dryrun" -eq 1 ]]; then
                    echo "DRYRUN: would move $id from $state -> $dest_state"
                    [[ "$state" == "running" ]] && echo "DRYRUN WARNING: running process would not be killed; only queue record would move."
                else
                    mv -f "$f" "$dest"
                    _queue_log_event "$dest_state" "$id" "$(_queue_job_name "$dest")" "$dest_state" "from=$state"
                    echo "Moved $id from $state -> $dest_state"
                    [[ "$state" == "running" ]] && echo "WARNING: moving running queue record does not kill the already-started process."
                fi
                moved=$((moved + 1))
            done

            [[ "$moved" -gt 0 ]]
            ;;

        unpause|resume|release)
            local local_dryrun="$dryrun"
            local target="$1"
            [[ "${1:-}" == "--dryrun" || "${1:-}" == "-n" ]] && { local_dryrun=1; shift; target="${1:-}"; }
            [[ "${2:-}" == "--dryrun" || "${2:-}" == "-n" ]] && local_dryrun=1
            [[ -z "$target" ]] && { echo "Usage: queue unpause <qid-or-exact-job-name> [--dryrun]" >&2; return 2; }

            local matches=()
            local f id name
            for f in "$root/paused"/*.job; do
                [[ -e "$f" ]] || continue
                id="$(basename "$f" .job)"
                name="$(_queue_job_name "$f")"
                if [[ "$id" == "$target" || "$name" == "$target" || "$id" == "$target"* ]]; then
                    matches+=( "$f" )
                fi
            done

            [[ "${#matches[@]}" -eq 0 ]] && { echo "queue unpause: no matching paused job: $target" >&2; return 1; }

            local exact_name_count
            exact_name_count="$(_queue_exact_name_count "$target" "${matches[@]}")"
            if [[ "${#matches[@]}" -gt 1 && "$exact_name_count" -eq 0 ]]; then
                echo "queue unpause: ambiguous QID prefix: $target" >&2
                _queue_print_matches "${matches[@]}"
                return 2
            fi

            for f in "${matches[@]}"; do
                id="$(basename "$f" .job)"
                if [[ "$local_dryrun" -eq 1 ]]; then
                    echo "DRYRUN: would unpause $id -> pending"
                else
                    {
                        echo "UNPAUSED_AT=$(printf '%q' "$(date -Is)")"
                        echo "UNPAUSED_TO=pending"
                    } >> "$f"
                    mv -f "$f" "$root/pending/$id.job"
                    _queue_log_event "unpaused" "$id" "$(_queue_job_name "$root/pending/$id.job")" "pending" "from=paused"
                    echo "Unpaused $id -> pending"
                fi
            done
            ;;

        undelete|undel|restore)
            local local_dryrun="$dryrun"
            local target="$1"
            shift || true
            local restore_state="pending"
            local force=0

            [[ -z "$target" ]] && { echo "Usage: queue undelete <qid-or-exact-job-name> [pending|done|failed] [--force]" >&2; return 2; }

            while [[ "$#" -gt 0 ]]; do
                case "$1" in
                    --force|-f) force=1; shift ;;
                    --dryrun|-n) local_dryrun=1; shift ;;
                    pending|done|failed|cancelled) restore_state="$1"; shift ;;
                    *) echo "queue undelete: unexpected argument: $1" >&2; return 2 ;;
                esac
            done

            local matches=()
            local f id name
            for f in "$root/deleted"/*.job; do
                [[ -e "$f" ]] || continue
                id="$(basename "$f" .job)"
                name="$(_queue_job_name "$f")"
                if [[ "$id" == "$target" || "$name" == "$target" || "$id" == "$target"* ]]; then
                    matches+=( "$f" )
                fi
            done

            if [[ "${#matches[@]}" -eq 0 ]]; then
                _queue_restore_print_non_deleted_matches "$target" || echo "queue undelete: no matching deleted job: $target" >&2
                return 1
            fi

            local exact_name_count
            exact_name_count="$(_queue_exact_name_count "$target" "${matches[@]}")"
            if [[ "${#matches[@]}" -gt 1 && "$exact_name_count" -eq 0 && "$force" -ne 1 ]]; then
                echo "queue undelete: ambiguous QID prefix: $target" >&2
                _queue_print_matches "${matches[@]}"
                echo "Use a fuller QID or --force." >&2
                return 2
            fi

            for f in "${matches[@]}"; do
                id="$(basename "$f" .job)"
                if [[ "$local_dryrun" -eq 1 ]]; then
                    echo "DRYRUN: would restore $id to $restore_state"
                else
                    {
                        echo "UNDELETED_AT=$(printf '%q' "$(date -Is)")"
                        echo "UNDELETED_TO=$(printf '%q' "$restore_state")"
                    } >> "$f"
                    mv -f "$f" "$root/$restore_state/$id.job"
                    _queue_log_event "undeleted" "$id" "$(_queue_job_name "$root/$restore_state/$id.job")" "$restore_state" "from=deleted"
                    echo "Restored $id to $restore_state"
                fi
            done
            ;;


        resubmit|retry)
            local local_dryrun="$dryrun"
            local target="$1"
            shift || true
            local force=0
            local note=""

            if [[ -z "$target" ]]; then
                echo "Usage: queue resubmit <qid-or-exact-job-name> [--force] [--dryrun] [--note TEXT]" >&2
                echo "Resubmit clones failed job(s) into pending with new QID(s), preserving the failed originals." >&2
                return 2
            fi

            while [[ "$#" -gt 0 ]]; do
                case "$1" in
                    --force|-f) force=1; shift ;;
                    --dryrun|-n) local_dryrun=1; shift ;;
                    --note) note="$2"; shift 2 ;;
                    *) echo "queue resubmit: unexpected argument: $1" >&2; return 2 ;;
                esac
            done

            local all_matches=()
            local matches=()
            local f state
            while IFS= read -r f; do
                all_matches+=( "$f" )
                state="$(basename "$(dirname "$f")")"
                [[ "$state" == "failed" || "$state" == "interrupted" ]] && matches+=( "$f" )
            done < <(_queue_find_jobs "$target")

            if [[ "${#all_matches[@]}" -eq 0 ]]; then
                echo "queue resubmit: no matching QID or exact job name: $target" >&2
                return 1
            fi

            if [[ "${#matches[@]}" -eq 0 ]]; then
                echo "queue resubmit: matching job(s) found, but none are in failed or interrupted state:" >&2
                _queue_print_matches "${all_matches[@]}"
                return 1
            fi

            local exact_name_count
            exact_name_count="$(_queue_exact_name_count "$target" "${matches[@]}")"

            if [[ "${#matches[@]}" -gt 1 && "$exact_name_count" -eq 0 && "$force" -ne 1 ]]; then
                echo "queue resubmit: ambiguous QID prefix: $target" >&2
                _queue_print_matches "${matches[@]}"
                echo "Use a fuller QID or --force." >&2
                return 2
            fi

            local count=0
            local src_id new_id name pri cmdline
            for f in "${matches[@]}"; do
                src_id="$(basename "$f" .job)"
                name="$(_queue_job_name "$f")"
                pri="$(_queue_job_pri "$f")"
                cmdline="$(grep '^COMMAND=' "$f" | sed 's/^COMMAND=( //; s/ )$//')"
                new_id="$(_queue_id)"

                if [[ "$local_dryrun" -eq 1 ]]; then
                    echo "DRYRUN: would resubmit failed/interrupted job:"
                    echo "  from:     $src_id"
                    echo "  new id:   $new_id"
                    echo "  name:     $name"
                    echo "  priority: $pri"
                    echo "  command:  $cmdline"
                else
                    _queue_clone_job_to_pending "$f" "$new_id" "$note"
                    _queue_log_event "resubmitted" "$new_id" "$name" "pending" "from=$src_id"
                    echo "Resubmitted $src_id -> $new_id ($name)"
                fi

                count=$((count + 1))
            done

            if [[ "$local_dryrun" -eq 1 ]]; then
                echo "DRYRUN: would resubmit $count failed/interrupted job(s)."
            else
                echo "Resubmitted $count failed/interrupted job(s)."
            fi
            ;;




        watch)
            local interval=1
            while [[ "$#" -gt 0 ]]; do
                case "$1" in
                    --interval|-i) interval="${2:-1}"; shift 2 ;;
                    *) shift ;;
                esac
            done
            [[ "$interval" =~ ^[0-9]+$ ]] || interval=1
            while true; do
                clear
                echo "queuebash watch - $(date -Is)"
                echo
                queue stats
                echo
                echo "=== running ==="
                queue list --state running
                echo
                echo "=== pending top ==="
                queue list --state pending | head -20
                echo
                echo "Ctrl+C to exit. interval=${interval}s"
                sleep "$interval"
            done
            ;;


        workers|worker|jobs)
            echo "=== queuebash worker processes ==="
            local any=0
            local pf pid
            for pf in "$root/workers"/*.pid; do
                [[ -e "$pf" ]] || continue
                pid="$(cat "$pf" 2>/dev/null)"
                if [[ -n "$pid" && -d "/proc/$pid" ]]; then
                    any=1
                    ps -o pid,ppid,pgid,stat,etime,pcpu,pmem,comm,args -p "$pid" 2>/dev/null || true
                else
                    rm -f "$pf"
                fi
            done
            [[ "$any" -eq 0 ]] && echo "No live detached workers recorded."
            ;;


        run|start)
            local local_dryrun="$dryrun"
            local detach=0
            [[ "$cmd" == "start" ]] && detach=1
            local workers=1
            while [[ "$#" -gt 0 ]]; do
                case "${1:-}" in
                    --workers|-w)
                        workers="${2:-}"
                        shift 2
                        ;;
                    --detach|-d|--background)
                        detach=1
                        shift
                        ;;
                    --dryrun|-n)
                        local_dryrun=1
                        shift
                        ;;
                    *)
                        echo "queue $cmd: unexpected argument: $1" >&2
                        return 2
                        ;;
                esac
            done

            if ! [[ "$workers" =~ ^[0-9]+$ ]] || [[ "$workers" -lt 1 ]]; then
                echo "queue run: workers must be a positive integer" >&2
                return 2
            fi

            if [[ "$local_dryrun" -eq 1 ]]; then
                echo "DRYRUN: would run queue with $workers worker(s)"
                local next_job
                next_job="$(_queue_next_job)"
                if [[ -n "$next_job" ]]; then
                    echo "DRYRUN: next job would be $(basename "$next_job" .job) ($(_queue_job_name "$next_job"))"
                else
                    echo "DRYRUN: no pending jobs"
                fi
                return 0
            fi

            if [[ "$detach" -eq 1 ]]; then
                echo "Starting queue with $workers detached worker(s)"
                local i wp
                for ((i=1; i<=workers; i++)); do
                    (_queue_worker "$i") &
                    wp="$!"
                    echo "$wp" > "$root/workers/worker_${wp}.pid"
                    echo "  worker $i pid=$wp"
                done
                _queue_log_event "workers_started" "" "" "workers" "workers=$workers detached=1"
                echo "Detached workers started. Use: queue workers"
                return 0
            fi

            echo "Running queue with $workers worker(s) in foreground"
            local i
            for ((i=1; i<=workers; i++)); do
                (_queue_worker "$i") &
            done
            wait
            ;;


        clean-logs|cleanlogs|log-clean|logs-clean)
            _queue_clean_logs "$@"
            ;;


        clear)
            local what="${1:-}"
            local local_dryrun="$dryrun"
            [[ "${2:-}" == "--dryrun" || "${2:-}" == "-n" ]] && local_dryrun=1
            case "$what" in
                done|failed|paused|interrupted|cancelled|deleted)
                    if [[ "$local_dryrun" -eq 1 ]]; then
                        echo "DRYRUN: would clear $what jobs:"
                        find "$root/$what" -maxdepth 1 -type f -name '*.job' -printf '  %f\n' 2>/dev/null
                    else
                        rm -f "$root/$what"/*.job
                        echo "Cleared $what jobs"
                    fi
                    ;;
                all)
                    if [[ "$local_dryrun" -eq 1 ]]; then
                        echo "DRYRUN: would clear all jobs and logs:"
                        find "$root"/{pending,running,paused,done,failed,deleted,logs} -maxdepth 1 -type f -printf '  %p\n' 2>/dev/null
                    else
                        rm -f "$root"/{pending,running,paused,done,failed,cancelled,deleted}/*.job
                        rm -f "$root/logs"/*.log
                        echo "Cleared all jobs and logs"
                    fi
                    ;;
                *) echo "Usage: queue clear done|failed|paused|interrupted|cancelled|deleted|all [--dryrun]" >&2; return 2 ;;
            esac
            ;;

        *)
            echo "Unknown queue command: $cmd" >&2
            _queue_help
            return 2
            ;;
    esac
}

_queue_worker_external_move_state() {
    local id="$1"
    local root="$(_queue_root)"
    local state
    for state in cancelled deleted interrupted paused done failed pending; do
        if [[ -f "$root/$state/$id.job" ]]; then
            printf '%s\n' "$state"
            return 0
        fi
    done
    printf '%s\n' "missing"
}

_queue_worker() {
    _queue_init

    local worker_id="$1"
    local root="$(_queue_root)"

    # Enable simple readline completion inside the queue manager REPL.
    # This temporarily binds TAB while queuemgr is active.
    bind -x '"\t": _queuemgr_repl_complete' 2>/dev/null || true

    while true; do
        local job
        job="$(_queue_next_job)"
        [[ -n "$job" ]] || break

        local id
        id="$(basename "$job" .job)"

        local running="$root/running/$id.job"
        local done="$root/done/$id.job"
        local failed="$root/failed/$id.job"
        local log="$root/logs/$id.log"

        if ! mv "$job" "$running" 2>/dev/null; then
            continue
        fi

        if ! _queue_class_claim_job "$running" "$id"; then
            mv "$running" "$root/pending/$id.job" 2>/dev/null || true
            _queue_log_event "class_blocked" "$id" "$(_queue_job_name "$root/pending/$id.job" 2>/dev/null || echo "-")" "pending" "worker=$worker_id"
            continue
        fi

        echo "[worker $worker_id] running $id"
        _queue_log_event "started" "$id" "$(_queue_job_name "$running")" "running" "worker=$worker_id"

        (
            source "$running"
            cd "$PWD_AT_SUBMIT" || exit 98
            _queue_source_env_drop_if_requested "$running"
            _queue_export_job_ipc_env "$JOB_ID"
            export -f queue_output 2>/dev/null || true
            stream_public_fifo="$(_queue_create_stream_fifo_for_job "$JOB_ID" 2>/dev/null || true)"

            {
                echo "=== queue job $JOB_ID : $JOB_NAME ==="
                echo "started: $(date -Is)"
                echo "pwd: $PWD"
                echo "output_env: ${QUEUEBASH_OUTPUT_ENV:-}"
                echo "helper_dir: ${QUEUEBASH_HELPER_DIR:-}"
                [[ -n "${QUEUEBASH_INHERITED_ENV_FROM:-}" ]] && echo "inherited_env_from: ${QUEUEBASH_INHERITED_ENV_FROM:-}"
                [[ -n "${QUEUEBASH_INHERITED_ENV_KEYS:-}" ]] && echo "inherited_env_keys: ${QUEUEBASH_INHERITED_ENV_KEYS:-}"
                auto_required_file_keys="$(_queue_auto_required_file_keys_from_env | xargs echo 2>/dev/null || true)"
                [[ -n "$auto_required_file_keys" ]] && echo "auto_required_files: $auto_required_file_keys"
                [[ -n "${stream_public_fifo:-}" ]] && echo "stream_fifo: $stream_public_fifo"
                printf "command:"
                printf " %q" "${COMMAND[@]}"
                echo
                echo

                runner_requested="${RUNNER:-${QUEUEBASH_RUNNER:-auto}}"
                runner_planned="$(_queue_runner_for_job "$runner_requested" "${CPU_LIMIT:-}" "${MEM_LIMIT:-}" || true)"
                limit_status="$(_queue_limit_status_text "${CPU_LIMIT:-}" "${MEM_LIMIT:-}")"
                [[ "$runner_planned" == "systemd" ]] && limit_status="systemd-run-user-service-pipe"
                if [[ -n "${CPU_LIMIT:-}" || -n "${MEM_LIMIT:-}" ]]; then
                    echo "resource_limit_request: cpu=${CPU_LIMIT:-} mem=${MEM_LIMIT:-} runner=${runner_requested:-auto} planned=${runner_planned:-} status=$limit_status"
                    if [[ "$limit_status" != "systemd-run-user-service-pipe" ]]; then
                        echo "WARNING: resource limits were requested but are NOT enforced in this shell/session."
                    fi
                fi

                _queue_preflight_auto_required_files
                preflight_rc="$?"
                if [[ "$preflight_rc" -ne 0 ]]; then
                    echo
                    echo "PRE_FLIGHT_REQUIRE_FILE_FAILED: exit_code=$preflight_rc"
                    exit "$preflight_rc"
                fi

                runner_used="$(_queue_runner_for_job "${RUNNER:-${QUEUEBASH_RUNNER:-auto}}" "${CPU_LIMIT:-}" "${MEM_LIMIT:-}")"
                {
                    printf 'RUNNER_USED=%q\n' "$runner_used"
                } >> "$running"
                mapfile -d '' payload_cmd < <(_queue_build_payload_command "${CPU_LIMIT:-}" "${MEM_LIMIT:-}" "${PWD_AT_SUBMIT:-$PWD}" "$runner_used" "${COMMAND[@]}")
                printf "launch_argv:"
                printf " %q" "${payload_cmd[@]}"
                printf "\n"
                max_log_bytes="$(_queue_job_log_max_bytes "$running")"
                log_overflow_policy="$(_queue_job_log_policy "$running")"

                stream_logger_stdout_pid=""
                stream_logger_stderr_pid=""
                stream_stdout_fifo=""
                stream_stderr_fifo=""
                use_stream_logger=0
                if [[ "${ALLOW_LARGE_LOG:-0}" != "1" && "$log_overflow_policy" != "allow" && "$log_overflow_policy" != "kill" && "$max_log_bytes" =~ ^[0-9]+$ && "$max_log_bytes" -gt 0 ]]; then
                    stream_stdout_fifo="$root/logs/.${JOB_ID}.stdout.fifo"
                    stream_stderr_fifo="$root/logs/.${JOB_ID}.stderr.fifo"
                    rm -f -- "$stream_stdout_fifo" "$stream_stderr_fifo"
                    mkfifo "$stream_stdout_fifo" "$stream_stderr_fifo"
                    use_stream_logger=1
                    _queue_stream_logger "$JOB_ID" "$running" "$log" "stdout" "$max_log_bytes" < "$stream_stdout_fifo" &
                    stream_logger_stdout_pid="$!"
                    _queue_stream_logger "$JOB_ID" "$running" "$log" "stderr" "$max_log_bytes" < "$stream_stderr_fifo" &
                    stream_logger_stderr_pid="$!"
                    "${payload_cmd[@]}" > "$stream_stdout_fifo" 2> "$stream_stderr_fifo" &
                else
                    "${payload_cmd[@]}" &
                fi
                cmd_pid="$!"

                cmd_pgid="$(ps -o pgid= -p "$cmd_pid" 2>/dev/null | tr -d '[:space:]')"
                {
                    printf 'RUN_PID=%q\n' "$cmd_pid"
                    printf 'RUN_PGID=%q\n' "$cmd_pgid"
                    printf 'RUN_STARTED_AT=%q\n' "$(date -Is)"
                    [[ -n "${QUEUEBASH_INHERITED_ENV_FROM:-}" ]] && printf 'QUEUEBASH_INHERITED_ENV_FROM=%q\n' "$QUEUEBASH_INHERITED_ENV_FROM"
                    [[ -n "${QUEUEBASH_INHERITED_ENV_KEYS:-}" ]] && printf 'QUEUEBASH_INHERITED_ENV_KEYS=%q\n' "$QUEUEBASH_INHERITED_ENV_KEYS"
                } >> "$running"

                _queue_log_worker_record "$use_stream_logger" "$log" "run_pid: $cmd_pid" "run_pgid: $cmd_pgid"
                _queue_log_event "pid_recorded" "$JOB_ID" "$JOB_NAME" "running" "pid=$cmd_pid pgid=$cmd_pgid"

                max_log_bytes="$(_queue_job_log_max_bytes "$running")"
                log_overflow_policy="$(_queue_job_log_policy "$running")"
                if [[ "${ALLOW_LARGE_LOG:-0}" != "1" && "$log_overflow_policy" == "kill" && "$max_log_bytes" =~ ^[0-9]+$ && "$max_log_bytes" -gt 0 ]]; then
                    _queue_log_watchdog "$JOB_ID" "$running" "$log" "$cmd_pid" "$max_log_bytes" &
                    log_watchdog_pid="$!"
                else
                    log_watchdog_pid=""
                fi

                wait "$cmd_pid"
                rc="$?"

                # The payload is gone, but stream readers may still be appending.
                # Wait for them before writing footer or other post-run records.
                _queue_wait_stream_loggers "${stream_logger_stdout_pid:-}" "${stream_logger_stderr_pid:-}"

                [[ -n "${stream_stdout_fifo:-}" ]] && rm -f -- "$stream_stdout_fifo" 2>/dev/null || true
                [[ -n "${stream_stderr_fifo:-}" ]] && rm -f -- "$stream_stderr_fifo" 2>/dev/null || true
                if [[ -n "${log_watchdog_pid:-}" ]]; then
                    kill "$log_watchdog_pid" >/dev/null 2>&1 || true
                    wait "$log_watchdog_pid" >/dev/null 2>&1 || true
                fi
                _queue_record_systemd_unit_if_seen "$running" "$log"

                log_bytes_now="$(_queue_log_size_bytes "$log")"
                max_log_bytes="$(_queue_job_log_max_bytes "$running")"
                if [[ "$max_log_bytes" -gt 0 && "$log_bytes_now" -gt "$max_log_bytes" ]]; then
                    _queue_log_worker_record "$use_stream_logger" "$log" "" "LOG_OVERFLOW_WARNING: log size ${log_bytes_now} exceeded cap ${max_log_bytes}"
                    _queue_log_event "log_overflow_warning" "$JOB_ID" "$JOB_NAME" "running" "bytes=$log_bytes_now cap=$max_log_bytes"
                    if [[ "$log_overflow_policy" == "kill" ]] && grep -q '^LOG_OVERFLOW=1$' "$running" 2>/dev/null; then
                        rc=97
                    fi
                fi

                _queue_log_worker_record "$use_stream_logger" "$log" "" "finished: $(date -Is)" "exit_code: $rc"

                exit "$rc"
            } > "$log" 2>&1
        )

        local rc="$?"

        if [[ "$rc" -eq 0 ]]; then
            if [[ -f "$running" ]]; then
                _queue_append_summary_to_job "$running" 0 "$log"
                mv "$running" "$done"
                _queue_job_stream_temp_cleanup "$id"
                _queue_log_event "done" "$id" "$(_queue_job_name "$done")" "done" "exit_code=0"
                echo "[worker $worker_id] done $id"

                if _queue_job_has_array "$done" ON_SUCCESS; then
                    (
                        source "$done"
                        cd "$PWD_AT_SUBMIT" || exit 98
                        {
                            echo
                            echo "=== on-success hook for $JOB_ID ==="
                            echo "started: $(date -Is)"
                            printf "hook:"
                            printf " %q" "${ON_SUCCESS[@]}"
                            echo
                            "${ON_SUCCESS[@]}"
                            hook_rc="$?"
                            echo "hook_exit_code: $hook_rc"
                            echo "finished: $(date -Is)"
                        } >> "$log" 2>&1
                    )
                fi
                _queue_maybe_gzip_completed_job_log "$id" "$done"
            else
                external_state="$(_queue_worker_external_move_state "$id")"
                if [[ "$external_state" == "cancelled" ]]; then
                    _queue_log_event "worker_observed_cancelled" "$id" "$JOB_NAME" "cancelled" "worker=$worker_id rc=0"
                    echo "[worker $worker_id] cancelled $id (operator moved record while worker was finishing)"
                else
                    echo "[worker $worker_id] done $id but queue record was moved externally to $external_state; no success/failure hook run by worker"
                fi
            fi
        else
            if [[ -f "$running" ]]; then
                if _queue_should_retry_failed_job "$running"; then
                    retry_done_old="$(grep '^RETRIES_DONE=' "$running" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
                    retry_done_old="${retry_done_old:-0}"
                    retry_done_new=$((retry_done_old + 1))
                    retry_backoff="$(grep '^RETRY_BACKOFF=' "$running" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
                    retry_backoff="${retry_backoff:-0}"
                    [[ "$retry_backoff" =~ ^[0-9]+$ ]] || retry_backoff=0
                    not_before=$(( $(_queue_epoch_now) + retry_backoff ))
                    if _queue_job_has_array "$running" ON_RETRY_FAILURE; then
                        (
                            source "$running"
                            cd "$PWD_AT_SUBMIT" || exit 98
                            {
                                echo
                                echo "=== on-retry-failure hook for $JOB_ID ==="
                                echo "started: $(date -Is)"
                                printf "hook:"
                                printf " %q" "${ON_RETRY_FAILURE[@]}"
                                echo
                                "${ON_RETRY_FAILURE[@]}"
                                hook_rc="$?"
                                echo "hook_exit_code: $hook_rc"
                                echo "finished: $(date -Is)"
                            } >> "$log" 2>&1
                        )
                    fi

                    retry_id="$(_queue_id)"
                    _queue_clone_retry_to_pending "$running" "$retry_id" "$retry_done_new" "$not_before"
                    _queue_append_summary_to_job "$running" "$rc" "$log"
                    mv "$running" "$failed"
                    _queue_job_stream_temp_cleanup "$id"
                    _queue_log_event "retry_scheduled" "$retry_id" "$(_queue_job_name "$root/pending/$retry_id.job")" "pending" "from=$id attempt=$retry_done_new backoff=$retry_backoff exit_code=$rc"
                    _queue_log_event "failed_retrying" "$id" "$(_queue_job_name "$failed")" "failed" "exit_code=$rc retry=$retry_id"
                    echo "[worker $worker_id] failed $id rc=$rc; scheduled retry $retry_id attempt $retry_done_new after ${retry_backoff}s"
                    _queue_maybe_gzip_completed_job_log "$id" "$failed"
                    continue
                fi

                _queue_append_summary_to_job "$running" "$rc" "$log"
                mv "$running" "$failed"
                _queue_job_stream_temp_cleanup "$id"
                _queue_log_event "failed" "$id" "$(_queue_job_name "$failed")" "failed" "exit_code=$rc"
                echo "[worker $worker_id] failed $id rc=$rc"

                if _queue_job_has_array "$failed" ON_FAILURE; then
                    (
                        source "$failed"
                        cd "$PWD_AT_SUBMIT" || exit 98
                        {
                            echo
                            echo "=== on-failure hook for $JOB_ID ==="
                            echo "started: $(date -Is)"
                            printf "hook:"
                            printf " %q" "${ON_FAILURE[@]}"
                            echo
                            "${ON_FAILURE[@]}"
                            hook_rc="$?"
                            echo "hook_exit_code: $hook_rc"
                            echo "finished: $(date -Is)"
                        } >> "$log" 2>&1
                    )
                fi
                _queue_maybe_gzip_completed_job_log "$id" "$failed"
            else
                external_state="$(_queue_worker_external_move_state "$id")"
                if [[ "$external_state" == "cancelled" ]]; then
                    _queue_log_event "worker_observed_cancelled" "$id" "$JOB_NAME" "cancelled" "worker=$worker_id rc=$rc"
                    echo "[worker $worker_id] cancelled $id (operator cancellation observed; payload rc=$rc)"
                else
                    echo "[worker $worker_id] failed $id rc=$rc but queue record was moved externally to $external_state; no failure hook run by worker"
                fi
            fi
        fi

        # Worker-side compression is intentionally targeted at the job just completed.
        # Bulk scanning/compression is reserved for explicit: queue compress-logs.
    done
}

_queuemgr_print_commands() {
    cat <<'EOF'
Commands:
  Run/workers                 Inspect                     Priority/state
  r / r4       run 1/4        s <id|name>   show          p <id|name> <pri>
  rd / rd4     dryrun 1/4     t <id|name>   tail          pause <id|name>
                              pid <id|name> pids
                              m <id|name>   metrics
                              ex <id|name>  explain
                              dep <id|name> deps          pd <id|name>
                                                          unp / unpd <id|name>

  Hooks                       Cancel/delete               Resubmit/recovery
  os <id|name>  show hooks    c <id|name>   cancel        rs <id|name>
  ok <id|name> -- <cmd>       kd <id|name>  kill          rsd <id|name>
  fail <id|name> -- <cmd>     d / dd <id|name>            h     health              hd      health --deep
                                                          wait  waiting deps
                                                          sched scheduled
                              df <id|name>                hf    health --fix
                              u / ud / uf <id|name>

  Clear/history               Filters/view                General
  cd      clear done          f <text>      text filter    help/?  show help
  cf      clear failed        n <text>      name filter    q       quit
  ci      clear interrupted   st <state>    state filter
  cc      clear cancelled     a             clear filters
  ccd     dryrun clear canc.  stat          stats
  cdel    clear deleted       gz      compress logs      clog    clean logs       ev [N]        recent events
EOF
}


queuemgr() {
    _queue_init

    local filter_text=""
    local filter_name=""
    local filter_state="all"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --filter|-f) filter_text="$2"; shift 2 ;;
            --name|-n) filter_name="$2"; shift 2 ;;
            --state|-s) filter_state="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    while true; do
        clear
        echo "queue manager: $(_queue_root)"
        echo "filters: state=$filter_state name=$filter_name filter=$filter_text"
        echo

        local args=()
        [[ -n "$filter_state" ]] && args+=( --state "$filter_state" )
        [[ -n "$filter_name" ]] && args+=( --name "$filter_name" )
        [[ -n "$filter_text" ]] && args+=( --filter "$filter_text" )
        queue list "${args[@]}"

        echo
        _queuemgr_print_commands
        echo
        read -e -r -p "queuemgr> " cmd arg extra rest

        case "$cmd" in
            q|quit|exit) bind '"\t": complete' 2>/dev/null || true; break ;;
            r) queue run; read -r -p "press enter..." ;;
            rd) queue --dryrun run; read -r -p "press enter..." ;;
            rd[0-9]*) queue --dryrun run --workers "${cmd#rd}"; read -r -p "press enter..." ;;
            r[0-9]*) queue run --workers "${cmd#r}"; read -r -p "press enter..." ;;
            s|show) queue show "$arg"; read -r -p "press enter..." ;;
            t|tail|follow) queue tail "$arg"; read -r -p "press enter..." ;;
            pid|pids|ps) queue pids "$arg"; read -r -p "press enter..." ;;
            m|metrics|metric|unit) queue metrics "$arg"; read -r -p "press enter..." ;;
            ex|explain) queue explain "$arg"; read -r -p "press enter..." ;;
            dep|deps|dependencies) queue deps "$arg"; read -r -p "press enter..." ;;
            wait|waiting|blocked) queue waiting; read -r -p "press enter..." ;;
            sched|scheduled|schedule) queue scheduled; read -r -p "press enter..." ;;
            p|prio|priority) queue priority "$arg" "$extra"; read -r -p "press enter..." ;;
            pause|hold) queue pause "$arg"; read -r -p "press enter..." ;;
            pd|pausedry|drypause) queue --dryrun pause "$arg"; read -r -p "press enter..." ;;
            unp|unpause|resume|release) queue unpause "$arg"; read -r -p "press enter..." ;;
            unpd|dryunpause) queue --dryrun unpause "$arg"; read -r -p "press enter..." ;;
            os|hooks|hook) queue hooks "$arg"; read -r -p "press enter..." ;;
            ok|onsuccess|on-success)
                if [[ "$extra" == "--" ]]; then
                    # shellcheck disable=SC2086
                    queue onsuccess "$arg" -- $rest
                else
                    echo "Usage: ok <id|name> -- <command...>"
                fi
                read -r -p "press enter..."
                ;;
            fail|onfailure|on-failure)
                if [[ "$extra" == "--" ]]; then
                    # shellcheck disable=SC2086
                    queue onfailure "$arg" -- $rest
                else
                    echo "Usage: fail <id|name> -- <command...>"
                fi
                read -r -p "press enter..."
                ;;
            c|cancel) queue cancel "$arg"; read -r -p "press enter..." ;;
            kd|kill) queue kill "$arg"; read -r -p "press enter..." ;;
            d|del|delete) queue delete "$arg"; read -r -p "press enter..." ;;
            dd|drydelete) queue --dryrun delete "$arg"; read -r -p "press enter..." ;;
            df|delf|deletef) queue delete "$arg" --force; read -r -p "press enter..." ;;
            u|undel|undelete|restore) queue undelete "$arg"; read -r -p "press enter..." ;;
            ud|dryundelete) queue --dryrun undelete "$arg"; read -r -p "press enter..." ;;
            uf|undelf|undeletef|restoref) queue undelete "$arg" --force; read -r -p "press enter..." ;;
            rs|resubmit|retry) queue resubmit "$arg"; read -r -p "press enter..." ;;
            rsd|dryresubmit|dryretry) queue --dryrun resubmit "$arg"; read -r -p "press enter..." ;;
            ci|clear-interrupted) queue clear interrupted; read -r -p "press enter..." ;;
            cid|dry-clear-interrupted) queue --dryrun clear interrupted; read -r -p "press enter..." ;;
            cc|clear-cancelled) queue clear cancelled; read -r -p "press enter..." ;;
            ccd|dry-clear-cancelled) queue --dryrun clear cancelled; read -r -p "press enter..." ;;
            cdel|clear-deleted) queue clear deleted; read -r -p "press enter..." ;;
            gz|gzip-logs|compress-logs) queue compress-logs; read -r -p "press enter..." ;;
            clog|clean-logs|cleanlogs|log-clean|logs-clean) queue clean-logs --dryrun; read -r -p "press enter..." ;;
            stat|stats) queue stats; read -r -p "press enter..." ;;
            h|health) queue health; read -r -p "press enter..." ;;
            hf|healthfix|health-fix) queue health --fix; read -r -p "press enter..." ;;
            ev|events) queue events --tail "${arg:-20}"; read -r -p "press enter..." ;;
            f|filter) filter_text="$arg" ;;
            n|name) filter_name="$arg" ;;
            st|state) filter_state="${arg:-all}" ;;
            a|all) filter_text=""; filter_name=""; filter_state="all" ;;
            cd) queue clear done; read -r -p "press enter..." ;;
            cf) queue clear failed; read -r -p "press enter..." ;;
            help|?)
                _queuemgr_print_commands
                read -r -p "press enter..."
                ;;
            "") ;;
            *) echo "unknown command"; sleep 1 ;;
        esac
    done
}

# -------------------------------------------------------------------
# Completion
# -------------------------------------------------------------------

_queue_complete() {
    COMPREPLY=()
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local commands="--dryrun -n submit submit-at submit-in list ls find show explain deps dependencies waiting blocked scheduled schedule tail stream follow class classes assets facilities claims resources pids pid ps metrics metric unit hooks hook onsuccess on-success onok on-ok onfailure on-failure onfail on-fail priority prio dynamic-prio pause hold unpause resume release cancel kill delete del rm remove undelete undel restore resubmit retry health stats events watch run start scheduled schedule compress-logs gzip-logs clean-logs cleanlogs log-clean logs-clean clear version --version -V help --help -h"

    if [[ "$COMP_CWORD" -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        return 0
    fi

    case "${COMP_WORDS[1]}" in
        submit)
            if [[ "$prev" == "--priority" || "$prev" == "-p" ]]; then
                COMPREPLY=( $(compgen -W "0 1 5 10 25 50 75 100 200 --dryrun -n" -- "$cur") )
                return 0
            fi
            if [[ "$prev" == "--" ]]; then
                COMPREPLY=( $(compgen -c -- "$cur") )
                return 0
            fi
            COMPREPLY=( $(compgen -W "--dryrun -n --priority -p --retries --backoff --retry-delay --cpu --mem --memory --runner --class --queue-class --after-success --after --depends-on --max-log-size --allow-large-log --no-log-cap --on-success --on-retry-failure --on-attempt-failure --on-failure --" -- "$cur") )
            COMPREPLY+=( $(compgen -c -- "$cur") )
            COMPREPLY+=( $(compgen -f -- "$cur") )
            return 0
            ;;

        list|ls)
            if [[ "$prev" == "--state" || "$prev" == "-s" ]]; then
                COMPREPLY=( $(compgen -W "all pending running paused done failed interrupted cancelled deleted" -- "$cur") )
                return 0
            fi
            COMPREPLY=( $(compgen -W "--state -s --name -n --filter -f" -- "$cur") )
            COMPREPLY+=( $(compgen -W "$(_queue_job_id_and_names_for_completion)" -- "$cur") )
            return 0
            ;;

        show|explain|deps|dependencies|waiting|blocked|scheduled|schedule|tail|follow|pids|pid|ps|metrics|metric|unit|hooks|hook|pause|hold|unpause|resume|release|cancel|kill|delete|del|rm|remove|undelete|undel|restore|resubmit|retry)
            if [[ "$COMP_CWORD" -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "$(_queue_job_id_and_names_for_completion)" -- "$cur") )
                return 0
            fi
            if [[ "$COMP_CWORD" -ge 3 ]]; then
                COMPREPLY=( $(compgen -W "--force -f --dryrun -n pending done failed" -- "$cur") )
                return 0
            fi
            ;;

        onsuccess|on-success|onok|on-ok|onfailure|on-failure|onfail|on-fail)
            if [[ "$COMP_CWORD" -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "$(_queue_job_id_and_names_for_completion)" -- "$cur") )
                return 0
            fi
            if [[ "$COMP_CWORD" -eq 3 ]]; then
                COMPREPLY=( $(compgen -W "--" -- "$cur") )
                return 0
            fi
            if [[ "${COMP_WORDS[3]}" == "--" ]]; then
                COMPREPLY=( $(compgen -c -- "$cur") )
                COMPREPLY+=( $(compgen -f -- "$cur") )
                return 0
            fi
            ;;

        priority|prio|dynamic-prio)
            if [[ "$COMP_CWORD" -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "$(_queue_job_id_and_names_for_completion)" -- "$cur") )
                return 0
            fi
            if [[ "$COMP_CWORD" -eq 3 ]]; then
                COMPREPLY=( $(compgen -W "0 1 5 10 25 50 75 100 200" -- "$cur") )
                return 0
            fi
            ;;

        run|start)
            if [[ "$COMP_CWORD" -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "--workers -w --detach -d --background --dryrun -n" -- "$cur") )
                return 0
            fi
            if [[ "$prev" == "--workers" ]]; then
                COMPREPLY=( $(compgen -W "1 2 3 4 5 6 7 8 12 16" -- "$cur") )
                return 0
            fi
            ;;

        clear)
            COMPREPLY=( $(compgen -W "done failed paused interrupted cancelled deleted all --dryrun -n" -- "$cur") )
            return 0
            ;;
    esac

    COMPREPLY=( $(compgen -f -- "$cur") )
    return 0
}

complete -F _queue_complete queue

_queuemgr_complete() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        --state|-s)
            COMPREPLY=( $(compgen -W "all pending running paused done failed interrupted cancelled deleted" -- "$cur") )
            return 0
            ;;
        --filter|-f|--name|-n)
            COMPREPLY=( $(compgen -W "$(_queue_job_id_and_names_for_completion)" -- "$cur") )
            return 0
            ;;
    esac

    COMPREPLY=( $(compgen -W "--filter -f --state -s --name -n" -- "$cur") )
    COMPREPLY+=( $(compgen -W "$(_queue_job_id_and_names_for_completion)" -- "$cur") )
    return 0
}

complete -F _queuemgr_complete queuemgr

_overfiles_complete() {
    COMPREPLY=()
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ "$COMP_CWORD" -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "--help -h --dryrun" -- "$cur") )
        COMPREPLY+=( $(compgen -f -- "$cur") )
        return 0
    fi

    if [[ "$prev" == "--dryrun" ]]; then
        COMPREPLY=( $(compgen -f -- "$cur") )
        return 0
    fi

    if [[ "$cur" == \{* ]]; then
        COMPREPLY=( $(compgen -W "{1}" -- "$cur") )
        return 0
    fi

    COMPREPLY=( $(compgen -c -- "$cur") )
    COMPREPLY+=( $(compgen -f -- "$cur") )
    COMPREPLY+=( $(compgen -W "{1}" -- "$cur") )
    return 0
}

complete -o default -F _overfiles_complete overfiles

_overdir_complete() {
    COMPREPLY=()
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ "$COMP_CWORD" -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "--help -h --dryrun" -- "$cur") )
        COMPREPLY+=( $(compgen -d -- "$cur") )
        return 0
    fi

    if [[ "$prev" == "--dryrun" ]]; then
        COMPREPLY=( $(compgen -d -- "$cur") )
        return 0
    fi

    if [[ "$cur" == \{* ]]; then
        COMPREPLY=( $(compgen -W "{1}" -- "$cur") )
        return 0
    fi

    COMPREPLY=( $(compgen -c -- "$cur") )
    COMPREPLY+=( $(compgen -d -- "$cur") )
    COMPREPLY+=( $(compgen -W "{1}" -- "$cur") )
    return 0
}

complete -o default -F _overdir_complete overdir
