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

QUEUEBASH_VERSION="0.17.53"

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
    echo "${QUEUEBASH_SELECTED_ROOT:-${QUEUEBASH_ROOT:-$HOME/.queuebash}}"
}

_queue_install_bundled_classes() {
    local root="$(_queue_root)"
    local source_dir="${QUEUEBASH_CLASS_SOURCE_DIR:-}"
    local src dst base script_dir

    if [[ -z "$source_dir" ]]; then
        if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
            script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P || true)"
            if [[ -n "$script_dir" && -d "$script_dir/classes" ]]; then
                source_dir="$script_dir/classes"
            fi
        fi
    fi

    if [[ -z "$source_dir" && -d "./classes" ]]; then
        source_dir="./classes"
    fi

    [[ -n "$source_dir" && -d "$source_dir" ]] || return 0

    mkdir -p "$root/classes"
    shopt -s nullglob
    for src in "$source_dir"/*.env; do
        [[ -f "$src" ]] || continue
        base="$(basename "$src")"
        dst="$root/classes/$base"
        [[ ! -e "$dst" && ! -e "$root/classes/.disabled/$base" ]] && cp "$src" "$dst"
    done
    shopt -u nullglob
}


_queue_obsolete_asset_plugins() {
    # Asset-side net_usage was removed. Runtime net usage accounting now lives
    # under caps.d/net_usage.sh. Keep this explicit rather than pruning arbitrary
    # site-local asset plugins that are not bundled with queuebash.
    printf '%s\n' net_usage
}

_queue_prune_obsolete_asset_plugins() {
    local root="$( _queue_root )" name active disabled obsolete_dir ts target rc=0
    obsolete_dir="$root/assets.d/.obsolete"
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        active="$root/assets.d/$name.sh"
        disabled="$root/assets.d/.disabled/$name.sh"
        if [[ -e "$active" || -e "$disabled" ]]; then
            if ! mkdir -p "$obsolete_dir" 2>/dev/null; then
                echo "queue assets: cannot create obsolete archive directory: $obsolete_dir" >&2
                rc=1
                continue
            fi
            ts="$(date +%Y%m%d_%H%M%S_%N)"
            if [[ -e "$active" ]]; then
                target="$obsolete_dir/${name}.${ts}.sh"
                if mv "$active" "$target" 2>/dev/null; then
                    echo "Archived obsolete asset plugin: $active -> $target" >&2
                else
                    echo "queue assets: cannot archive obsolete asset plugin: $active" >&2
                    rc=1
                fi
            fi
            if [[ -e "$disabled" ]]; then
                target="$obsolete_dir/${name}.${ts}.disabled.sh"
                if mv "$disabled" "$target" 2>/dev/null; then
                    echo "Archived obsolete disabled asset plugin: $disabled -> $target" >&2
                else
                    echo "queue assets: cannot archive obsolete disabled asset plugin: $disabled" >&2
                    rc=1
                fi
            fi
        fi
    done < <(_queue_obsolete_asset_plugins)
    return "$rc"
}

_queue_install_bundled_asset_plugins() {
    local root="$(_queue_root)"
    local source_dir="${QUEUEBASH_PLUGIN_SOURCE_DIR:-}"
    local src dst base script_dir

    if [[ -z "$source_dir" ]]; then
        # Prefer the checked-out source tree when queuebash.sh is sourced/run from it.
        if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
            script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P || true)"
            if [[ -n "$script_dir" && -d "$script_dir/assets.d" ]]; then
                source_dir="$script_dir/assets.d"
            fi
        fi
    fi

    if [[ -z "$source_dir" && -d "./assets.d" ]]; then
        source_dir="./assets.d"
    fi

    [[ -n "$source_dir" && -d "$source_dir" ]] || return 0

    mkdir -p "$root/assets.d"
    _queue_prune_obsolete_asset_plugins >/dev/null 2>&1 || true
    shopt -s nullglob
    for src in "$source_dir"/*.sh; do
        [[ -f "$src" ]] || continue
        base="$(basename "$src")"
        dst="$root/assets.d/$base"

        # Never overwrite local/site-edited plugins; also respect disabled modules.
        if [[ ! -e "$dst" && ! -e "$root/assets.d/.disabled/$base" ]]; then
            cp "$src" "$dst"
            chmod +x "$dst" 2>/dev/null || true
        fi
    done
    shopt -u nullglob
}

_queue_install_bundled_cap_plugins() {
    local root="$(_queue_root)"
    local source_dir="${QUEUEBASH_CAP_PLUGIN_SOURCE_DIR:-}"
    local src dst base script_dir

    if [[ -z "$source_dir" ]]; then
        if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
            script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P || true)"
            if [[ -n "$script_dir" && -d "$script_dir/caps.d" ]]; then
                source_dir="$script_dir/caps.d"
            fi
        fi
    fi

    if [[ -z "$source_dir" && -d "./caps.d" ]]; then
        source_dir="./caps.d"
    fi

    [[ -n "$source_dir" && -d "$source_dir" ]] || return 0

    mkdir -p "$root/caps.d"
    shopt -s nullglob
    for src in "$source_dir"/*.sh; do
        [[ -f "$src" ]] || continue
        base="$(basename "$src")"
        dst="$root/caps.d/$base"
        if [[ ! -e "$dst" && ! -e "$root/caps.d/.disabled/$base" ]]; then
            cp "$src" "$dst"
            chmod +x "$dst" 2>/dev/null || true
        fi
    done
    shopt -u nullglob
}

_queue_install_bundled_policies() {
    local root="$(_queue_root)"
    local source_dir="${QUEUEBASH_POLICY_SOURCE_DIR:-}"
    local src dst rel script_dir kind base

    if [[ -z "$source_dir" ]]; then
        if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
            script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P || true)"
            if [[ -n "$script_dir" && -d "$script_dir/policies.d" ]]; then
                source_dir="$script_dir/policies.d"
            fi
        fi
    fi

    if [[ -z "$source_dir" && -d "./policies.d" ]]; then
        source_dir="./policies.d"
    fi

    [[ -n "$source_dir" && -d "$source_dir" ]] || return 0

    mkdir -p "$root/policies.d/sandbox" "$root/policies.d/seccomp" "$root/policies.d/class-statement"
    shopt -s nullglob
    for src in "$source_dir"/*/*.env; do
        [[ -f "$src" ]] || continue
        kind="$(basename "$(dirname "$src")")"
        case "$kind" in sandbox|seccomp|class-statement) ;; *) continue ;; esac
        base="$(basename "$src")"
        dst="$root/policies.d/$kind/$base"
        if [[ ! -e "$dst" && ! -e "$root/policies.d/$kind/.disabled/$base" ]]; then
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
        fi
    done
    shopt -u nullglob
}

_queue_init() {
    local root="$(_queue_root)"
    local default_class="${QUEUEBASH_DEFAULT_CLASS:-DEFAULT}"
    local default_file="$root/classes/$default_class.env"

    mkdir -p "$root"/{pending,running,paused,done,failed,pol_block,policy_blocked,interrupted,cancelled,deleted,logs,workers,outputs,streams,helpers,classes,class.d,assets.d,caps.d,policies.d/sandbox,policies.d/seccomp,policies.d/class-statement,claims/classes,claims/assets}

    if [[ ! -f "$default_file" ]]; then
        cat > "$default_file" <<'EOF'
# bashqueues default class
# Every job has a class. Jobs submitted without --class use this one.
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0

# Record-format assets only:
#   queue_class_shared_asset family check "target" key=value
#   queue_class_exclusive_asset family check "target" key=value
#   queue_class_exclusive_claim "claim-token"
#
# Explicit cross-user/global resource claims:
#   queue_class_global_exclusive_claim "github:publish"
#   queue_class_global_shared_claim "gpu:cuda" slots=2
#   queue_class_global_shared_asset net allowance "wwan0" slots=1 allowance_bytes=10G direction=rx_tx
EOF
    fi


    _queue_install_bundled_classes
    _queue_install_bundled_asset_plugins
    _queue_install_bundled_cap_plugins
    _queue_install_bundled_policies

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
    for state in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
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

    for state in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
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

_queue_now_iso() {
    date -Is 2>/dev/null || date
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
    local exact="$root/classes/$class.env"
    local f base

    if [[ -f "$exact" ]]; then
        printf '%s\n' "$exact"
        return 0
    fi

    shopt -s nullglob
    for f in "$root/classes"/*.env; do
        base="$(basename "$f" .env)"
        if [[ "${base,,}" == "${class,,}" ]]; then
            printf '%s\n' "$f"
            shopt -u nullglob
            return 0
        fi
    done
    shopt -u nullglob

    printf '%s\n' "$exact"
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


_queue_asset_facility_valid_name() {
    local facility="$1"
    [[ "$facility" =~ ^[A-Za-z_][A-Za-z0-9_]*:[A-Za-z_][A-Za-z0-9_]*$ ]]
}

_queue_asset_contract_validate_loaded() {
    local helper="$1"
    local mode="${2:-strict}"
    local line facility family check func
    local rc=0
    local any=0

    if ! declare -F queue_asset_facilities >/dev/null 2>&1; then
        echo "asset_contract_error: missing publisher queue_asset_facilities helper=$helper"
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        facility="${line%%[[:space:]]*}"
        [[ -z "$facility" ]] && continue
        any=1

        if ! _queue_asset_facility_valid_name "$facility"; then
            echo "asset_contract_error: invalid facility '$facility' helper=$helper"
            rc=1
            continue
        fi

        family="${facility%%:*}"
        check="${facility#*:}"
        func="$(_queue_asset_check_function_name "$family" "$check")"

        if ! declare -F "$func" >/dev/null 2>&1; then
            echo "asset_contract_error: facility '$facility' missing function $func helper=$helper"
            rc=1
            continue
        fi

        if [[ "$mode" != "quiet" ]]; then
            echo "asset_contract_ok: $facility -> $func"
        fi
    done < <(queue_asset_facilities)

    if [[ "$any" -eq 0 ]]; then
        echo "asset_contract_error: publisher returned no facilities helper=$helper"
        rc=1
    fi

    return "$rc"
}

_queue_asset_contract_validate_helper() {
    local helper="$1"
    local mode="${2:-strict}"

    [[ -f "$helper" ]] || { echo "asset_contract_error: helper not found: $helper"; return 1; }

    (
        source "$helper" >/dev/null 2>&1 || { echo "asset_contract_error: source failed helper=$helper"; exit 1; }
        _queue_asset_contract_validate_loaded "$helper" "$mode"
    )
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


_queue_asset_family_valid_name() {
    local family="$1"
    [[ "$family" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}



_queue_class_archive_dir() { printf '%s\n' "$(_queue_root)/classes/.archive"; }
_queue_class_backup_dir() { printf '%s\n' "$(_queue_root)/classes/.backup"; }
_queue_class_valid_name() { local class="$1"; [[ "$class" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]]; }

_queue_class_list_names() {
    local root="$(_queue_root)" f
    shopt -s nullglob
    for f in "$root/classes"/*.env; do [[ -f "$f" ]] && basename "$f" .env; done | sort
    shopt -u nullglob
}


_queue_class_validate_no_legacy_assets() {
    local src="$1"

    if grep -Eq '^[[:space:]]*CLASS_(SHARED_ASSETS|EXCLUSIVE_ASSETS|ASSETS)[[:space:]]*=' "$src"; then
        echo "queue classes: legacy CLASS_*_ASSETS format is not supported: $src" >&2
        echo "queue classes: use queue_class_shared_asset / queue_class_exclusive_asset records" >&2
        return 1
    fi

    return 0
}

_queue_class_validate_file() {
    local class="$1" src="$2" tmpdir tmp rc
    _queue_class_valid_name "$class" || { echo "queue classes: invalid class name: $class" >&2; return 2; }
    [[ -f "$src" ]] || { echo "queue classes: class file not found: $src" >&2; return 2; }
    _queue_class_validate_no_legacy_assets "$src" || return 6
    tmpdir="$(mktemp -d)"; tmp="$tmpdir/$class.env"; cp "$src" "$tmp" || { rm -rf "$tmpdir"; return 1; }
    if ! bash -n "$tmp"; then echo "queue classes: syntax validation failed: $src" >&2; rm -rf "$tmpdir"; return 3; fi
    (
        CLASS_ALLOW_PARALLEL=1; CLASS_MAX_CONCURRENT=0; CLASS_SHARED_ASSETS=""; CLASS_EXCLUSIVE_ASSETS=""; CLASS_ASSETS=""
        source "$tmp" >/dev/null 2>&1 || exit 4
        [[ "${CLASS_MAX_CONCURRENT:-0}" =~ ^[0-9]+$ ]] || exit 5
        exit 0
    )
    rc="$?"
    case "$rc" in
        0) ;;
        4) echo "queue classes: source failed: $src" >&2 ;;
        5) echo "queue classes: CLASS_MAX_CONCURRENT must be numeric: $src" >&2 ;;
        *) echo "queue classes: validation failed rc=$rc: $src" >&2 ;;
    esac
    rm -rf "$tmpdir"; return "$rc"
}

_queue_class_replace() {
    local class="$1" src="$2" force="${3:-0}" root dst backup_dir backup tmp meta ts
    _queue_class_valid_name "$class" || { echo "queue classes replace: invalid class: $class" >&2; return 2; }
    [[ -f "$src" ]] || { echo "queue classes replace: source not found: $src" >&2; return 2; }
    if [[ "$force" != "1" ]]; then _queue_class_validate_file "$class" "$src" || return "$?"; else bash -n "$src" || return 3; fi
    root="$(_queue_root)"; mkdir -p "$root/classes"; dst="$root/classes/$class.env"
    backup_dir="$(_queue_class_backup_dir)"; mkdir -p "$backup_dir"
    ts="$(date +%Y%m%d_%H%M%S_%N)"; backup="$backup_dir/${class}.${ts}.env"; meta="$backup_dir/${class}.${ts}.meta"; tmp="$root/classes/.${class}.new.$$"
    if [[ -e "$dst" ]]; then
        cp -p "$dst" "$backup" || return 1
        { printf 'class=%q\n' "$class"; printf 'backup=%q\n' "$backup"; printf 'original=%q\n' "$dst"; printf 'replaced_at=%q\n' "$(date -Is)"; printf 'source=%q\n' "$src"; } > "$meta"
    else
        { printf 'class=%q\n' "$class"; printf 'backup=%q\n' ""; printf 'original=%q\n' "$dst"; printf 'replaced_at=%q\n' "$(date -Is)"; printf 'source=%q\n' "$src"; printf 'created_new=1\n'; } > "$meta"
    fi
    cp "$src" "$tmp" || { rm -f "$tmp"; return 1; }
    mv -f "$tmp" "$dst" || { rm -f "$tmp"; return 1; }
    echo "Replaced queue class: $dst"; [[ -f "$backup" ]] && echo "Backup: $backup" || echo "Backup: none (new class)"
    _queue_log_event "class_replaced" "$class" "$class" "classes" "path=$dst backup=$backup source=$src" 2>/dev/null || true
}

_queue_class_refresh_from_dir() {
    local src_dir="$1" src class rc=0
    [[ -n "$src_dir" && -d "$src_dir" ]] || { echo "queue classes refresh: directory not found: $src_dir" >&2; return 2; }
    shopt -s nullglob
    for src in "$src_dir"/*.env; do [[ -f "$src" ]] || continue; class="$(basename "$src" .env)"; echo "Refreshing class=$class source=$src"; _queue_class_replace "$class" "$src" 0 || rc=1; done
    shopt -u nullglob; return "$rc"
}

_queue_class_latest_backup() { local class="$1" dir="$(_queue_class_backup_dir)"; ls -1t "$dir/${class}".*.env 2>/dev/null | head -1 || true; }

_queue_class_rollback() {
    local class="$1" backup="${2:-}" root dst tmp
    _queue_class_valid_name "$class" || return 2
    root="$(_queue_root)"; dst="$root/classes/$class.env"; [[ -n "$backup" ]] || backup="$(_queue_class_latest_backup "$class")"
    [[ -n "$backup" && -f "$backup" ]] || { echo "queue classes rollback: no backup found for class: $class" >&2; return 1; }
    _queue_class_validate_file "$class" "$backup" || return 4
    tmp="$root/classes/.${class}.rollback.$$"; cp "$backup" "$tmp" || { rm -f "$tmp"; return 1; }; mv -f "$tmp" "$dst" || { rm -f "$tmp"; return 1; }
    echo "Rolled back queue class: $dst"; echo "Restored from: $backup"
}

_queue_class_delete() {
    local class="$1" root dst archive_dir archive meta ts ref
    _queue_class_valid_name "$class" || return 2
    root="$(_queue_root)"; dst="$(_queue_class_file "$class")"; [[ -f "$dst" ]] || { echo "queue classes delete: class not found: $class ($dst)" >&2; return 1; }
    ref="$(grep -R -l -E "^JOB_CLASS=['\"]?${class}['\"]?$|^JOB_CLASS=${class}$" "$root/pending" "$root/running" "$root/paused" 2>/dev/null | head -1 || true)"
    [[ -z "$ref" ]] || { echo "queue classes delete: refusing because pending/running/paused jobs reference class: $class" >&2; echo "$ref" >&2; return 3; }
    archive_dir="$(_queue_class_archive_dir)"; mkdir -p "$archive_dir"; ts="$(date +%Y%m%d_%H%M%S_%N)"; archive="$archive_dir/${class}.${ts}.env"; meta="$archive_dir/${class}.${ts}.meta"
    mv "$dst" "$archive" || return 1
    { printf 'class=%q\n' "$class"; printf 'archive=%q\n' "$archive"; printf 'original=%q\n' "$dst"; printf 'archived_at=%q\n' "$(date -Is)"; } > "$meta"
    echo "Archived queue class: $dst"; echo "Archive: $archive"
}

_queue_class_latest_archive() { local class="$1" dir="$(_queue_class_archive_dir)"; ls -1t "$dir/${class}".*.env 2>/dev/null | head -1 || true; }

_queue_class_undelete() {
    local class="$1" archive="${2:-}" root dst tmp
    _queue_class_valid_name "$class" || return 2
    root="$(_queue_root)"; dst="$root/classes/$class.env"; [[ -n "$archive" ]] || archive="$(_queue_class_latest_archive "$class")"
    [[ -n "$archive" && -f "$archive" ]] || { echo "queue classes undelete: no archive found for class: $class" >&2; return 1; }
    [[ ! -e "$dst" ]] || { echo "queue classes undelete: active class already exists: $dst" >&2; return 3; }
    _queue_class_validate_file "$class" "$archive" || return 4
    tmp="$root/classes/.${class}.undelete.$$"; cp "$archive" "$tmp" || { rm -f "$tmp"; return 1; }; mv -f "$tmp" "$dst" || { rm -f "$tmp"; return 1; }
    echo "Restored archived queue class: $dst"; echo "Restored from: $archive"
}

_queue_class_backups() { local class="${1:-}" dir="$(_queue_class_backup_dir)"; mkdir -p "$dir"; if [[ -n "$class" ]]; then ls -1t "$dir/${class}".*.env 2>/dev/null || true; else ls -1t "$dir"/*.env 2>/dev/null || true; fi; }
_queue_class_archives() { local class="${1:-}" dir="$(_queue_class_archive_dir)"; mkdir -p "$dir"; if [[ -n "$class" ]]; then ls -1t "$dir/${class}".*.env 2>/dev/null || true; else ls -1t "$dir"/*.env 2>/dev/null || true; fi; }


_queue_class_name_from_file() {
    local file="$1"
    local base name

    base="$(basename "$file")"
    name="${base%.env}"

    [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]] || return 1
    printf '%s\n' "$name"
}

_queue_class_refresh_one() {
    local src="$1"
    local name dst backup_dir backup ts tmp meta created_new=0

    [[ -f "$src" ]] || {
        echo "queue classes refresh: not a file: $src" >&2
        return 1
    }

    name="$(_queue_class_name_from_file "$src")" || {
        echo "queue classes refresh: invalid class filename: $src" >&2
        return 1
    }

    mkdir -p "$(_queue_root)/classes" "$(_queue_root)/classes/.backup"

    dst="$(_queue_root)/classes/${name}.env"
    backup_dir="$(_queue_root)/classes/.backup"

    tmp="$(mktemp)"
    cp "$src" "$tmp"

    if ! bash -n "$tmp" >/dev/null 2>&1; then
        echo "queue classes refresh: syntax check failed: $src" >&2
        rm -f "$tmp"
        return 1
    fi

    ts="$(date +%Y%m%d_%H%M%S_%N)"
    meta="$backup_dir/${name}.${ts}.meta"

    if [[ -f "$dst" ]]; then
        backup="$backup_dir/${name}.${ts}.env"
        cp "$dst" "$backup"
    else
        backup=""
        created_new=1
    fi

    echo "Refreshing class definition name=$name source=$src"
    cp "$tmp" "$dst"
    rm -f "$tmp"

    if ! _queue_class_validate "$name" >/dev/null 2>&1; then
        echo "queue classes refresh: validation failed after install: $name" >&2
        if [[ -n "$backup" && -f "$backup" ]]; then
            cp "$backup" "$dst"
            echo "Rolled back class definition: $dst" >&2
        else
            rm -f "$dst"
            echo "Removed invalid new class definition: $dst" >&2
        fi
        return 1
    fi

    {
        printf 'class=%q\n' "$name"
        printf 'backup=%q\n' "$backup"
        printf 'original=%q\n' "$dst"
        printf 'replaced_at=%q\n' "$(date -Is 2>/dev/null || date)"
        printf 'source=%q\n' "$src"
        printf 'created_new=%q\n' "$created_new"
    } > "$meta"

    echo "Replaced class definition: $dst"
    [[ -n "$backup" ]] && echo "Backup: $backup"
    echo "Metadata: $meta"
}

_queue_classes_refresh() {
    local dir="${1:-}"
    local src any=0 rc=0

    if [[ -z "$dir" ]]; then
        echo "Usage: queue classes refresh <directory>" >&2
        return 2
    fi

    if [[ ! -d "$dir" ]]; then
        echo "queue classes refresh: directory not found: $dir" >&2
        return 1
    fi

    shopt -s nullglob
    for src in "$dir"/*.env; do
        any=1
        _queue_class_refresh_one "$src" || rc=1
    done
    shopt -u nullglob

    if [[ "$any" -eq 0 ]]; then
        echo "queue classes refresh: no .env class files found in $dir" >&2
        return 1
    fi

    return "$rc"
}

_queue_class_explain() {
    local class="$1" f refs
    [[ -n "$class" ]] || { echo "Usage: queue classes explain <class>" >&2; return 2; }
    f="$(_queue_class_file "$class")"
    echo "============================================================================="
    echo "CLASS EXPLAIN: $class"
    echo "============================================================================="
    echo "class file:       $f"
    if [[ -f "$f" ]]; then echo "exists:           yes"; echo; echo "Contents:"; sed 's/^/  /' "$f"; echo; echo "Validation:"; _queue_class_validate_file "$(basename "$f" .env)" "$f" && echo "  OK" || true; else echo "exists:           no"; fi
    echo; echo "Jobs referencing this class:"
    refs="$(grep -R -l -E "^JOB_CLASS=['\"]?${class}['\"]?$|^JOB_CLASS=${class}$" "$(_queue_root)"/{pending,running,paused,done,failed,pol_block,policy_blocked,interrupted,cancelled,deleted} 2>/dev/null || true)"
    [[ -n "$refs" ]] && echo "$refs" || echo "  none"
    echo
    echo "Class defaults:"
    _queue_class_defaults_show "$class"

}


# -----------------------------------------------------------------------------
# Class asset record format
# -----------------------------------------------------------------------------
# Legacy format remains supported:
#   CLASS_SHARED_ASSETS="path:exists:/tmp git:repo_exists:/repo"
#
# New record format is delimiter-safe. The class file calls functions; Bash keeps
# each argument separate, so targets/params may contain as many ':' or ',' chars
# as needed:
#   queue_class_shared_asset net http_status "https://github.com" timeout=5 accept_status="200,201,302,403"
#   queue_class_shared_asset net tcp_endpoint "db.internal:5432" timeout=3
#   queue_class_exclusive_asset "github_publish:slot"

_queue_class_asset_reset() {
    QUEUE_CLASS_SHARED_ASSET_SPECS=()
    QUEUE_CLASS_EXCLUSIVE_ASSET_SPECS=()
    QUEUE_CLASS_GLOBAL_CLAIM_SPECS=()
}

_queue_class_asset_pack() {
    local arg q out=""
    for arg in "$@"; do
        printf -v q '%q' "$arg"
        out+="$q "
    done
    printf '%s' "$out"
}

queue_class_shared_asset() {
    QUEUE_CLASS_SHARED_ASSET_SPECS+=("$(_queue_class_asset_pack "$@")")
}

queue_class_exclusive_asset() {
    QUEUE_CLASS_EXCLUSIVE_ASSET_SPECS+=("$(_queue_class_asset_pack "$@")")
}

_queue_class_global_pack() {
    local mode="$1" slots="$2" record_type="$3"
    shift 3 || true
    _queue_class_asset_pack "$mode" "$slots" "$record_type" "$@"
}

# Explicit cross-user/global coordination records. These do not change legacy
# per-queue class/assets behaviour; operators opt in by using global records.
queue_class_global_exclusive_claim() {
    local claim="${1:-}"
    [[ -n "$claim" ]] || return 0
    shift || true
    QUEUE_CLASS_GLOBAL_CLAIM_SPECS+=("$(_queue_class_global_pack exclusive 1 claim "$claim" "$@")")
}

queue_class_global_shared_claim() {
    local claim="${1:-}"
    [[ -n "$claim" ]] || return 0
    shift || true
    QUEUE_CLASS_GLOBAL_CLAIM_SPECS+=("$(_queue_class_global_pack shared 0 claim "$claim" "$@")")
}

queue_class_global_exclusive_asset() {
    [[ "$#" -ge 3 ]] || return 0
    QUEUE_CLASS_GLOBAL_CLAIM_SPECS+=("$(_queue_class_global_pack exclusive 1 asset "$@")")
}

queue_class_global_shared_asset() {
    [[ "$#" -ge 3 ]] || return 0
    QUEUE_CLASS_GLOBAL_CLAIM_SPECS+=("$(_queue_class_global_pack shared 0 asset "$@")")
}

# Friendly spellings for operators creating classes by hand.
queue_class_global_exclusive_resource() { queue_class_global_exclusive_claim "$@"; }
queue_class_global_shared_resource() { queue_class_global_shared_claim "$@"; }

# Friendly aliases for claim-only assets.
queue_class_shared_claim() { queue_class_shared_asset "$@"; }
queue_class_exclusive_claim() { queue_class_exclusive_asset "$@"; }

_queue_class_asset_claim_token_from_spec() {
    local spec="$1"
    eval "set -- $spec"
    case "$#" in
        0) return 0 ;;
        1) printf '%s\n' "$1" ;;
        2) printf '%s:%s\n' "$1" "$2" ;;
        *) printf '%s:%s:%s\n' "$1" "$2" "$3" ;;
    esac
}


_queue_asset_check_uses_legacy_token_target_contract() {
    local func="$1"
    local body

    body="$(declare -f "$func" 2>/dev/null || true)"

    # Older bundled helpers used token as $1 and target as $2.
    grep -Eq 'local[[:space:]]+token="\$1"|local[[:space:]][^;]*token="\$1"' <<< "$body" &&
        grep -Eq 'shift[[:space:]]+2|\$2' <<< "$body"
}

_queue_asset_implied_preflight_args() {
    local token="$1" family="$2" check="$3" target="$4"
    shift 4 || true
    local helper func

    [[ -n "$family" && -n "$check" && -n "$target" ]] || return 0

    helper="$(_queue_asset_helper_path "$family")"
    func="$(_queue_asset_check_function_name "$family" "$check")"

    # No helper means claim-only token.
    [[ -f "$helper" ]] || return 0

    (
        source "$helper" || exit 40
        _queue_asset_contract_validate_loaded "$helper" quiet >/dev/null || exit 43
        _queue_asset_facility_is_published "$family" "$check" || exit 41
        declare -F "$func" >/dev/null 2>&1 || exit 42
        if _queue_asset_check_uses_legacy_token_target_contract "$func"; then
            "$func" "$token" "$target" "$@"
        else
            "$func" "$target" "$@"
        fi
    )
}

_queue_asset_implied_preflight_spec() {
    local spec="$1" token
    eval "set -- $spec"
    (($# >= 3)) || return 0
    token="$(_queue_class_asset_claim_token_from_spec "$spec")"
    _queue_asset_implied_preflight_args "$token" "$@"
}

_queue_asset_archive_dir() { printf '%s\n' "$(_queue_root)/assets.d/.archive"; }

_queue_asset_family_is_used_by_classes() {
    local family="$1"
    local root="$(_queue_root)"
    local classfile rec rec_family
    shopt -s nullglob
    for classfile in "$root/classes"/*.env; do
        [[ -f "$classfile" ]] || continue
        (
            _queue_class_record_reset 2>/dev/null || true
            source "$classfile" >/dev/null 2>&1 || exit 0

            for rec in "${QUEUE_CLASS_SHARED_ASSET_RECORDS[@]:-}" "${QUEUE_CLASS_EXCLUSIVE_ASSET_RECORDS[@]:-}"; do
                rec_family="${rec%%"$'\t'"*}"
                if [[ "$rec_family" == "$family" ]]; then
                    echo "$classfile:$rec"
                fi
            done
        )
    done
    shopt -u nullglob
}

_queue_asset_refresh_from_dir() {
    local src_dir="$1" plugin family rc=0
    [[ -n "$src_dir" && -d "$src_dir" ]] || { echo "queue assets refresh: directory not found: $src_dir" >&2; return 2; }
    shopt -s nullglob
    for plugin in "$src_dir"/*.sh; do
        [[ -f "$plugin" ]] || continue
        family="$(basename "$plugin" .sh)"
        echo "Refreshing asset plugin family=$family source=$plugin"
        _queue_asset_replace_plugin "$family" "$plugin" 0 || rc=1
    done
    shopt -u nullglob
    return "$rc"
}

_queue_asset_delete_plugin() {
    local family="$1" root dst archive_dir ts archive meta used
    _queue_asset_family_valid_name "$family" || { echo "queue assets delete: invalid family: $family" >&2; return 2; }
    used="$(_queue_asset_family_is_used_by_classes "$family")"
    if [[ -n "$used" ]]; then
        echo "queue assets delete: refusing to archive plugin because family is used by classes:" >&2
        echo "$used" >&2
        echo "Remove or change those class assets first." >&2
        return 3
    fi
    root="$(_queue_root)"; dst="$root/assets.d/$family.sh"
    [[ -f "$dst" ]] || { echo "queue assets delete: plugin not found: $dst" >&2; return 1; }
    archive_dir="$(_queue_asset_archive_dir)"; mkdir -p "$archive_dir"
    ts="$(date +%Y%m%d_%H%M%S_%N)"
    archive="$archive_dir/${family}.${ts}.sh"; meta="$archive_dir/${family}.${ts}.meta"
    mv "$dst" "$archive" || return 1
    { printf 'family=%q\n' "$family"; printf 'archive=%q\n' "$archive"; printf 'original=%q\n' "$dst"; printf 'archived_at=%q\n' "$(date -Is)"; } > "$meta"
    echo "Archived asset plugin: $dst"
    echo "Archive: $archive"
    _queue_log_event "asset_plugin_archived" "$family" "$family" "assets" "path=$dst archive=$archive" 2>/dev/null || true
}

_queue_asset_latest_archive_for_family() {
    local family="$1" archive_dir="$(_queue_asset_archive_dir)"
    ls -1t "$archive_dir/${family}".*.sh 2>/dev/null | head -1 || true
}

_queue_asset_undelete_plugin() {
    local family="$1" archive="${2:-}" root dst tmp
    _queue_asset_family_valid_name "$family" || { echo "queue assets undelete: invalid family: $family" >&2; return 2; }
    root="$(_queue_root)"; dst="$root/assets.d/$family.sh"
    [[ -n "$archive" ]] || archive="$(_queue_asset_latest_archive_for_family "$family")"
    [[ -n "$archive" && -f "$archive" ]] || { echo "queue assets undelete: no archived plugin found for family: $family" >&2; return 1; }
    [[ ! -e "$dst" ]] || { echo "queue assets undelete: active plugin already exists: $dst" >&2; return 3; }
    _queue_asset_replace_validate_source "$family" "$archive" || return 4
    tmp="$root/assets.d/.${family}.undelete.$$"
    cp "$archive" "$tmp" || { rm -f "$tmp"; return 1; }
    chmod +x "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$dst" || { rm -f "$tmp"; return 1; }
    echo "Restored archived asset plugin: $dst"
    echo "Restored from: $archive"
    _queue_log_event "asset_plugin_undeleted" "$family" "$family" "assets" "path=$dst archive=$archive" 2>/dev/null || true
}

_queue_asset_list_archives() {
    local family="${1:-}" archive_dir="$(_queue_asset_archive_dir)"
    mkdir -p "$archive_dir"
    if [[ -n "$family" ]]; then ls -1t "$archive_dir/${family}".*.sh 2>/dev/null || true; else ls -1t "$archive_dir"/*.sh 2>/dev/null || true; fi
}

_queue_asset_explain() {
    local subject="$1" family check helper func used dupes archived backups
    [[ -n "$subject" ]] || { echo "Usage: queue assets explain <family|family:check>" >&2; return 2; }
    if [[ "$subject" == *:* ]]; then family="${subject%%:*}"; check="${subject#*:}"; else family="$subject"; check=""; fi
    _queue_asset_family_valid_name "$family" || { echo "queue assets explain: invalid family: $family" >&2; return 2; }
    helper="$(_queue_asset_helper_path "$family")"
    echo "============================================================================="
    echo "ASSET EXPLAIN: $subject"
    echo "============================================================================="
    echo "family:              $family"
    [[ -n "$check" ]] && echo "facility:            $family:$check"
    echo "active helper:       $helper"
    if [[ -f "$helper" ]]; then
        echo "active helper exists: yes"; echo; echo "Published facilities:"
        ( source "$helper" >/dev/null 2>&1 && declare -F queue_asset_facilities >/dev/null 2>&1 && queue_asset_facilities ) || echo "  none"
        echo; echo "Contract:"; _queue_asset_contract_validate_helper "$helper" strict || true
    else
        echo "active helper exists: no"
    fi
    if [[ -n "$check" ]]; then func="$(_queue_asset_check_function_name "$family" "$check")"; echo; echo "Resolved check function:"; echo "  $func"; fi
    echo; echo "Class usage:"; used="$(_queue_asset_family_is_used_by_classes "$family" || true)"; [[ -n "$used" ]] && echo "$used" || echo "  none"
    echo; echo "Duplicate publishers:"; dupes="$(_queue_asset_scan_duplicate_publishers | awk -v fam="$family" -F '\t' '$1 ~ "^" fam ":" {print}' || true)"; [[ -n "$dupes" ]] && echo "$dupes" || echo "  none"
    echo; echo "Backups:"; backups="$(_queue_asset_list_backups "$family" || true)"; [[ -n "$backups" ]] && echo "$backups" || echo "  none"
    echo; echo "Archives:"; archived="$(_queue_asset_list_archives "$family" || true)"; [[ -n "$archived" ]] && echo "$archived" || echo "  none"
    return 0
}

_queue_asset_replace_backup_dir() {
    printf '%s\n' "$(_queue_root)/assets.d/.backup"
}

_queue_asset_replace_validate_source() {
    local family="$1"
    local src="$2"
    local tmpdir tmp helper_rc

    _queue_asset_family_valid_name "$family" || { echo "queue assets replace: invalid family: $family" >&2; return 2; }
    [[ -f "$src" ]] || { echo "queue assets replace: source plugin not found: $src" >&2; return 2; }

    tmpdir="$(mktemp -d)"
    tmp="$tmpdir/$family.sh"
    cp "$src" "$tmp" || { rm -rf "$tmpdir"; return 1; }

    # Syntax validation first.
    if ! bash -n "$tmp"; then
        echo "queue assets replace: syntax validation failed: $src" >&2
        rm -rf "$tmpdir"
        return 3
    fi

    # Contract validation against the temporary helper.
    _queue_asset_contract_validate_helper "$tmp" quiet >/dev/null
    helper_rc="$?"
    if [[ "$helper_rc" -ne 0 ]]; then
        echo "queue assets replace: contract validation failed: $src" >&2
        _queue_asset_contract_validate_helper "$tmp" strict >&2 || true
        rm -rf "$tmpdir"
        return 4
    fi

    # Require at least one facility for this family to prevent accidentally
    # installing a sys plugin as net.sh, etc.
    (
        source "$tmp" >/dev/null 2>&1 || exit 1
        queue_asset_facilities | awk '{print $1}' | grep -Eq "^${family}:"
    )
    helper_rc="$?"
    if [[ "$helper_rc" -ne 0 ]]; then
        echo "queue assets replace: plugin does not publish any ${family}: facilities: $src" >&2
        rm -rf "$tmpdir"
        return 5
    fi

    rm -rf "$tmpdir"
    return 0
}

_queue_asset_replace_plugin() {
    local family="$1"
    local src="$2"
    local force="${3:-0}"
    local root dst backup_dir ts backup tmp meta

    _queue_asset_family_valid_name "$family" || { echo "queue assets replace: invalid family: $family" >&2; return 2; }
    [[ -f "$src" ]] || { echo "queue assets replace: source plugin not found: $src" >&2; return 2; }

    if [[ "$force" != "1" ]]; then
        _queue_asset_replace_validate_source "$family" "$src" || return "$?"
    else
        bash -n "$src" || return 3
        echo "queue assets replace: WARNING force mode skipped contract validation" >&2
    fi

    root="$(_queue_root)"
    mkdir -p "$root/assets.d"
    backup_dir="$(_queue_asset_replace_backup_dir)"
    mkdir -p "$backup_dir"

    dst="$root/assets.d/$family.sh"
    ts="$(date +%Y%m%d_%H%M%S_%N)"
    backup="$backup_dir/${family}.${ts}.sh"
    tmp="$root/assets.d/.${family}.new.$$"
    meta="$backup_dir/${family}.${ts}.meta"

    if [[ -e "$dst" ]]; then
        cp -p "$dst" "$backup" || return 1
        {
            printf 'family=%q\n' "$family"
            printf 'backup=%q\n' "$backup"
            printf 'original=%q\n' "$dst"
            printf 'replaced_at=%q\n' "$(date -Is)"
            printf 'source=%q\n' "$src"
        } > "$meta"
    else
        {
            printf 'family=%q\n' "$family"
            printf 'backup=%q\n' ""
            printf 'original=%q\n' "$dst"
            printf 'replaced_at=%q\n' "$(date -Is)"
            printf 'source=%q\n' "$src"
            printf 'created_new=1\n'
        } > "$meta"
    fi

    cp "$src" "$tmp" || { rm -f "$tmp"; return 1; }
    chmod +x "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$dst" || { rm -f "$tmp"; return 1; }

    echo "Replaced asset plugin: $dst"
    if [[ -f "$backup" ]]; then
        echo "Backup: $backup"
    else
        echo "Backup: none (new plugin)"
    fi

    _queue_log_event "asset_plugin_replaced" "$family" "$family" "assets" "path=$dst backup=$backup source=$src" 2>/dev/null || true
}

_queue_asset_latest_backup_for_family() {
    local family="$1"
    local backup_dir="$(_queue_asset_replace_backup_dir)"
    ls -1t "$backup_dir/${family}".*.sh 2>/dev/null | head -1
}

_queue_asset_rollback_plugin() {
    local family="$1"
    local backup="${2:-}"
    local root dst tmp

    _queue_asset_family_valid_name "$family" || { echo "queue assets rollback: invalid family: $family" >&2; return 2; }

    root="$(_queue_root)"
    dst="$root/assets.d/$family.sh"

    if [[ -z "$backup" ]]; then
        backup="$(_queue_asset_latest_backup_for_family "$family")"
    fi

    [[ -n "$backup" && -f "$backup" ]] || { echo "queue assets rollback: no backup found for family: $family" >&2; return 1; }

    # Validate backup before restoring it. A broken backup is worse than no rollback.
    _queue_asset_replace_validate_source "$family" "$backup" || {
        echo "queue assets rollback: backup failed validation, not restoring: $backup" >&2
        return 4
    }

    tmp="$root/assets.d/.${family}.rollback.$$"
    cp "$backup" "$tmp" || { rm -f "$tmp"; return 1; }
    chmod +x "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$dst" || { rm -f "$tmp"; return 1; }

    echo "Rolled back asset plugin: $dst"
    echo "Restored from: $backup"

    _queue_log_event "asset_plugin_rolled_back" "$family" "$family" "assets" "path=$dst backup=$backup" 2>/dev/null || true
}

_queue_asset_list_backups() {
    local family="${1:-}"
    local backup_dir="$(_queue_asset_replace_backup_dir)"
    mkdir -p "$backup_dir"

    if [[ -n "$family" ]]; then
        ls -1t "$backup_dir/${family}".*.sh 2>/dev/null || true
    else
        ls -1t "$backup_dir"/*.sh 2>/dev/null || true
    fi
}

_queue_asset_scan_duplicate_publishers() {
    local root="$(_queue_root)"
    local plugin facility
    local tmp
    tmp="$(mktemp)"
    shopt -s nullglob
    for plugin in "$root/assets.d"/*.sh; do
        [[ -f "$plugin" ]] || continue
        (
            source "$plugin" >/dev/null 2>&1 || exit 0
            declare -F queue_asset_facilities >/dev/null 2>&1 || exit 0
            queue_asset_facilities | awk -v helper="$(basename "$plugin")" '{print $1 "\t" helper}'
        ) >> "$tmp"
    done
    shopt -u nullglob

    awk -F '\t' '
        {
            count[$1]++
            helpers[$1] = helpers[$1] ? helpers[$1] "," $2 : $2
        }
        END {
            for (facility in count) {
                if (count[facility] > 1) {
                    print facility "\t" helpers[facility]
                }
            }
        }
    ' "$tmp" | sort
    rm -f "$tmp"
}

_queue_asset_scan_facilities() {
    local root="$(_queue_root)"
    local plugin
    shopt -s nullglob
    for plugin in "$root/assets.d"/*.sh; do
        [[ -f "$plugin" ]] || continue
        (
            source "$plugin" >/dev/null 2>&1 || { echo "INVALID helper=$(basename "$plugin") source_failed"; exit 0; }

            if ! _queue_asset_contract_validate_loaded "$plugin" quiet >/dev/null; then
                echo "INVALID helper=$(basename "$plugin") contract_failed"
                exit 0
            fi

            queue_asset_facilities
        )
    done | awk '
        /^INVALID / {
            if (!seen_invalid[$0]++) print
            next
        }
        {
            facility=$1
            if (facility == "") next
            if (!seen_facility[facility]++) print
        }
    '
    shopt -u nullglob
}

_queue_asset_implied_preflight_one() {
    local token="$1"
    local family check rest target seg cur_param
    local -a raw params target_parts

    [[ "$token" == *:*:* ]] || return 0

    family="${token%%:*}"
    rest="${token#*:}"
    check="${rest%%:*}"
    rest="${rest#*:}"

    [[ -n "$family" && -n "$check" && -n "$rest" ]] || return 0

    IFS=':' read -r -a raw <<< "$rest"

    params=()
    target_parts=()
    cur_param=""

    for seg in "${raw[@]}"; do
        if [[ -z "$cur_param" && "$seg" == *=* ]]; then
            cur_param="$seg"
        elif [[ -n "$cur_param" && "$seg" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            params+=("$cur_param")
            cur_param="$seg"
        elif [[ -n "$cur_param" ]]; then
            cur_param="${cur_param}:$seg"
        else
            target_parts+=("$seg")
        fi
    done
    [[ -n "$cur_param" ]] && params+=("$cur_param")

    target=""
    if ((${#target_parts[@]} > 0)); then
        local IFS=':'
        target="${target_parts[*]}"
    fi

    _queue_asset_implied_preflight_args "$token" "$family" "$check" "$target" "${params[@]}"
}


_queue_exception_dir() {
    printf '%s\n' "$(_queue_root)/exceptions"
}

_queue_exception_file() {
    local id="$1"
    printf '%s/%s.env\n' "$(_queue_exception_dir)" "$id"
}

_queue_exception_job_id_from_current_context() {
    if [[ -n "${JOB_ID:-}" ]]; then
        printf '%s\n' "$JOB_ID"
        return 0
    fi
    if [[ -n "${QUEUEBASH_CLASS_JOB_ID:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_CLASS_JOB_ID"
        return 0
    fi
    return 1
}

_queue_exception_normalize_key() {
    local key="${1:-}"
    key="${key//[^A-Za-z0-9_:-]/_}"
    printf '%s\n' "$key"
}

_queue_exception_asset_matches() {
    local requested="$1"
    local asset="$2"
    local family="${asset%%:*}"
    local rest="${asset#*:}"
    local facility

    facility="$family:${rest%%:*}"

    [[ "$requested" == "$asset" ]] && return 0
    [[ "$requested" == "$facility" ]] && return 0
    [[ "$requested" == "$family" ]] && return 0

    return 1
}

_queue_exception_is_allowed_for_asset() {
    local id asset f line key reason created_at created_by expires_at

    id="$(_queue_exception_job_id_from_current_context 2>/dev/null || true)"
    [[ -n "$id" ]] || return 1

    asset="$1"
    f="$(_queue_exception_file "$id")"
    [[ -f "$f" ]] || return 1

    while IFS=$'	' read -r key reason created_at created_by expires_at; do
        [[ -n "$key" ]] || continue
        [[ "$key" == \#* ]] && continue
        expires_at="${expires_at:-never}"
        if _queue_exception_asset_matches "$key" "$asset"; then
            if _queue_expiry_is_expired "$expires_at"; then
                printf 'asset_exception_expired: job=%s asset=%s exception=%s expired_at=%s
' "$id" "$asset" "$key" "$expires_at"
                continue
            fi
            QUEUEBASH_EXCEPTION_MATCH_KEY="$key"
            QUEUEBASH_EXCEPTION_MATCH_REASON="${reason:-not-recorded}"
            QUEUEBASH_EXCEPTION_MATCH_BY="${created_by:-unknown}"
            QUEUEBASH_EXCEPTION_MATCH_AT="${created_at:-unknown}"
            QUEUEBASH_EXCEPTION_MATCH_EXPIRES_AT="$expires_at"
            export QUEUEBASH_EXCEPTION_MATCH_KEY QUEUEBASH_EXCEPTION_MATCH_REASON QUEUEBASH_EXCEPTION_MATCH_BY QUEUEBASH_EXCEPTION_MATCH_AT QUEUEBASH_EXCEPTION_MATCH_EXPIRES_AT
            printf 'asset_exception_applied: job=%s asset=%s exception=%s reason=%s by=%s at=%s expires=%s
'                 "$id" "$asset" "$QUEUEBASH_EXCEPTION_MATCH_KEY" "$QUEUEBASH_EXCEPTION_MATCH_REASON" "$QUEUEBASH_EXCEPTION_MATCH_BY" "$QUEUEBASH_EXCEPTION_MATCH_AT" "$QUEUEBASH_EXCEPTION_MATCH_EXPIRES_AT"
            return 0
        fi
    done < "$f"

    return 1
}
_queue_exception_add() {
    local id="${1:-}"
    local key="${2:-}"
    shift 2 || true
    local reason="" expires="never" user created f norm arg

    while (($#)); do
        case "$1" in
            --reason)
                [[ $# -ge 2 ]] || { echo "queue exception add: --reason needs text" >&2; return 2; }
                reason="$2"
                shift 2
                ;;
            --reason=*)
                reason="${1#*=}"
                shift
                ;;
            --expires|--expires-at)
                [[ $# -ge 2 ]] || { echo "queue exception add: $1 needs a value" >&2; return 2; }
                expires="$2"
                shift 2
                ;;
            --expires=*|--expires-at=*)
                expires="${1#*=}"
                shift
                ;;
            *)
                if [[ -z "$reason" ]]; then
                    reason="$1"
                    shift
                else
                    echo "queue exception add: unexpected argument: $1" >&2
                    return 2
                fi
                ;;
        esac
    done

    [[ -n "$id" && -n "$key" ]] || {
        echo "Usage: queue exception add <qid> <family|facility|asset> --reason <text> [--expires never|+30m|+2h|YYYY-MM-DD]" >&2
        return 2
    }
    [[ -n "$reason" ]] || {
        echo "queue exception add: reason is required" >&2
        return 2
    }
    if [[ "$expires" != "never" && -z "$(_queue_expiry_to_epoch "$expires" 2>/dev/null || true)" ]]; then
        echo "queue exception add: unsupported --expires value: $expires" >&2
        return 2
    fi

    norm="$(_queue_exception_normalize_key "$key")"
    mkdir -p "$(_queue_exception_dir)"
    f="$(_queue_exception_file "$id")"
    created="$(date -Is 2>/dev/null || date)"
    user="${USER:-unknown}"

    if [[ -f "$f" ]] && awk -F '	' -v k="$norm" '$1 == k { found=1 } END { exit !found }' "$f"; then
        echo "queue exception add: exception already exists for $id: $norm" >&2
        return 1
    fi

    printf '%s	%s	%s	%s	%s
' "$norm" "$reason" "$created" "$user" "$expires" >> "$f"
    _queue_log_event "exception_added" "$id" "$norm" "exceptions" "reason=$reason by=$user expires=$expires"
    echo "Added exception overlay: job=$id asset=$norm expires=$expires"
}
_queue_exception_list() {
    local id="${1:-}"
    local f

    [[ -n "$id" ]] || { echo "Usage: queue exception list <qid>" >&2; return 2; }
    f="$(_queue_exception_file "$id")"

    echo "=============================================================================="
    echo "QUEUEBASH EXCEPTIONS: $id"
    echo "=============================================================================="

    if [[ ! -f "$f" ]]; then
        echo "none"
        return 0
    fi

    awk -F '	' '
        BEGIN {
            printf "%-32s  %-20s  %-12s  %-20s  %s\n", "ASSET/FACILITY", "CREATED", "BY", "EXPIRES", "REASON"
        }
        NF {
            expires=$5; if (expires == "") expires="never";
            printf "%-32s  %-20s  %-12s  %-20s  %s\n", $1, $3, $4, expires, $2
        }
    ' "$f"
}
_queue_exception_clear() {
    local id="${1:-}"
    local key="${2:-}"
    local f tmp norm user

    [[ -n "$id" && -n "$key" ]] || {
        echo "Usage: queue exception clear <qid> <family|facility|asset>" >&2
        return 2
    }

    f="$(_queue_exception_file "$id")"
    [[ -f "$f" ]] || { echo "queue exception clear: no exceptions for $id" >&2; return 1; }

    norm="$(_queue_exception_normalize_key "$key")"
    tmp="$(mktemp)"
    awk -F '\t' -v k="$norm" '$1 != k' "$f" > "$tmp"

    if cmp -s "$f" "$tmp"; then
        rm -f "$tmp"
        echo "queue exception clear: exception not found: $norm" >&2
        return 1
    fi

    mv "$tmp" "$f"
    user="${USER:-unknown}"
    _queue_log_event "exception_cleared" "$id" "$norm" "exceptions" "by=$user"
    echo "Cleared exception overlay: job=$id asset=$norm"
}

_queue_exception_clear_all() {
    local id="${1:-}"
    local f user

    [[ -n "$id" ]] || { echo "Usage: queue exception clear-all <qid>" >&2; return 2; }
    f="$(_queue_exception_file "$id")"
    [[ -f "$f" ]] || { echo "queue exception clear-all: no exceptions for $id" >&2; return 1; }

    rm -f "$f"
    user="${USER:-unknown}"
    _queue_log_event "exception_cleared_all" "$id" "$id" "exceptions" "by=$user"
    echo "Cleared all exception overlays for job=$id"
}



_queue_security_guidance_shell_join() {
    local out="" item
    for item in "$@"; do
        printf -v item '%q' "$item"
        out="${out:+$out }$item"
    done
    printf '%s\n' "$out"
}

_queue_security_guidance_command_for_current_job() {
    if declare -p COMMAND >/dev/null 2>&1; then
        _queue_security_guidance_shell_join "${COMMAND[@]}"
    else
        printf '%s\n' "${COMMAND_LINE:-}"
    fi
}

_queue_security_guidance_extract_port() {
    local text="${1:-}" port=""
    if [[ "$text" =~ -\>([^[:space:]]*):([0-9]+) ]]; then
        port="${BASH_REMATCH[2]}"
    elif [[ "$text" =~ TCP[^:[:space:]]*:([0-9]+) ]]; then
        port="${BASH_REMATCH[1]}"
    elif [[ "$text" =~ UDP[^:[:space:]]*:([0-9]+) ]]; then
        port="${BASH_REMATCH[1]}"
    elif [[ "$text" =~ :([0-9]+)(\ |$|-) ]]; then
        port="${BASH_REMATCH[1]}"
    fi
    [[ "$port" =~ ^[0-9]+$ ]] && printf '%s\n' "$port"
}

_queue_security_guidance_print_submit() {
    local flag1="${1:-}" value1="${2:-}" flag2="${3:-}" value2="${4:-}"
    local name="${JOB_NAME:-job}" class="${JOB_CLASS:-${QUEUE_CLASS_NAME:-DEFAULT}}" cmd
    cmd="$(_queue_security_guidance_command_for_current_job)"
    printf '    queue submit %q --class %q' "$name" "$class"
    if [[ -n "$flag1" ]]; then
        if [[ -n "$value1" ]]; then printf ' %s %q' "$flag1" "$value1"; else printf ' %s' "$flag1"; fi
    fi
    if [[ -n "$flag2" ]]; then
        if [[ -n "$value2" ]]; then printf ' %s %q' "$flag2" "$value2"; else printf ' %s' "$flag2"; fi
    fi
    if [[ -n "$cmd" ]]; then
        printf ' -- %s\n' "$cmd"
    else
        printf ' -- <original-command>\n'
    fi
}

_queue_security_guidance_probe_preflight_for_current_job() {
    # Explain-time probe only.  The existing class/asset preflight is already
    # the source of truth; this captures its first blocking line so explain can
    # show the exact job-level exception operator command.
    local output line asset=""
    output="$(_queue_asset_implied_preflight_for_class 2>&1 || true)"
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        case "$line" in
            asset_exception_applied:*) continue ;;
        esac
        if [[ "$line" == *asset=* ]]; then
            asset="${line#*asset=}"
            asset="${asset%% *}"
        elif [[ "$line" == asset_check_blocked:* ]]; then
            asset="${line#asset_check_blocked: }"
            asset="${asset%% *}"
        fi
        if [[ -n "$asset" ]]; then
            printf '%s\t%s\n' "$asset" "$line"
            return 0
        fi
    done <<< "$output"
    return 1
}

_queue_security_exception_guidance_for_job() {
    local id="${1:-}" jobf="${2:-}" log_file="${3:-}"
    [[ -n "$id" && -n "$jobf" && -f "$jobf" ]] || return 0

    (
        JOB_ID="$id"
        COMMAND=()
        JOB_NAME=""
        JOB_CLASS=""
        SANDBOX_LEVEL=""
        SECCOMP_PROFILE=""
        SECCOMP_ALLOW=""
        RUNTIME_CAPS=""
        RUNTIME_CAP_PORTS=""
        EXCEPTION_SANDBOX_OVERRIDE=""
        EXCEPTION_SECCOMP_ALLOW=""
        EXCEPTION_DROP_CAP=""
        EXCEPTION_ADD_PORT=""
        RUNTIME_CAP_VIOLATED=""
        RUNTIME_CAP_VIOLATION=""
        EXIT_CODE=""
        source "$jobf" >/dev/null 2>&1 || exit 0

        local any=0 violation="${RUNTIME_CAP_VIOLATION:-}" cmd log_tail port probe_asset probe_line sandbox_reason=""
        cmd="$(_queue_security_guidance_command_for_current_job)"
        [[ -n "$log_file" && -f "$log_file" ]] && log_tail="$(_queue_log_tail_text "$log_file" 80 2>/dev/null || true)"

        echo
        echo "Security exception guidance"

        case "$violation" in
            no-spawn-shell*)
                echo "  runtime cap blocked a child shell. Smallest explicit exception:"
                echo "    --drop-cap no-spawn-shell"
                _queue_security_guidance_print_submit --drop-cap no-spawn-shell
                any=1
                ;;
            no-network-tools*)
                echo "  runtime cap blocked a network client/tool. Smallest explicit exception:"
                echo "    --drop-cap no-network-tools"
                _queue_security_guidance_print_submit --drop-cap no-network-tools
                any=1
                ;;
            no-network-sockets*)
                echo "  runtime cap blocked socket creation. Smallest explicit exception:"
                echo "    --drop-cap no-network-sockets"
                _queue_security_guidance_print_submit --drop-cap no-network-sockets
                any=1
                ;;
            only-local-sockets*)
                echo "  runtime cap blocked a non-local socket. Smallest explicit exception:"
                echo "    --drop-cap only-local-sockets"
                _queue_security_guidance_print_submit --drop-cap only-local-sockets
                any=1
                ;;
            only-port*)
                port="$(_queue_security_guidance_extract_port "$violation" 2>/dev/null || true)"
                [[ -z "$port" ]] && port="$(_queue_security_guidance_extract_port "$log_tail" 2>/dev/null || true)"
                echo "  runtime cap blocked a socket outside the allowed port list. Smallest explicit exception:"
                if [[ -n "$port" ]]; then
                    echo "    --add-port $port"
                    _queue_security_guidance_print_submit --add-port "$port"
                else
                    echo "    --add-port <required-port>"
                    _queue_security_guidance_print_submit --add-port "<required-port>"
                fi
                any=1
                ;;
        esac

        if [[ "$any" -eq 0 ]]; then
            if [[ " ${SANDBOX_LEVEL:-} " =~ [[:space:]](network-none|strict)[[:space:]] ]] && \
               { [[ "$cmd" =~ (^|[[:space:]])(curl|wget|nc|ncat|netcat|socat|telnet|ssh|scp|sftp|rsync)([[:space:]]|$) ]] || \
                 grep -Eiq 'network is unreachable|temporary failure in name resolution|could not resolve host|name or service not known|no route to host|private.?network|dns' <<< "$log_tail"; }; then
                sandbox_reason="${SANDBOX_LEVEL:-strict} blocks external networking"
                echo "  sandbox likely blocked network access ($sandbox_reason). Smallest explicit exception:"
                echo "    --sandbox-override off"
                _queue_security_guidance_print_submit --sandbox-override off
                any=1
            fi
        fi

        if [[ "$any" -eq 0 && " ${SECCOMP_PROFILE:-} " =~ [[:space:]]strict[[:space:]] ]]; then
            if grep -Eiq 'operation not permitted|system call|seccomp|strace|ptrace|keyctl|mount|unshare|clone3' <<< "$log_tail"; then
                echo "  seccomp may have blocked a syscall. Start with the narrow systemd syscall group required by the tool."
                echo "  Common debug exception:"
                echo "    --seccomp-allow @debug"
                _queue_security_guidance_print_submit --seccomp-allow @debug
                any=1
            fi
        fi

        if [[ "$any" -eq 0 && "$(_queue_job_state_for_file "$jobf" 2>/dev/null || true)" == "pending" ]]; then
            if _queue_class_load_for_job "$jobf" >/dev/null 2>&1; then
                IFS=$'\t' read -r probe_asset probe_line < <(_queue_security_guidance_probe_preflight_for_current_job || true)
                if [[ -n "$probe_asset" ]]; then
                    echo "  class/asset preflight is currently blocking this job:"
                    echo "    $probe_line"
                    echo "  Exact job-local exception overlay:"
                    printf '    queue exception add %q %q --reason %q\n' "$id" "$probe_asset" "approved one-off exception for this job"
                    any=1
                fi
            fi
        fi

        if [[ "$any" -eq 0 ]]; then
            echo "  none inferred"
            echo "  No specific security exception could be inferred from the job record/log yet."
        else
            echo "  note: prefer the narrowest exception; avoid editing class defaults unless this should become policy."
        fi
    )
}

_queue_exception_explain_for_job() {
    local id="${1:-}"
    local f jobf
    local now_epoch created_epoch age

    [[ -n "$id" ]] || return 0
    f="$(_queue_exception_file "$id")"
    jobf="$(_queue_job_file_by_id_any_state "$id" 2>/dev/null || true)"

    echo
    echo "Exception overlays"

    local any_job_exception=0
    local sandbox_override seccomp_allow drop_cap add_port
    local sandbox_from seccomp_profile caps_from ports_from
    local exemption_type exemption_detail exemption_code exemption_action

    if [[ -n "$jobf" && -f "$jobf" ]]; then
        sandbox_override="$(_queue_job_var_value "$jobf" EXCEPTION_SANDBOX_OVERRIDE 2>/dev/null || true)"
        seccomp_allow="$(_queue_job_var_value "$jobf" EXCEPTION_SECCOMP_ALLOW 2>/dev/null || true)"
        drop_cap="$(_queue_job_var_value "$jobf" EXCEPTION_DROP_CAP 2>/dev/null || true)"
        add_port="$(_queue_job_var_value "$jobf" EXCEPTION_ADD_PORT 2>/dev/null || true)"
        sandbox_from="$(_queue_job_var_value "$jobf" SANDBOX_POLICY_NAME 2>/dev/null || true)"
        seccomp_profile="$(_queue_job_var_value "$jobf" SECCOMP_POLICY_NAME 2>/dev/null || true)"
        caps_from="$(_queue_job_var_value "$jobf" RUNTIME_CAPS 2>/dev/null || true)"
        ports_from="$(_queue_job_var_value "$jobf" RUNTIME_CAP_PORTS 2>/dev/null || true)"
        exemption_type="$(_queue_job_var_value "$jobf" SECURITY_EXEMPTION_TYPE 2>/dev/null || true)"
        exemption_detail="$(_queue_job_var_value "$jobf" SECURITY_EXEMPTION_DETAIL 2>/dev/null || true)"
        exemption_code="$(_queue_job_var_value "$jobf" SECURITY_AUTHORISATION_CODE 2>/dev/null || true)"
        exemption_action="$(_queue_job_var_value "$jobf" SECURITY_EXEMPTION_ACTION 2>/dev/null || true)"
    else
        # Fallback for callers that deliberately source a job before calling this helper.
        sandbox_override="${EXCEPTION_SANDBOX_OVERRIDE:-}"
        seccomp_allow="${EXCEPTION_SECCOMP_ALLOW:-}"
        drop_cap="${EXCEPTION_DROP_CAP:-}"
        add_port="${EXCEPTION_ADD_PORT:-}"
        sandbox_from="${SANDBOX_POLICY_NAME:-}"
        seccomp_profile="${SECCOMP_POLICY_NAME:-}"
        caps_from="${RUNTIME_CAPS:-}"
        ports_from="${RUNTIME_CAP_PORTS:-}"
        exemption_type="${SECURITY_EXEMPTION_TYPE:-}"
        exemption_detail="${SECURITY_EXEMPTION_DETAIL:-}"
        exemption_code="${SECURITY_AUTHORISATION_CODE:-}"
        exemption_action="${SECURITY_EXEMPTION_ACTION:-}"
    fi

    if [[ -n "$sandbox_override" ]]; then
        echo "  sandbox:           OVERRIDE ${sandbox_from:-class-default} -> $sandbox_override via job flag"
        any_job_exception=1
    fi
    if [[ -n "$seccomp_allow" ]]; then
        echo "  seccomp:           HOLE PUNCHED allowing '$seccomp_allow'${seccomp_profile:+ on $seccomp_profile}"
        any_job_exception=1
    fi
    if [[ -n "$drop_cap" ]]; then
        echo "  runtime caps:      REMOVED '$drop_cap'${caps_from:+ from $caps_from}"
        any_job_exception=1
    fi
    if [[ -n "$add_port" ]]; then
        echo "  runtime ports:     ADDED '$add_port'${ports_from:+ to $ports_from}"
        any_job_exception=1
    fi
    if [[ -n "$exemption_type" ]]; then
        echo "  exemption:         $exemption_type"
        [[ -n "$exemption_action" ]] && echo "    action:          $exemption_action"
        [[ -n "$exemption_detail" ]] && echo "    detail:          $exemption_detail"
        [[ -n "$exemption_code" ]] && echo "    authorisation:   $exemption_code"
        any_job_exception=1
    fi

    if [[ ! -f "$f" ]]; then
        [[ "$any_job_exception" -eq 0 ]] && echo "  none"
        return 0
    fi

    while IFS=$'\t' read -r key reason created_at created_by expires_at; do
        [[ -n "$key" ]] || continue
        [[ "$key" == \#* ]] && continue

        age=""
        if [[ -n "$created_at" ]]; then
            now_epoch="$(date +%s 2>/dev/null || echo 0)"
            created_epoch="$(date -d "$created_at" +%s 2>/dev/null || echo 0)"
            if [[ "$now_epoch" =~ ^[0-9]+$ && "$created_epoch" =~ ^[0-9]+$ && "$created_epoch" -gt 0 && "$now_epoch" -ge "$created_epoch" ]]; then
                age="$((now_epoch - created_epoch))s"
            fi
        fi

        echo "  ignore:            $key"
        echo "    reason:          ${reason:-not-recorded}"
        echo "    by:              ${created_by:-unknown}"
        echo "    created:         ${created_at:-unknown}${age:+ (age $age)}"
        echo "    expires:         ${expires_at:-never}"
    done < "$f"
}

_queue_exception_list_all() {
    local dir f id count first
    dir="$(_queue_exception_dir)"

    [[ -d "$dir" ]] || return 0

    for f in "$dir"/*.env; do
        [[ -f "$f" ]] || continue
        id="${f##*/}"
        id="${id%.env}"
        count="$(awk 'NF { n++ } END { print n+0 }' "$f" 2>/dev/null)"
        first="$(awk -F '\t' 'NF { print $1 ": " $2; exit }' "$f" 2>/dev/null)"
        printf '%s	%s	%s
' "$id" "${count:-0}" "$first"
    done
}

_queue_exception_command() {
    local sub="${1:-list}"
    shift || true

    case "$sub" in
        add) _queue_exception_add "$@" ;;
        list|show) _queue_exception_list "$@" ;;
        list-all|all|jobs) _queue_exception_list_all "$@" ;;
        clear|remove|rm) _queue_exception_clear "$@" ;;
        clear-all|remove-all) _queue_exception_clear_all "$@" ;;
        *)
            echo "Usage: queue exception add|list|list-all|clear|clear-all ..." >&2
            return 2
            ;;
    esac
}

_queue_asset_implied_preflight_for_class() {
    local asset rc

    for asset in $CLASS_EXCLUSIVE_ASSETS $CLASS_SHARED_ASSETS; do
        [[ -z "$asset" ]] && continue
        if _queue_exception_is_allowed_for_asset "$asset"; then
            _queue_log_event "exception_applied" "$(_queue_exception_job_id_from_current_context 2>/dev/null || echo unknown)" "$asset" "pending" "asset=$asset exception=${QUEUEBASH_EXCEPTION_MATCH_KEY:-} reason=${QUEUEBASH_EXCEPTION_MATCH_REASON:-} by=${QUEUEBASH_EXCEPTION_MATCH_BY:-} at=${QUEUEBASH_EXCEPTION_MATCH_AT:-}"
            continue
        fi
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
            43)
                echo "asset_preflight_blocked: helper_contract_failed asset=$asset"
                return "$rc"
                ;;
            *)
                echo "asset_preflight_blocked: asset=$asset rc=$rc"
                return "$rc"
                ;;
        esac
    done

    local spec spec_asset
    for spec in "${QUEUE_CLASS_EXCLUSIVE_ASSET_SPECS[@]}" "${QUEUE_CLASS_SHARED_ASSET_SPECS[@]}"; do
        [[ -z "$spec" ]] && continue
        spec_asset="$(_queue_class_asset_claim_token_from_spec "$spec")"
        if _queue_exception_is_allowed_for_asset "$spec_asset"; then
            _queue_log_event "exception_applied" "$(_queue_exception_job_id_from_current_context 2>/dev/null || echo unknown)" "$spec_asset" "pending" "asset=$spec_asset exception=${QUEUEBASH_EXCEPTION_MATCH_KEY:-} reason=${QUEUEBASH_EXCEPTION_MATCH_REASON:-} by=${QUEUEBASH_EXCEPTION_MATCH_BY:-} at=${QUEUEBASH_EXCEPTION_MATCH_AT:-}"
            continue
        fi
        _queue_asset_implied_preflight_spec "$spec"
        rc="$?"
        case "$rc" in
            0) ;;
            41)
                echo "asset_preflight_blocked: unpublished_facility asset=$spec_asset"
                return "$rc"
                ;;
            42)
                echo "asset_preflight_blocked: missing_check_function asset=$spec_asset"
                return "$rc"
                ;;
            43)
                echo "asset_preflight_blocked: helper_contract_failed asset=$spec_asset"
                return "$rc"
                ;;
            *)
                echo "asset_preflight_blocked: asset=$spec_asset rc=$rc"
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


_queue_class_export_job_context() {
    local f="$1"
    local workdir idx val abs job_id job_name

    [[ -f "$f" ]] || return 0

    (
        JOB_ID=""
        JOB_NAME=""
        PWD_AT_SUBMIT=""
        COMMAND=()
        source "$f" >/dev/null 2>&1 || exit 0

        job_id="${JOB_ID:-$(basename "$f" .job)}"
        job_name="${JOB_NAME:-}"
        workdir="${PWD_AT_SUBMIT:-$PWD}"

        printf 'QUEUEBASH_CLASS_JOB_ID=%q\n' "$job_id"
        printf 'QUEUEBASH_CLASS_JOB_NAME=%q\n' "$job_name"
        printf 'QUEUEBASH_JOB_WORKDIR=%q\n' "$workdir"
        printf 'QUEUEBASH_COMMAND_COUNT=%q\n' "${#COMMAND[@]}"

        for idx in "${!COMMAND[@]}"; do
            val="${COMMAND[$idx]}"
            printf 'QUEUEBASH_COMMAND_%s=%q\n' "$idx" "$val"

            if (( idx > 0 )); then
                printf 'QUEUEBASH_COMMAND_ARG_%s=%q\n' "$idx" "$val"
                case "$val" in
                    /*) abs="$val" ;;
                    *)  abs="$workdir/$val" ;;
                esac
                printf 'QUEUEBASH_COMMAND_ARG_%s_ABSPATH=%q\n' "$idx" "$abs"
            fi
        done
    )
}



# -----------------------------------------------------------------------------
# User queue selection
# -----------------------------------------------------------------------------
_queue_home_for_user() {
    local user="${1:-}"
    [[ -n "$user" ]] || return 1
    getent passwd "$user" 2>/dev/null | awk -F: '{print $6; exit}'
}

_queue_root_for_user() {
    local user="${1:-}"
    local home
    home="$(_queue_home_for_user "$user")" || return 1
    [[ -n "$home" ]] || return 1
    printf '%s/.queuebash\n' "$home"
}

_queue_user_exists() {
    local user="${1:-}"
    [[ -n "$user" ]] || return 1
    getent passwd "$user" >/dev/null 2>&1
}

_queue_select_user_queue() {
    local user="${1:-}"
    local user_home selected_root

    _queue_user_exists "$user" || {
        echo "queue user: no such user: $user" >&2
        return 2
    }

    user_home="$(_queue_home_for_user "$user")" || {
        echo "queue user: cannot determine home for user: $user" >&2
        return 2
    }
    [[ -n "$user_home" ]] || {
        echo "queue user: empty home for user: $user" >&2
        return 2
    }

    selected_root="${user_home}/.queuebash"
    export QUEUEBASH_SELECTED_USER="$user"
    export QUEUEBASH_SELECTED_ROOT="$selected_root"
    export QUEUEBASH_ROOT="$selected_root"
    return 0
}

_queue_selected_user_for_display() {
    if [[ -n "${QUEUEBASH_SELECTED_USER:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_SELECTED_USER"
        return 0
    fi

    if declare -F _queue_root_owner_user >/dev/null 2>&1; then
        _queue_root_owner_user 2>/dev/null && return 0
    fi

    id -un 2>/dev/null || printf 'unknown\n'
}

# -----------------------------------------------------------------------------
# Draft jobs
# -----------------------------------------------------------------------------
_queue_draft_dir() {
    printf '%s/drafts\n' "$(_queue_root)"
}

_queue_draft_archive_dir() {
    printf '%s/drafts/.archive\n' "$(_queue_root)"
}

_queue_draft_id() {
    printf 'DRAFT-%s-%06d\n' "$(date +%Y%m%d_%H%M%S 2>/dev/null || date +%s)" "$(( RANDOM % 1000000 ))"
}

_queue_draft_file() {
    local id="$1"
    printf '%s/%s.env\n' "$(_queue_draft_dir)" "$id"
}

_queue_draft_init() {
    mkdir -p "$(_queue_draft_dir)" "$(_queue_draft_archive_dir)"
}

_queue_job_file_for_id_any_state() {
    local id="$1"
    local state f
    for state in pending running done failed pol_block policy_blocked cancelled deleted interrupted; do
        f="$(_queue_root)/$state/$id.job"
        [[ -f "$f" ]] && { printf '%s\n' "$f"; return 0; }
    done
    return 1
}

_queue_draft_shell_quote_array_from_command_line() {
    local command_line="$1"
    # Best-effort fallback for explain-only command strings.
    # shellcheck disable=SC2206
    local parts=( $command_line )
    printf 'COMMAND=('
    local p
    for p in "${parts[@]}"; do
        printf ' %q' "$p"
    done
    printf ' )\n'
}


_queue_draft_create() {
    local name="${1:-}"
    local priority=10
    local job_class=""
    local submit_user=""
    local pwd_at_submit=""
    local not_before_text=""
    local not_before_epoch=0
    local schedule_label=""
    local retries_max=0
    local retry_backoff=0
    local runner=""
    local sandbox_level=""
    local cpu_limit=""
    local mem_limit=""
    local max_log_size_bytes=""
    local depends_after_success=()
    local inherit_env_from=()
    local on_success=()
    local on_failure=()
    local on_retry_failure=()
    local draft_id draft_file now delay_seconds

    [[ -n "$name" ]] || { echo "Usage: queue draft create <name> [options] -- <command...>" >&2; return 2; }
    shift || true

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --priority|-p)
                [[ -n "${2:-}" ]] || { echo "queue draft create: --priority needs a value" >&2; return 2; }
                priority="$2"
                shift 2
                ;;
            --class|--queue-class)
                [[ -n "${2:-}" ]] || { echo "queue draft create: $1 needs a class name" >&2; return 2; }
                job_class="$2"
                shift 2
                ;;
            --submit-user|--user)
                [[ -n "${2:-}" ]] || { echo "queue draft create: $1 needs a user" >&2; return 2; }
                submit_user="$2"
                shift 2
                ;;
            --cwd|--pwd|--execution-dir)
                [[ -n "${2:-}" ]] || { echo "queue draft create: $1 needs a directory" >&2; return 2; }
                pwd_at_submit="$2"
                shift 2
                ;;
            --not-before)
                [[ -n "${2:-}" ]] || { echo "queue draft create: --not-before needs a value" >&2; return 2; }
                not_before_text="$2"
                schedule_label="$2"
                if [[ "$not_before_text" == @* ]]; then
                    not_before_epoch="${not_before_text#@}"
                elif [[ "$not_before_text" == +* ]]; then
                    delay_seconds="$(_queue_parse_delay_seconds "${not_before_text#+}")" || {
                        echo "queue draft create: invalid --not-before delay: $not_before_text" >&2
                        return 2
                    }
                    not_before_epoch="$(( $(_queue_now_epoch) + delay_seconds ))"
                else
                    not_before_epoch="$(_queue_parse_at_epoch "$not_before_text")" || {
                        echo "queue draft create: invalid --not-before: $not_before_text" >&2
                        return 2
                    }
                fi
                shift 2
                ;;
            --retries)
                [[ -n "${2:-}" ]] || { echo "queue draft create: --retries needs a value" >&2; return 2; }
                retries_max="$2"
                shift 2
                ;;
            --backoff|--retry-delay)
                [[ -n "${2:-}" ]] || { echo "queue draft create: --backoff needs a value" >&2; return 2; }
                retry_backoff="$2"
                shift 2
                ;;
            --runner)
                [[ -n "${2:-}" ]] || { echo "queue draft create: --runner needs a value" >&2; return 2; }
                runner="$2"
                shift 2
                ;;
            --sandbox)
                [[ -n "${2:-}" ]] || { echo "queue draft create: --sandbox needs a value" >&2; return 2; }
                case "$2" in off|none) sandbox_level="off" ;;
                            network-none|restrict-egress|strict) sandbox_level="$2" ;; *) echo "queue draft create: invalid --sandbox: $2" >&2; return 2 ;; esac
                shift 2
                ;;
            --cpu)
                [[ -n "${2:-}" ]] || { echo "queue draft create: --cpu needs a value" >&2; return 2; }
                cpu_limit="$2"
                shift 2
                ;;
            --mem|--memory)
                [[ -n "${2:-}" ]] || { echo "queue draft create: --mem needs a value" >&2; return 2; }
                mem_limit="$2"
                shift 2
                ;;
            --max-log-size)
                [[ -n "${2:-}" ]] || { echo "queue draft create: --max-log-size needs a value" >&2; return 2; }
                max_log_size_bytes="$(_queue_parse_size_to_bytes "$2")"
                [[ "$max_log_size_bytes" -gt 0 ]] || { echo "queue draft create: invalid --max-log-size: $2" >&2; return 2; }
                shift 2
                ;;
            --after-success|--after|--depends-on)
                [[ -n "${2:-}" ]] || { echo "queue draft create: $1 needs a QID or exact job name" >&2; return 2; }
                depends_after_success+=( "$2" )
                shift 2
                ;;
            --inherit-env-from|--inherit-env)
                [[ -n "${2:-}" ]] || { echo "queue draft create: $1 needs a source job QID/name" >&2; return 2; }
                inherit_env_from+=( "$2" )
                if ! _queue_array_contains "$2" "${depends_after_success[@]}"; then
                    depends_after_success+=( "$2" )
                fi
                shift 2
                ;;
            --on-success)
                shift
                on_success=()
                while [[ "$#" -gt 0 && "$1" != "--on-failure" && "$1" != "--on-retry-failure" && "$1" != "--on-attempt-failure" && "$1" != "--priority" && "$1" != "-p" && "$1" != "--" ]]; do
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
                echo "queue draft create: unexpected argument before -- : $1" >&2
                echo "Usage: queue draft create <name> [--priority N] [--class CLASS] [--submit-user USER] [--cwd DIR] [--not-before WHEN] [--retries N] [--backoff SEC] [--runner auto|direct|systemd] [--cpu PCT] [--mem SIZE] [--max-log-size SIZE] [--after-success QID] [--inherit-env-from QID] [--on-success <cmd...>] [--on-retry-failure <cmd...>] [--on-failure <cmd...>] -- <command...>" >&2
                return 2
                ;;
        esac
    done

    [[ "$#" -gt 0 ]] || { echo "queue draft create: missing command after --" >&2; return 2; }
    [[ "$priority" =~ ^-?[0-9]+$ ]] || priority=10
    [[ "$retries_max" =~ ^[0-9]+$ ]] || retries_max=0
    [[ "$retry_backoff" =~ ^[0-9]+$ ]] || retry_backoff=0

    _queue_draft_init
    draft_id="$(_queue_draft_id)"
    draft_file="$(_queue_draft_file "$draft_id")"
    now="$(_queue_now_iso)"

    {
        printf '# queuebash draft: %q\n' "$draft_id"
        printf 'DRAFT_ID=%q\n' "$draft_id"
        printf 'DRAFT_STATE=%q\n' "draft"
        printf 'DRAFT_NAME=%q\n' "$name"
        printf 'DRAFT_CREATED_AT=%q\n' "$now"
        printf 'DRAFT_UPDATED_AT=%q\n' "$now"
        printf 'DRAFT_SOURCE=%q\n' "panel-task-creator"
        printf 'DRAFT_SOURCE_QUEUE_USER=%q\n' "${QUEUEBASH_SELECTED_USER:-}"
        printf '\n'
        printf 'JOB_NAME=%q\n' "$name"
        printf 'PRIORITY=%q\n' "$priority"
        printf 'JOB_CLASS=%q\n' "$job_class"
        printf 'SUBMIT_USER=%q\n' "$submit_user"
        printf 'PWD_AT_SUBMIT=%q\n' "$pwd_at_submit"
        printf 'NOT_BEFORE_EPOCH=%q\n' "$not_before_epoch"
        [[ -n "$not_before_text" ]] && printf 'NOT_BEFORE_TEXT=%q\n' "$not_before_text"
        [[ -n "$schedule_label" ]] && printf 'SCHEDULE_LABEL=%q\n' "$schedule_label"
        printf 'RETRIES_MAX=%q\n' "$retries_max"
        printf 'RETRY_BACKOFF=%q\n' "$retry_backoff"
        printf 'RUNNER=%q\n' "$runner"
        printf 'SANDBOX_LEVEL=%q\n' "$sandbox_level"
        printf 'CPU_LIMIT=%q\n' "$cpu_limit"
        printf 'MEM_LIMIT=%q\n' "$mem_limit"
        printf 'MAX_LOG_SIZE_BYTES=%q\n' "$max_log_size_bytes"
        printf 'DEPENDS_AFTER_SUCCESS=('
        local dep
        for dep in "${depends_after_success[@]}"; do
            printf ' %q' "$dep"
        done
        printf ' )\n'
        printf 'INHERIT_ENV_FROM=('
        for dep in "${inherit_env_from[@]}"; do
            printf ' %q' "$dep"
        done
        printf ' )\n'
        printf 'ON_SUCCESS=('
        local hook_part
        for hook_part in "${on_success[@]}"; do
            printf ' %q' "$hook_part"
        done
        printf ' )\n'
        printf 'ON_FAILURE=('
        for hook_part in "${on_failure[@]}"; do
            printf ' %q' "$hook_part"
        done
        printf ' )\n'
        printf 'ON_RETRY_FAILURE=('
        for hook_part in "${on_retry_failure[@]}"; do
            printf ' %q' "$hook_part"
        done
        printf ' )\n'
        printf 'COMMAND=('
        local part
        for part in "$@"; do
            printf ' %q' "$part"
        done
        printf ' )\n'
    } > "$draft_file"

    echo "Created draft $draft_id"
    echo "$draft_file"
}

_queue_draft_create_from_job() {
    local id="${1:-}"
    local draft_id source_file draft_file now
    [[ -n "$id" ]] || { echo "Usage: queue draft create-from-job <qid>" >&2; return 2; }

    source_file="$(_queue_job_file_for_id_any_state "$id")" || {
        echo "queue draft create-from-job: job not found: $id" >&2
        return 1
    }

    _queue_draft_init
    draft_id="$(_queue_draft_id)"
    draft_file="$(_queue_draft_file "$draft_id")"
    now="$(_queue_now_iso)"

    {
        echo "# queuebash draft: $draft_id"
        echo "DRAFT_ID=$(printf '%q' "$draft_id")"
        echo "DRAFT_STATE=draft"
        echo "DRAFT_NAME=$(printf '%q' "Copy of $id")"
        echo "DRAFT_CREATED_AT=$(printf '%q' "$now")"
        echo "DRAFT_UPDATED_AT=$(printf '%q' "$now")"
        echo "DRAFT_SOURCE_JOB_ID=$(printf '%q' "$id")"
        echo "DRAFT_SOURCE_QUEUE_USER=$(printf '%q' "${QUEUEBASH_SELECTED_USER:-}")"
        echo

        awk '
            /^JOB_ID=/ { next }
            /^RUN_PID=/ { next }
            /^RUN_PGID=/ { next }
            /^RUN_STARTED_AT=/ { next }
            /^RUN_FINISHED_AT=/ { next }
            /^STARTED_AT=/ { next }
            /^FINISHED_AT=/ { next }
            /^EXIT_CODE=/ { next }
            /^RUNNER_USED=/ { next }
            /^SYSTEMD_UNIT=/ { next }
            /^JOB_CLASS_CLAIMED=/ { next }
            /^JOB_CLASS_CLAIMED_AT=/ { next }
            /^CLASS_DEFAULTS_APPLIED_AT=/ { next }
            /^CLASS_DEFAULTS_SOURCE=/ { print; next }
            { print }
        ' "$source_file"
    } > "$draft_file"

    echo "Created draft $draft_id from job $id"
    echo "$draft_file"
}

_queue_draft_list() {
    _queue_draft_init
    printf '%-34s %-10s %-22s %-20s %s\n' "DRAFT_ID" "STATE" "UPDATED" "JOB_NAME" "COMMAND"
    local f
    for f in "$(_queue_draft_dir)"/*.env; do
        [[ -f "$f" ]] || continue
        (
            DRAFT_ID=""
            DRAFT_STATE=""
            DRAFT_UPDATED_AT=""
            JOB_NAME=""
            COMMAND=()
            # shellcheck disable=SC1090
            source "$f" 2>/dev/null || true
            printf '%-34s %-10s %-22s %-20s %s\n' \
                "${DRAFT_ID:-$(basename "$f" .env)}" \
                "${DRAFT_STATE:-draft}" \
                "${DRAFT_UPDATED_AT:-}" \
                "${JOB_NAME:-}" \
                "$(_queue_shell_join "${COMMAND[@]}")"
        )
    done | sort
}

_queue_draft_show() {
    local id="${1:-}"
    local f
    [[ -n "$id" ]] || { echo "Usage: queue draft show <draft_id>" >&2; return 2; }
    f="$(_queue_draft_file "$id")"
    [[ -f "$f" ]] || { echo "queue draft show: not found: $id" >&2; return 1; }
    echo "=============================================================================="
    echo "QUEUEBASH DRAFT: $id"
    echo "=============================================================================="
    sed -n '1,220p' "$f"
}

_queue_draft_set_state() {
    local id="${1:-}"
    local state="${2:-}"
    local f tmp now
    [[ -n "$id" && -n "$state" ]] || { echo "Usage: queue draft state <draft_id> <draft|ready|submitted|abandoned>" >&2; return 2; }
    case "$state" in draft|ready|submitted|abandoned) ;; *) echo "queue draft state: invalid state: $state" >&2; return 2 ;; esac
    f="$(_queue_draft_file "$id")"
    [[ -f "$f" ]] || { echo "queue draft state: not found: $id" >&2; return 1; }
    tmp="${f}.tmp.$$"
    now="$(_queue_now_iso)"
    awk -v st="$state" -v now="$now" '
        BEGIN { saw_state=0; saw_updated=0 }
        /^DRAFT_STATE=/ { print "DRAFT_STATE=" st; saw_state=1; next }
        /^DRAFT_UPDATED_AT=/ { printf "DRAFT_UPDATED_AT=%q\n", now; saw_updated=1; next }
        { print }
        END {
            if (!saw_state) print "DRAFT_STATE=" st
            if (!saw_updated) printf "DRAFT_UPDATED_AT=%q\n", now
        }
    ' "$f" > "$tmp"
    mv "$tmp" "$f"
    echo "Draft $id state=$state"
}

_queue_draft_submit() {
    local id="${1:-}"
    local f job_name pri cls not_before retries backoff runner cpu mem maxlog submit_user pwd_at
    [[ -n "$id" ]] || { echo "Usage: queue draft submit <draft_id>" >&2; return 2; }
    f="$(_queue_draft_file "$id")"
    [[ -f "$f" ]] || { echo "queue draft submit: not found: $id" >&2; return 1; }

    (
        DRAFT_ID=""
        DRAFT_STATE="draft"
        JOB_NAME=""
        PRIORITY=10
        JOB_CLASS=""
        NOT_BEFORE_EPOCH=0
        NOT_BEFORE_TEXT=""
        RETRIES_MAX=0
        RETRY_BACKOFF=0
        RUNNER=""
        SANDBOX_LEVEL=""
        CPU_LIMIT=""
        MEM_LIMIT=""
        MAX_LOG_SIZE_BYTES=""
        SUBMIT_USER=""
        PWD_AT_SUBMIT=""
        DEPENDS_AFTER_SUCCESS=()
        INHERIT_ENV_FROM=()
        ON_SUCCESS=()
        ON_FAILURE=()
        ON_RETRY_FAILURE=()
        COMMAND=()

        # shellcheck disable=SC1090
        source "$f"

        if [[ "${#COMMAND[@]}" -eq 0 ]]; then
            echo "queue draft submit: draft has no COMMAND array" >&2
            exit 2
        fi

        job_name="${JOB_NAME:-${DRAFT_NAME:-draft_job}}"
        job_name="${job_name// /_}"

        args=(submit "$job_name" --priority "${PRIORITY:-10}")
        [[ -n "${JOB_CLASS:-}" ]] && args+=(--class "$JOB_CLASS")
        [[ -n "${RUNNER:-}" ]] && args+=(--runner "$RUNNER")
        [[ -n "${SANDBOX_LEVEL:-}" ]] && args+=(--sandbox "$SANDBOX_LEVEL")
        [[ -n "${CPU_LIMIT:-}" ]] && args+=(--cpu "$CPU_LIMIT")
        [[ -n "${MEM_LIMIT:-}" ]] && args+=(--mem "$MEM_LIMIT")
        [[ -n "${MAX_LOG_SIZE_BYTES:-}" ]] && args+=(--max-log-size "$MAX_LOG_SIZE_BYTES")
        [[ -n "${RETRIES_MAX:-}" && "${RETRIES_MAX:-0}" != "0" ]] && args+=(--retries "$RETRIES_MAX")
        [[ -n "${RETRY_BACKOFF:-}" && "${RETRY_BACKOFF:-0}" != "0" ]] && args+=(--backoff "$RETRY_BACKOFF")
        if [[ -n "${NOT_BEFORE_TEXT:-}" ]]; then
            args+=(--not-before "$NOT_BEFORE_TEXT")
        elif [[ -n "${NOT_BEFORE_EPOCH:-}" && "${NOT_BEFORE_EPOCH:-0}" != "0" ]]; then
            args+=(--not-before "@$NOT_BEFORE_EPOCH")
        fi
        local dep
        for dep in "${DEPENDS_AFTER_SUCCESS[@]}"; do
            [[ -n "$dep" ]] && args+=(--after-success "$dep")
        done
        for dep in "${INHERIT_ENV_FROM[@]}"; do
            [[ -n "$dep" ]] && args+=(--inherit-env-from "$dep")
        done
        if [[ "${#ON_RETRY_FAILURE[@]}" -gt 0 ]]; then
            args+=(--on-retry-failure "${ON_RETRY_FAILURE[@]}")
        fi
        if [[ "${#ON_SUCCESS[@]}" -gt 0 ]]; then
            args+=(--on-success "${ON_SUCCESS[@]}")
        fi
        if [[ "${#ON_FAILURE[@]}" -gt 0 ]]; then
            args+=(--on-failure "${ON_FAILURE[@]}")
        fi
        args+=(-- "${COMMAND[@]}")

        if [[ -n "${PWD_AT_SUBMIT:-}" ]]; then
            cd "$PWD_AT_SUBMIT" || {
                echo "queue draft submit: cannot cd to PWD_AT_SUBMIT=$PWD_AT_SUBMIT" >&2
                exit 98
            }
        fi

        if [[ -n "${SUBMIT_USER:-}" && "${SUBMIT_USER:-}" != "current" && "$(id -u 2>/dev/null || echo 99999)" == "0" ]]; then
            exec runuser -u "$SUBMIT_USER" -- bash -lc "$(printf 'export QUEUEBASH_ALLOW_NONINTERACTIVE=1; export QUEUEBASH_ROOT=%q; source %q >/dev/null 2>&1; queue' "$(_queue_root)" "${BASH_SOURCE[0]}")$(printf ' %q' "${args[@]}")"
        fi

        queue "${args[@]}"
    )
    local rc=$?
    if [[ "$rc" -eq 0 ]]; then
        _queue_draft_set_state "$id" submitted >/dev/null || true
    fi
    return "$rc"
}

_queue_draft_abandon() {
    local id="${1:-}"
    [[ -n "$id" ]] || { echo "Usage: queue draft abandon <draft_id>" >&2; return 2; }
    _queue_draft_set_state "$id" abandoned
}

_queue_draft_command() {
    local sub="${1:-list}"
    shift || true
    case "$sub" in
        list|ls) _queue_draft_list "$@" ;;
        show|cat|explain) _queue_draft_show "$@" ;;
        create|new|save) _queue_draft_create "$@" ;;
        create-from-job|copy-from-job) _queue_draft_create_from_job "$@" ;;
        submit) _queue_draft_submit "$@" ;;
        state) _queue_draft_set_state "$@" ;;
        ready) _queue_draft_set_state "${1:-}" ready ;;
        abandon) _queue_draft_abandon "$@" ;;
        *) echo "Usage: queue draft list|show <id>|create <name> [options] -- <command...>|create-from-job <qid>|submit <id>|ready <id>|abandon <id>|state <id> <state>" >&2; return 2 ;;
    esac
}


_queue_current_shell_user_for_display() {
    id -un 2>/dev/null || whoami 2>/dev/null || printf 'unknown\n'
}

_queue_has_selected_user_context() {
    [[ -n "${QUEUEBASH_SELECTED_USER:-}" ]]
}

_queue_print_selected_user_banner() {
    _queue_has_selected_user_context || return 0

    local selected_user selected_root shell_user
    selected_user="$(_queue_selected_user_for_display)"
    selected_root="$(_queue_root)"
    shell_user="$(_queue_current_shell_user_for_display)"

    if [[ "$selected_user" == "$shell_user" ]]; then
        printf 'QUEUE USER: %s  root=%s\n' "$selected_user" "$selected_root"
    else
        printf 'QUEUE USER: %s  shell-user=%s  root=%s\n' "$selected_user" "$shell_user" "$selected_root"
    fi
}

# -----------------------------------------------------------------------------
# Root / user-queue safety
# -----------------------------------------------------------------------------
# Root may administer another user's queue files, but must not evaluate
# user-owned queue-local code in the root process.  Queue-local class files and
# asset helpers are executable shell code; if QUEUEBASH_ROOT belongs to another
# user, commands that source/evaluate that code are delegated to that owner.

_queue_path_owner_user() {
    local path="${1:-}"
    [[ -n "$path" ]] || return 1

    while [[ ! -e "$path" && "$path" != "/" ]]; do
        path="$(dirname "$path")"
    done

    stat -c '%U' "$path" 2>/dev/null || return 1
}

_queue_root_owner_user() {
    _queue_path_owner_user "$(_queue_root)"
}

_queue_running_as_root() {
    [[ "$(id -u 2>/dev/null || echo 99999)" == "0" ]]
}

_queue_root_is_foreign_user_queue() {
    local owner
    _queue_running_as_root || return 1
    owner="$(_queue_root_owner_user 2>/dev/null || true)"
    [[ -n "$owner" && "$owner" != "root" ]]
}

_queue_delegate_command_to_owner() {
    local owner="$1"
    shift

    [[ -n "$owner" ]] || {
        echo "queue user-queue safety: queue owner could not be determined" >&2
        return 126
    }

    if command -v runuser >/dev/null 2>&1; then
        runuser -u "$owner" -- bash -lc "$(printf 'export QUEUEBASH_ALLOW_NONINTERACTIVE=1; export QUEUEBASH_USER_QUEUE_DELEGATED=1; export QUEUEBASH_ROOT=%q; source %q >/dev/null 2>&1; queue' "$(_queue_root)" "${BASH_SOURCE[0]}")$(printf ' %q' "$@")"
        return "$?"
    fi

    if command -v sudo >/dev/null 2>&1; then
        sudo -u "$owner" bash -lc "$(printf 'export QUEUEBASH_ALLOW_NONINTERACTIVE=1; export QUEUEBASH_USER_QUEUE_DELEGATED=1; export QUEUEBASH_ROOT=%q; source %q >/dev/null 2>&1; queue' "$(_queue_root)" "${BASH_SOURCE[0]}")$(printf ' %q' "$@")"
        return "$?"
    fi

    echo "queue user-queue safety: cannot delegate to owner=$owner; runuser/sudo not found" >&2
    return 126
}

_queue_command_may_evaluate_queue_code() {
    local cmd="${1:-}"
    local sub="${2:-}"

    case "$cmd" in
        run|worker|workers|start|daemon|submit|explain)
            return 0
            ;;

        class|classes)
            case "$sub" in
                explain|validate|refresh|replace|rollback|edit|create|class-create)
                    return 0 ;;
            esac
            ;;
        asset|assets)
            case "$sub" in
                explain|validate|refresh|replace|rollback|expand)
                    return 0 ;;
            esac
            ;;
        # The panel manager itself must remain in the operator/root shell.
        # Panel actions that actually evaluate queue-local code invoke queue
        # commands separately and are guarded at that point.
    esac

    return 1
}

_queue_guard_foreign_user_queue_eval() {
    local cmd="${1:-}"
    local sub="${2:-}"
    local owner
    shift 2 || true

    [[ "${QUEUEBASH_USER_QUEUE_DELEGATED:-0}" == "1" ]] && return 0
    [[ "${QUEUEBASH_ALLOW_ROOT_USER_QUEUE_EVAL:-0}" == "1" ]] && return 0

    _queue_command_may_evaluate_queue_code "$cmd" "$sub" || return 0
    _queue_root_is_foreign_user_queue || return 0

    owner="$(_queue_root_owner_user 2>/dev/null || true)"

    if [[ "${QUEUEBASH_ROOT_USER_QUEUE_MODE:-delegate}" == "refuse" ]]; then
        echo "queue user-queue safety: refusing to evaluate queue-local code as root" >&2
        echo "queue user-queue safety: QUEUEBASH_ROOT=$(_queue_root) owner=$owner command=$cmd ${sub:-}" >&2
        echo "queue user-queue safety: rerun as $owner or set QUEUEBASH_ROOT_USER_QUEUE_MODE=delegate" >&2
        return 126
    fi

    _queue_delegate_command_to_owner "$owner" "$@"
}

_queue_class_source_with_job_context() {
    local class_file="$1"
    local job_file="$2"
    local line

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        export "$line"
    done < <(_queue_class_export_job_context "$job_file")

    source "$class_file"
}


# -----------------------------------------------------------------------------
# Global cross-user resource claims
# -----------------------------------------------------------------------------
# Phase 1 implementation: data-only claim state under a root/admin-owned global
# root. Existing per-queue-root class/assets semantics are unchanged.

_queue_global_root() {
    printf '%s\n' "${QUEUEBASH_GLOBAL_ROOT:-/var/lib/bashqueues/global}"
}

_queue_global_claim_policy() {
    printf '%s\n' "${QUEUEBASH_GLOBAL_CLAIM_POLICY:-strict}"
}

_queue_global_enabled() {
    [[ "${QUEUEBASH_GLOBAL_CLAIMS:-1}" != "0" && "${QUEUEBASH_GLOBAL_CLAIMS:-1}" != "off" ]]
}

_queue_global_hash() {
    local key="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$key" | sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        printf '%s' "$key" | shasum -a 256 | awk '{print $1}'
    else
        printf '%s' "$key" | cksum | awk '{print $1}'
    fi
}

_queue_global_init() {
    local root="$(_queue_global_root)"
    mkdir -p "$root/claims" "$root/slots" "$root/.lock" 2>/dev/null || return 1
}

_queue_global_lock_file() {
    local claim="$1" hash
    hash="$(_queue_global_hash "$claim")"
    printf '%s/.lock/%s.lock\n' "$(_queue_global_root)" "$hash"
}

_queue_global_claim_file() {
    local claim="$1" hash
    hash="$(_queue_global_hash "$claim")"
    printf '%s/claims/%s.env\n' "$(_queue_global_root)" "$hash"
}

_queue_global_events_log() {
    printf '%s/events.jsonl\n' "$(_queue_global_root)"
}

_queue_global_json_event() {
    local event="$1" claim="$2" mode="$3" qid="$4" queue_user="$5" queue_root="$6" class="$7" job_name="$8" detail="${9:-}"
    local ts log
    _queue_global_init >/dev/null 2>&1 || return 0
    ts="$(date -Is 2>/dev/null || date)"
    log="$(_queue_global_events_log)"
    {
        printf '{"ts":"%s","event":"%s","claim":"%s","mode":"%s","qid":"%s","queue_user":"%s","queue_root":"%s","class":"%s","job_name":"%s","by_user":"%s"' \
            "$(_queue_json_escape "$ts")" "$(_queue_json_escape "$event")" "$(_queue_json_escape "$claim")" "$(_queue_json_escape "$mode")" \
            "$(_queue_json_escape "$qid")" "$(_queue_json_escape "$queue_user")" "$(_queue_json_escape "$queue_root")" \
            "$(_queue_json_escape "$class")" "$(_queue_json_escape "$job_name")" "$(_queue_json_escape "$(id -un 2>/dev/null || echo unknown)")"
        [[ -n "$detail" ]] && printf ',"detail":"%s"' "$(_queue_json_escape "$detail")"
        printf '}\n'
    } >> "$log" 2>/dev/null || true
}

_queue_global_slots_from_args() {
    local default_slots="$1" arg v
    shift || true
    for arg in "$@"; do
        case "$arg" in
            slots=*) v="${arg#slots=}"; [[ "$v" =~ ^[0-9]+$ ]] && { printf '%s\n' "$v"; return 0; } ;;
        esac
    done
    if [[ "$default_slots" =~ ^[0-9]+$ && "$default_slots" -gt 0 ]]; then
        printf '%s\n' "$default_slots"
    else
        printf '1\n'
    fi
}

_queue_global_spec_info() {
    local spec="$1" mode default_slots record_type claim family check target slots
    eval "set -- $spec"
    [[ "$#" -ge 4 ]] || return 1
    mode="$1"; default_slots="$2"; record_type="$3"; shift 3
    case "$record_type" in
        claim)
            claim="${1:-}"
            shift || true
            slots="$(_queue_global_slots_from_args "$default_slots" "$@")"
            printf '%s\t%s\t%s\t%s\t%s\n' "$mode" "$slots" "$record_type" "$claim" "$(_queue_class_asset_pack "$claim" "$@")"
            ;;
        asset)
            [[ "$#" -ge 3 ]] || return 1
            family="$1"; check="$2"; target="$3"
            claim="${family}:${check}:${target}"
            slots="$(_queue_global_slots_from_args "$default_slots" "$@")"
            printf '%s\t%s\t%s\t%s\t%s\n' "$mode" "$slots" "$record_type" "$claim" "$(_queue_class_asset_pack "$@")"
            ;;
        *) return 1 ;;
    esac
}

_queue_global_preflight_for_spec() {
    local spec="$1" mode slots record_type claim packed
    IFS=$'\t' read -r mode slots record_type claim packed < <(_queue_global_spec_info "$spec") || return 1
    if [[ "$record_type" == "asset" ]]; then
        eval "set -- $packed"
        [[ "$#" -ge 3 ]] || return 1
        local family="$1" check="$2" target="$3"
        _queue_asset_implied_preflight_args "$claim" "$@"
    fi
}

_queue_global_claim_exception_allows() {
    local claim="$1"
    if _queue_exception_is_allowed_for_asset "global:claim:$claim" >/dev/null 2>&1; then
        return 0
    fi
    if _queue_exception_is_allowed_for_asset "global:claim" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

_queue_global_claim_holder_state() {
    local qroot="$1" qid="$2" st
    for st in running pending paused done failed interrupted cancelled deleted; do
        [[ -f "$qroot/$st/$qid.job" ]] && { printf '%s\n' "$st"; return 0; }
    done
    printf 'missing\n'
}

_queue_global_claim_compact_file() {
    local file="$1" claim="$2" mode="$3" slots="$4" tmp now n=0 line qid qroot state
    [[ -f "$file" ]] || return 0
    tmp="$(mktemp)"
    now="$(date -Is 2>/dev/null || date)"
    {
        printf 'CLAIM_KEY=%q\n' "$claim"
        printf 'CLAIM_HASH=%q\n' "$(_queue_global_hash "$claim")"
        printf 'CLAIM_MODE=%q\n' "$mode"
        printf 'CLAIM_SLOTS_TOTAL=%q\n' "$slots"
        printf 'CLAIM_UPDATED_AT=%q\n' "$now"
    } > "$tmp"
    while IFS= read -r line; do
        [[ "$line" == HOLDER$'\t'* ]] || continue
        qid="$(printf '%s\n' "$line" | cut -f2)"
        qroot="$(printf '%s\n' "$line" | cut -f4)"
        state="$(_queue_global_claim_holder_state "$qroot" "$qid")"
        if [[ "$state" == "running" ]]; then
            n=$((n + 1))
            printf '%s\n' "$line" >> "$tmp"
        else
            _queue_global_json_event "global_claim_stale_removed" "$claim" "$mode" "$qid" "$(printf '%s\n' "$line" | cut -f3)" "$qroot" "$(printf '%s\n' "$line" | cut -f5)" "$(printf '%s\n' "$line" | cut -f6)" "state=$state"
        fi
    done < <(grep '^HOLDER' "$file" 2>/dev/null || true)
    mv "$tmp" "$file"
}

_queue_global_claim_holder_count() {
    local file="$1" n
    n="$(grep -c '^HOLDER' "$file" 2>/dev/null)" || n=0
    printf '%s\n' "${n:-0}"
}

_queue_global_claim_holder_summary() {
    local claim="$1" file line qid queue_user qroot class job_name pid started state out=""
    file="$(_queue_global_claim_file "$claim")"
    [[ -f "$file" ]] || return 0
    while IFS= read -r line; do
        [[ "$line" == HOLDER$'\t'* ]] || continue
        qid="$(printf '%s\n' "$line" | cut -f2)"
        queue_user="$(printf '%s\n' "$line" | cut -f3)"
        qroot="$(printf '%s\n' "$line" | cut -f4)"
        class="$(printf '%s\n' "$line" | cut -f5)"
        job_name="$(printf '%s\n' "$line" | cut -f6)"
        pid="$(printf '%s\n' "$line" | cut -f7)"
        started="$(printf '%s\n' "$line" | cut -f8)"
        state="$(_queue_global_claim_holder_state "$qroot" "$qid" 2>/dev/null || printf unknown)"
        [[ -n "$out" ]] && out+="; "
        out+="holder=${queue_user}:${qid}:${job_name:-?}:state=${state}:class=${class:-?}:pid=${pid:-?}:since=${started:-?}"
    done < <(grep '^HOLDER' "$file" 2>/dev/null || true)
    printf '%s\n' "$out"
}


_queue_global_claim_has_holder() {
    local file="$1" qid="$2" qroot="$3"
    awk -F '\t' -v qid="$qid" -v qroot="$qroot" '$1 == "HOLDER" && $2 == qid && $4 == qroot { found=1 } END { exit found ? 0 : 1 }' "$file" 2>/dev/null
}

_queue_global_claim_available_one() {
    local claim="$1" mode="$2" slots="$3" qid="${4:-}" qroot="${5:-}" lock file count rc=0
    _queue_global_enabled || return 0
    _queue_global_init || {
        [[ "$(_queue_global_claim_policy)" == "warn" || "$(_queue_global_claim_policy)" == "off" ]] && return 0
        return 1
    }
    lock="$(_queue_global_lock_file "$claim")"
    file="$(_queue_global_claim_file "$claim")"
    (
        flock -x 9 || exit 1
        [[ -f "$file" ]] || : > "$file"
        _queue_global_claim_compact_file "$file" "$claim" "$mode" "$slots"
        if [[ -n "$qid" && -n "$qroot" ]] && _queue_global_claim_has_holder "$file" "$qid" "$qroot"; then
            exit 0
        fi
        count="$(_queue_global_claim_holder_count "$file")"
        if [[ "$mode" == "exclusive" ]]; then
            (( count == 0 )) || exit 2
        else
            (( count < slots )) || exit 3
        fi
        exit 0
    ) 9>"$lock"
    rc="$?"
    return "$rc"
}

_queue_global_claims_available_for_job() {
    local f="$1" id name class spec mode slots record_type claim packed rc any=0
    id="$(basename "$f" .job)"
    name="$(_queue_job_name "$f" 2>/dev/null || true)"
    class="${QUEUE_CLASS_NAME:-$(_queue_class_name_for_job "$f")}" 
    for spec in "${QUEUE_CLASS_GLOBAL_CLAIM_SPECS[@]}"; do
        any=1
        IFS=$'\t' read -r mode slots record_type claim packed < <(_queue_global_spec_info "$spec") || return 1
        if _queue_global_claim_exception_allows "$claim"; then
            _queue_log_event "exception_applied" "$id" "$claim" "pending" "asset=global:claim:$claim reason=${QUEUEBASH_EXCEPTION_MATCH_REASON:-} by=${QUEUEBASH_EXCEPTION_MATCH_BY:-}"
            continue
        fi
        _queue_global_preflight_for_spec "$spec" || return 2
        if ! _queue_global_claim_available_one "$claim" "$mode" "$slots" "$id" "$(_queue_root)"; then
            local holders
            holders="$(_queue_global_claim_holder_summary "$claim")"
            _queue_log_event "global_claim_blocked" "$id" "$name" "pending" "claim=$claim mode=$mode slots=$slots${holders:+ $holders}"
            _queue_global_json_event "global_claim_blocked" "$claim" "$mode" "$id" "$(_queue_selected_user_for_display 2>/dev/null || id -un)" "$(_queue_root)" "$class" "$name" "slots=$slots${holders:+ $holders}"
            return 3
        fi
    done
    return 0
}

_queue_global_claim_acquire_one() {
    local claim="$1" mode="$2" slots="$3" qid="$4" qroot="$5" class="$6" job_name="$7" pid="${8:-}" lock file now count tmp
    _queue_global_enabled || return 0
    _queue_global_init || {
        [[ "$(_queue_global_claim_policy)" == "warn" || "$(_queue_global_claim_policy)" == "off" ]] && return 0
        return 1
    }
    lock="$(_queue_global_lock_file "$claim")"
    file="$(_queue_global_claim_file "$claim")"
    now="$(date -Is 2>/dev/null || date)"
    (
        flock -x 9 || exit 1
        [[ -f "$file" ]] || : > "$file"
        _queue_global_claim_compact_file "$file" "$claim" "$mode" "$slots"
        if _queue_global_claim_has_holder "$file" "$qid" "$qroot"; then
            exit 0
        fi
        count="$(_queue_global_claim_holder_count "$file")"
        if [[ "$mode" == "exclusive" ]]; then
            (( count == 0 )) || exit 2
        else
            (( count < slots )) || exit 3
        fi
        tmp="$(mktemp)"
        {
            printf 'CLAIM_KEY=%q\n' "$claim"
            printf 'CLAIM_HASH=%q\n' "$(_queue_global_hash "$claim")"
            printf 'CLAIM_MODE=%q\n' "$mode"
            printf 'CLAIM_SLOTS_TOTAL=%q\n' "$slots"
            printf 'CLAIM_CREATED_AT=%q\n' "$now"
            printf 'CLAIM_UPDATED_AT=%q\n' "$now"
            grep '^HOLDER' "$file" 2>/dev/null || true
            printf 'HOLDER\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$qid" "$(_queue_selected_user_for_display 2>/dev/null || id -un)" "$qroot" "$class" "$job_name" "${pid:-$$}" "$now"
        } > "$tmp"
        mv "$tmp" "$file"
        exit 0
    ) 9>"$lock"
}

_queue_global_claims_acquire_for_job() {
    local f="$1" id="$2" class name spec mode slots record_type claim packed acquired=()
    class="${QUEUE_CLASS_NAME:-$(_queue_class_name_for_job "$f")}" 
    name="$(_queue_job_name "$f" 2>/dev/null || true)"
    for spec in "${QUEUE_CLASS_GLOBAL_CLAIM_SPECS[@]}"; do
        IFS=$'\t' read -r mode slots record_type claim packed < <(_queue_global_spec_info "$spec") || return 1
        if _queue_global_claim_exception_allows "$claim"; then
            _queue_log_event "exception_applied" "$id" "$claim" "running" "asset=global:claim:$claim reason=${QUEUEBASH_EXCEPTION_MATCH_REASON:-} by=${QUEUEBASH_EXCEPTION_MATCH_BY:-}"
            continue
        fi
        _queue_global_preflight_for_spec "$spec" || return 2
        if _queue_global_claim_acquire_one "$claim" "$mode" "$slots" "$id" "$(_queue_root)" "$class" "$name" "${RUN_PID:-$$}"; then
            acquired+=("$claim")
            _queue_log_event "global_claim_acquired" "$id" "$name" "running" "claim=$claim mode=$mode slots=$slots"
            _queue_global_json_event "global_claim_acquired" "$claim" "$mode" "$id" "$(_queue_selected_user_for_display 2>/dev/null || id -un)" "$(_queue_root)" "$class" "$name" "slots=$slots"
        else
            _queue_log_event "global_claim_blocked" "$id" "$name" "pending" "claim=$claim mode=$mode slots=$slots acquire_failed=1"
            _queue_global_json_event "global_claim_blocked" "$claim" "$mode" "$id" "$(_queue_selected_user_for_display 2>/dev/null || id -un)" "$(_queue_root)" "$class" "$name" "slots=$slots acquire_failed=1"
            _queue_global_release_job_claims "$id" "$(_queue_root)"
            return 3
        fi
    done
    return 0
}

_queue_global_release_job_claims() {
    local qid="$1" qroot="${2:-$(_queue_root)}" root file lock claim mode slots tmp line changed queue_user class job_name
    [[ -n "$qid" ]] || return 0
    root="$(_queue_global_root)"
    [[ -d "$root/claims" ]] || return 0
    shopt -s nullglob
    for file in "$root/claims"/*.env; do
        [[ -f "$file" ]] || continue
        claim="$(grep '^CLAIM_KEY=' "$file" 2>/dev/null | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || true)"
        mode="$(grep '^CLAIM_MODE=' "$file" 2>/dev/null | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || true)"
        slots="$(grep '^CLAIM_SLOTS_TOTAL=' "$file" 2>/dev/null | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || true)"
        [[ -n "$claim" ]] || claim="$(basename "$file" .env)"
        [[ -n "$mode" ]] || mode="shared"
        [[ -n "$slots" ]] || slots=1
        lock="$root/.lock/$(basename "$file" .env).lock"
        (
            flock -x 9 || exit 0
            tmp="$(mktemp)"
            changed=0
            grep -v '^HOLDER' "$file" > "$tmp" 2>/dev/null || true
            while IFS= read -r line; do
                [[ "$line" == HOLDER$'\t'* ]] || continue
                if [[ "$(printf '%s\n' "$line" | cut -f2)" == "$qid" && "$(printf '%s\n' "$line" | cut -f4)" == "$qroot" ]]; then
                    changed=1
                    queue_user="$(printf '%s\n' "$line" | cut -f3)"
                    class="$(printf '%s\n' "$line" | cut -f5)"
                    job_name="$(printf '%s\n' "$line" | cut -f6)"
                else
                    printf '%s\n' "$line" >> "$tmp"
                fi
            done < <(grep '^HOLDER' "$file" 2>/dev/null || true)
            if [[ "$changed" -eq 1 ]]; then
                mv "$tmp" "$file"
                _queue_global_json_event "global_claim_released" "$claim" "$mode" "$qid" "${queue_user:-}" "$qroot" "${class:-}" "${job_name:-}" ""
            else
                rm -f "$tmp"
            fi
            if ! grep -q '^HOLDER' "$file" 2>/dev/null; then
                rm -f "$file" 2>/dev/null || true
            fi
        ) 9>"$lock"
    done
    shopt -u nullglob
}

_queue_global_claims_print() {
    local root="$(_queue_global_root)" file claim mode slots count line
    if [[ ! -d "$root/claims" ]]; then
        echo "No global claim root found: $root"
        return 0
    fi
    printf '%-32s %-10s %-9s %s\n' "CLAIM" "MODE" "USED/TOTAL" "HOLDERS"
    shopt -s nullglob
    for file in "$root/claims"/*.env; do
        [[ -f "$file" ]] || continue
        claim="$(grep '^CLAIM_KEY=' "$file" | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || true)"
        mode="$(grep '^CLAIM_MODE=' "$file" | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || true)"
        slots="$(grep '^CLAIM_SLOTS_TOTAL=' "$file" | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || true)"
        count="$(_queue_global_claim_holder_count "$file")"
        printf '%-32s %-10s %s/%s\n' "${claim:-$(basename "$file" .env)}" "${mode:-?}" "$count" "${slots:-?}"
        while IFS= read -r line; do
            [[ "$line" == HOLDER$'\t'* ]] || continue
            printf '  %-12s %-36s %-16s %s\n' "$(printf '%s\n' "$line" | cut -f3)" "$(printf '%s\n' "$line" | cut -f2)" "$(printf '%s\n' "$line" | cut -f5)" "$(printf '%s\n' "$line" | cut -f6)"
        done < <(grep '^HOLDER' "$file" 2>/dev/null || true)
    done
    shopt -u nullglob
}

_queue_global_claim_explain() {
    local claim="$1" file line
    [[ -n "$claim" ]] || { echo "Usage: queue global claim CLAIM" >&2; return 2; }
    file="$(_queue_global_claim_file "$claim")"
    echo "GLOBAL CLAIM: $claim"
    echo "global root:  $(_queue_global_root)"
    echo "file:         $file"
    if [[ ! -f "$file" ]]; then
        echo "status:       no active holders"
        return 0
    fi
    echo
    sed 's/^/  /' "$file" | grep -v '^  HOLDER' || true
    echo
    echo "holders:"
    while IFS= read -r line; do
        [[ "$line" == HOLDER$'\t'* ]] || continue
        printf '  qid=%s user=%s root=%s class=%s job=%s pid=%s since=%s\n' \
            "$(printf '%s\n' "$line" | cut -f2)" "$(printf '%s\n' "$line" | cut -f3)" "$(printf '%s\n' "$line" | cut -f4)" \
            "$(printf '%s\n' "$line" | cut -f5)" "$(printf '%s\n' "$line" | cut -f6)" "$(printf '%s\n' "$line" | cut -f7)" "$(printf '%s\n' "$line" | cut -f8)"
    done < <(grep '^HOLDER' "$file" 2>/dev/null || true)
}

_queue_global_cleanup() {
    local dryrun=0 root file claim mode slots before after
    [[ "${1:-}" == "--dryrun" ]] && dryrun=1
    root="$(_queue_global_root)"
    [[ -d "$root/claims" ]] || { echo "No global claims root: $root"; return 0; }
    shopt -s nullglob
    for file in "$root/claims"/*.env; do
        [[ -f "$file" ]] || continue
        claim="$(grep '^CLAIM_KEY=' "$file" | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || basename "$file" .env)"
        mode="$(grep '^CLAIM_MODE=' "$file" | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || echo shared)"
        slots="$(grep '^CLAIM_SLOTS_TOTAL=' "$file" | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || echo 1)"
        before="$(_queue_global_claim_holder_count "$file")"
        if [[ "$dryrun" -eq 1 ]]; then
            echo "DRYRUN global cleanup would compact: $claim holders=$before"
        else
            _queue_global_claim_compact_file "$file" "$claim" "$mode" "$slots"
            after="$(_queue_global_claim_holder_count "$file")"
            echo "global cleanup: $claim holders $before -> $after"
        fi
    done
    shopt -u nullglob
}

_queue_global_force_release() {
    local claim="$1" qid="$2" file line qroot
    [[ -n "$claim" && -n "$qid" ]] || { echo "Usage: queue global release CLAIM QID --force" >&2; return 2; }
    [[ "${3:-}" == "--force" ]] || { echo "queue global release requires --force" >&2; return 2; }
    file="$(_queue_global_claim_file "$claim")"
    [[ -f "$file" ]] || { echo "queue global release: claim not active: $claim" >&2; return 1; }
    qroot="$(awk -F '\t' -v qid="$qid" '$1 == "HOLDER" && $2 == qid {print $4; exit}' "$file")"
    [[ -n "$qroot" ]] || { echo "queue global release: qid not holder: $qid" >&2; return 1; }
    _queue_global_release_job_claims "$qid" "$qroot"
}

_queue_global_health() {
    local root="$(_queue_global_root)" rc=0
    echo "global root: $root"
    if [[ ! -d "$root" ]]; then
        echo "MISSING root directory"
        return 1
    fi
    for d in claims slots .lock; do
        if [[ -d "$root/$d" ]]; then
            echo "OK $d"
        else
            echo "MISSING $d"; rc=1
        fi
    done
    [[ -w "$root/claims" ]] && echo "claims writable: yes" || echo "claims writable: no"
    return "$rc"
}

_queue_global_command() {
    local sub="${1:-claims}"
    shift || true
    case "$sub" in
        root) _queue_global_root ;;
        claims|list) _queue_global_claims_print ;;
        claim|explain) _queue_global_claim_explain "${1:-}" ;;
        cleanup) _queue_global_cleanup "$@" ;;
        release) _queue_global_force_release "$@" ;;
        health) _queue_global_health ;;
        *) echo "Usage: queue global root|claims|claim CLAIM|cleanup [--dryrun]|release CLAIM QID --force|health" >&2; return 2 ;;
    esac
}

_queue_global_explain_for_job() {
    local f="$1" id="$2" root="$(_queue_global_root)" file line found=0 claim mode slots qid qroot
    local spec record_type packed status count holders
    echo "Global resource claims"
    [[ -d "$root/claims" ]] || { echo "  none"; return 0; }

    # First show any claims already held by this job.
    shopt -s nullglob
    for file in "$root/claims"/*.env; do
        [[ -f "$file" ]] || continue
        claim="$(grep '^CLAIM_KEY=' "$file" | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || basename "$file" .env)"
        mode="$(grep '^CLAIM_MODE=' "$file" | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || echo shared)"
        slots="$(grep '^CLAIM_SLOTS_TOTAL=' "$file" | head -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || echo 1)"
        while IFS= read -r line; do
            [[ "$line" == HOLDER$'\t'* ]] || continue
            qid="$(printf '%s\n' "$line" | cut -f2)"
            qroot="$(printf '%s\n' "$line" | cut -f4)"
            if [[ "$qid" == "$id" && "$qroot" == "$(_queue_root)" ]]; then
                found=1
                echo "  $claim"
                echo "    mode:        $mode"
                echo "    status:      acquired"
                echo "    slots:       $slots"
                echo "    global root: $root"
            fi
        done < <(grep '^HOLDER' "$file" 2>/dev/null || true)
    done
    shopt -u nullglob

    # Then show global claims required by the class even when this job is pending
    # and blocked before it ever acquired a holder record.
    if _queue_class_load_for_job "$f" >/dev/null 2>&1; then
        for spec in "${QUEUE_CLASS_GLOBAL_CLAIM_SPECS[@]}"; do
            IFS=$'\t' read -r mode slots record_type claim packed < <(_queue_global_spec_info "$spec") || continue
            [[ -n "$claim" ]] || continue
            if _queue_global_claim_exception_allows "$claim"; then
                status="bypassed by exception"
            elif _queue_global_claim_available_one "$claim" "$mode" "$slots" "$id" "$(_queue_root)"; then
                status="available / waiting to acquire"
            else
                status="blocked: global resource slot unavailable"
            fi
            count="$(_queue_global_claim_holder_count "$(_queue_global_claim_file "$claim")")"
            holders="$(_queue_global_claim_holder_summary "$claim")"
            echo "  $claim"
            echo "    mode:        $mode"
            echo "    status:      $status"
            echo "    slots used:  ${count:-0}/${slots:-1}"
            echo "    global root: $root"
            if [[ -n "$holders" ]]; then
                echo "    holders:     $holders"
            fi
            found=1
        done
    fi

    [[ "$found" -eq 0 ]] && echo "  none"
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
    CLASS_PREFLIGHT_FUNC=""
    CLASS_PREFLIGHT_FUNCS=""
    CLASS_PREFLIGHT_CMD=""
    CLASS_PREFLIGHT_CMDS=""
    CLASS_PREFLIGHT_PLUGINS=""
    _queue_class_asset_reset

    if [[ ! -f "$QUEUE_CLASS_FILE" && "$QUEUE_CLASS_NAME" == "${QUEUEBASH_DEFAULT_CLASS:-DEFAULT}" ]]; then
        default_file="$root/classes/${QUEUEBASH_DEFAULT_CLASS:-DEFAULT}.env"
        mkdir -p "$root/classes" "$root/class.d"
        cat > "$default_file" <<'EOF'
# bashqueues default class
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
EOF
    fi

    if [[ -f "$QUEUE_CLASS_FILE" ]]; then
        _queue_class_source_with_job_context "$QUEUE_CLASS_FILE" "$f"
    unset CLASS_SHARED_ASSETS CLASS_EXCLUSIVE_ASSETS CLASS_ASSETS
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
        for spec in "${QUEUE_CLASS_EXCLUSIVE_ASSET_SPECS[@]}"; do
            asset="$(_queue_class_asset_claim_token_from_spec "$spec")"
            [[ -n "$asset" ]] && _queue_asset_has_any_claim "$asset" && exit 12
        done
        for asset in $CLASS_SHARED_ASSETS; do
            _queue_asset_has_exclusive_claim "$asset" && exit 13
        done
        for spec in "${QUEUE_CLASS_SHARED_ASSET_SPECS[@]}"; do
            asset="$(_queue_class_asset_claim_token_from_spec "$spec")"
            [[ -n "$asset" ]] && _queue_asset_has_exclusive_claim "$asset" && exit 13
        done

        _queue_asset_implied_preflight_for_class || exit 23
        _queue_class_dynamic_preflight "$f" || exit 24
        _queue_global_claims_available_for_job "$f" || exit 25
        exit 0
    )
    rc="$?"
    if [[ "$rc" -ne 0 ]]; then
        case "$rc" in
            23) _queue_log_event "resource_blocked" "$id" "$name" "pending" "class=$class reason=asset_preflight" ;;
            24) _queue_log_event "resource_blocked" "$id" "$name" "pending" "class=$class reason=preflight" ;;
            25) : ;; # global claim helper already logged the claim key and holder summary
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
        for spec in "${QUEUE_CLASS_EXCLUSIVE_ASSET_SPECS[@]}"; do
            asset="$(_queue_class_asset_claim_token_from_spec "$spec")"
            [[ -n "$asset" ]] && _queue_asset_has_any_claim "$asset" && exit 22
        done
        for asset in $CLASS_SHARED_ASSETS; do
            _queue_asset_has_exclusive_claim "$asset" && exit 23
        done
        for spec in "${QUEUE_CLASS_SHARED_ASSET_SPECS[@]}"; do
            asset="$(_queue_class_asset_claim_token_from_spec "$spec")"
            [[ -n "$asset" ]] && _queue_asset_has_exclusive_claim "$asset" && exit 23
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
        for spec in "${QUEUE_CLASS_EXCLUSIVE_ASSET_SPECS[@]}"; do
            asset="$(_queue_class_asset_claim_token_from_spec "$spec")"
            [[ -z "$asset" ]] && continue
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
        for spec in "${QUEUE_CLASS_SHARED_ASSET_SPECS[@]}"; do
            asset="$(_queue_class_asset_claim_token_from_spec "$spec")"
            [[ -z "$asset" ]] && continue
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
    _queue_class_release_claims "$id" 2>/dev/null || true
    _queue_global_release_job_claims "$id" "$root" 2>/dev/null || true
    return 1
}

_queue_class_release_claims() {
    local id="$1" root
    root="$(_queue_root)"
    [[ -z "$id" ]] && return 0
    rm -rf "$root/claims/classes/"*".$id.claim" "$root/claims/assets/"*".$id.claim" 2>/dev/null || true
    _queue_global_release_job_claims "$id" "$root" 2>/dev/null || true
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



_queue_dispatch_trace_enabled() {
    [[ "${QUEUEBASH_TRACE_DISPATCH:-0}" == "1" || "${QUEUEBASH_TRACE_DISPATCH:-0}" == "true" ]]
}

_queue_dispatch_trace_log() {
    local worker="${1:-?}"
    local msg="${2:-}"
    local root="$(_queue_root)"
    local ts

    _queue_dispatch_trace_enabled || return 0

    ts="$(date -Is 2>/dev/null || date)"
    mkdir -p "$root/workers"
    printf '%s worker=%s %s\n' "$ts" "$worker" "$msg" >> "$root/workers/dispatch.trace"
    printf '[worker %s trace] %s\n' "$worker" "$msg" >&2
}

_queue_dispatch_trace_show() {
    local root="$(_queue_root)"
    local n="${1:-120}"
    local f="$root/workers/dispatch.trace"

    if [[ ! -f "$f" ]]; then
        echo "No dispatch trace found: $f"
        echo "Enable with: QUEUEBASH_TRACE_DISPATCH=1 queue run"
        return 0
    fi

    tail -n "$n" "$f"
}

_queue_pending_candidate_summary() {
    local root="$(_queue_root)"
    local f
    shopt -s nullglob
    for f in "$root/pending"/*.job; do
        [[ -f "$f" ]] || continue
        printf '%s %s class=%s\n' "$(basename "$f" .job)" "$(_queue_job_name "$f" 2>/dev/null || true)" "$(_queue_class_for_job_file "$f" 2>/dev/null || echo DEFAULT)"
    done
    shopt -u nullglob
}

_queue_claims_summary_for_explain() {
    local root="$(_queue_root)"
    local dir f

    for dir in "$root/claims" "$root/locks" "$root/resources" "$root/class_claims"; do
        [[ -d "$dir" ]] || continue
        echo "  claim dir:         $dir"
        shopt -s nullglob
        for f in "$dir"/*; do
            [[ -e "$f" ]] || continue
            echo "    $(basename "$f")"
        done
        shopt -u nullglob
    done
}


_queue_move_failure_diagnose() {
    local src="$1"
    local dst="$2"
    local id="${3:-}"
    local root="$(_queue_root)"

    echo "move_failure: id=$id"
    echo "move_failure: src=$src"
    echo "move_failure: dst=$dst"

    [[ -e "$src" ]] && echo "move_failure: src_exists=1" || echo "move_failure: src_exists=0"

    if [[ -e "$dst" ]]; then
        echo "move_failure: dst_exists=1"
        if [[ -f "$dst" ]]; then
            echo "move_failure: dst_type=file"
        elif [[ -d "$dst" ]]; then
            echo "move_failure: dst_type=directory"
        else
            echo "move_failure: dst_type=other"
        fi
    else
        echo "move_failure: dst_exists=0"
    fi

    [[ -d "$root/running" ]] && echo "move_failure: running_dir_exists=1" || echo "move_failure: running_dir_exists=0"
    [[ -w "$root/running" ]] && echo "move_failure: running_dir_writable=1" || echo "move_failure: running_dir_writable=0"
    [[ -d "$root/pending" ]] && echo "move_failure: pending_dir_exists=1" || echo "move_failure: pending_dir_exists=0"
    [[ -w "$root/pending" ]] && echo "move_failure: pending_dir_writable=1" || echo "move_failure: pending_dir_writable=0"

    local state f count=0
    for state in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
        f="$root/$state/$id.job"
        if [[ -e "$f" ]]; then
            echo "move_failure: duplicate_record=$state/$id.job"
            count=$((count + 1))
        fi
    done
    echo "move_failure: duplicate_record_count=$count"
}

_queue_move_pending_to_running() {
    local job="$1"
    local running="$2"
    local id="$3"
    local worker="${4:-?}"
    local err rc line

    _queue_dispatch_trace_log "$worker" "move pending->running start $id src=$job dst=$running"

    err="$(mktemp)"
    mv "$job" "$running" 2>"$err"
    rc="$?"

    if [[ "$rc" -eq 0 ]]; then
        rm -f "$err"
        _queue_dispatch_trace_log "$worker" "move pending->running ok $id"
        return 0
    fi

    _queue_dispatch_trace_log "$worker" "move pending->running failed $id rc=$rc"

    if [[ -s "$err" ]]; then
        while IFS= read -r line; do
            _queue_dispatch_trace_log "$worker" "move stderr $id: $line"
        done < "$err"
    fi

    while IFS= read -r line; do
        _queue_dispatch_trace_log "$worker" "$line"
    done < <(_queue_move_failure_diagnose "$job" "$running" "$id")

    rm -f "$err"
    return "$rc"
}

_queue_duplicate_qids_report() {
    local root="$(_queue_root)"
    local state f id tmp
    tmp="$(mktemp)"

    for state in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
        shopt -s nullglob
        for f in "$root/$state"/*.job; do
            [[ -f "$f" ]] || continue
            id="$(basename "$f" .job)"
            printf '%s\t%s\t%s\n' "$id" "$state" "$f" >> "$tmp"
        done
        shopt -u nullglob
    done

    if [[ -s "$tmp" ]]; then
        cut -f1 "$tmp" | sort | uniq -d | while IFS= read -r id; do
            echo "duplicate qid: $id"
            awk -F '\t' -v id="$id" '$1 == id { printf "  %-12s %s\n", $2, $3 }' "$tmp"
        done
    fi

    rm -f "$tmp"
}



_queue_script_dir() {
    local src="${BASH_SOURCE[0]:-$0}"
    cd "$(dirname "$src")" 2>/dev/null && pwd -P
}

_queue_manager_panel_entry() {
    local dir panel python
    dir="$(_queue_script_dir)"
    panel="$dir/queuemgr_panel.py"

    if [[ ! -f "$panel" ]]; then
        echo "queue manager: missing panel manager: $panel" >&2
        return 1
    fi

    python="${QUEUEBASH_PYTHON:-python3}"
    "$python" "$panel" "$@"
}

_queue_manager_entry() {
    local sub="${1:-panel}"
    case "$sub" in
        panel|"")
            [[ "$#" -gt 0 ]] && shift || true
            _queue_manager_panel_entry "$@"
            ;;
        help|--help|-h)
            echo "QueueManager is panel-only. Use: queue mgr"
            ;;
        *)
            echo "queue manager: legacy manager subcommand removed: $sub" >&2
            echo "Use: queue mgr" >&2
            return 2
            ;;
    esac
}

_queue_normalize_systemd_cpu_quota() {
    local v="$1"

    # Accept either "50" or "50%"; systemd wants a single literal percent.
    # Never double percent-escape because this is used as an argv element, not
    # inside a printf format string.
    [[ -z "$v" ]] && return 0

    if [[ "$v" =~ ^[0-9]+([.][0-9]+)?%$ ]]; then
        printf '%s\n' "$v"
    elif [[ "$v" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        printf '%s%%\n' "$v"
    else
        printf '%s\n' "$v"
    fi
}

_queue_class_load_defaults_for_class() {
    local class="${1:-DEFAULT}"
    local class_file
    class_file="$(_queue_class_file "$class")"
    [[ -f "$class_file" ]] || return 0

    (
        CLASS_DEFAULT_RUNNER=""
        CLASS_DEFAULT_CPU_LIMIT=""
        CLASS_DEFAULT_MEM_LIMIT=""
        CLASS_DEFAULT_MAX_LOG_SIZE_BYTES=""
        CLASS_DEFAULT_LOG_OVERFLOW_POLICY=""
        CLASS_DEFAULT_ALLOW_LARGE_LOG=""
        CLASS_DEFAULT_TIMEOUT=""
        CLASS_DEFAULT_KILL_AFTER=""
        CLASS_DEFAULT_LOG_TAG=""
        CLASS_DEFAULT_OUTPUT_DIR=""
        CLASS_DEFAULT_ENV_PREFIX=""
        CLASS_DEFAULT_WORKING_DIR=""
        CLASS_DEFAULT_RUN_USER=""
        CLASS_DEFAULT_SUBMIT_USER=""
        CLASS_DEFAULT_SANDBOX_LEVEL=""
        CLASS_DEFAULT_RUNTIME_CAPS=""
        CLASS_DEFAULT_RUNTIME_CAP_INTERVAL=""
        CLASS_DEFAULT_RUNTIME_CAP_PORTS=""
        CLASS_DEFAULT_SECCOMP_PROFILE=""
        CLASS_DEFAULT_SECCOMP_ALLOW=""

        # Execution/cost caps.
        CLASS_DEFAULT_CPU_SECONDS=""
        CLASS_DEFAULT_WALL_SECONDS=""
        CLASS_DEFAULT_BILLING_CYCLES=""
        CLASS_DEFAULT_BILLING_UNIT_SECONDS=""
        CLASS_DEFAULT_BILLING_GRACE_SECONDS=""
        CLASS_DEFAULT_BILLING_POLICY=""
        CLASS_DEFAULT_NET_USAGE_INTERFACE=""
        CLASS_DEFAULT_NET_USAGE_DIRECTION=""
        CLASS_DEFAULT_NET_USAGE_LIMIT_BYTES=""
        CLASS_DEFAULT_NET_USAGE_ALLOWANCE_BYTES=""
        CLASS_DEFAULT_NET_USAGE_COUNTER_FILE=""
        CLASS_DEFAULT_NET_USAGE_POLICY=""

        source "$class_file" >/dev/null 2>&1 || exit 0

        [[ -n "${CLASS_DEFAULT_RUNNER:-}" ]] && printf 'RUNNER\t%s\n' "$CLASS_DEFAULT_RUNNER"
        [[ -n "${CLASS_DEFAULT_CPU_LIMIT:-}" ]] && printf 'CPU_LIMIT\t%s\n' "$CLASS_DEFAULT_CPU_LIMIT"
        [[ -n "${CLASS_DEFAULT_MEM_LIMIT:-}" ]] && printf 'MEM_LIMIT\t%s\n' "$CLASS_DEFAULT_MEM_LIMIT"
        [[ -n "${CLASS_DEFAULT_MAX_LOG_SIZE_BYTES:-}" ]] && printf 'MAX_LOG_SIZE_BYTES\t%s\n' "$CLASS_DEFAULT_MAX_LOG_SIZE_BYTES"
        [[ -n "${CLASS_DEFAULT_LOG_OVERFLOW_POLICY:-}" ]] && printf 'LOG_OVERFLOW_POLICY\t%s\n' "$CLASS_DEFAULT_LOG_OVERFLOW_POLICY"
        [[ -n "${CLASS_DEFAULT_ALLOW_LARGE_LOG:-}" ]] && printf 'ALLOW_LARGE_LOG\t%s\n' "$CLASS_DEFAULT_ALLOW_LARGE_LOG"
        [[ -n "${CLASS_DEFAULT_TIMEOUT:-}" ]] && printf 'TIMEOUT\t%s\n' "$CLASS_DEFAULT_TIMEOUT"
        [[ -n "${CLASS_DEFAULT_KILL_AFTER:-}" ]] && printf 'KILL_AFTER\t%s\n' "$CLASS_DEFAULT_KILL_AFTER"
        [[ -n "${CLASS_DEFAULT_LOG_TAG:-}" ]] && printf 'LOG_TAG\t%s\n' "$CLASS_DEFAULT_LOG_TAG"
        [[ -n "${CLASS_DEFAULT_OUTPUT_DIR:-}" ]] && printf 'OUTPUT_DIR\t%s\n' "$CLASS_DEFAULT_OUTPUT_DIR"
        [[ -n "${CLASS_DEFAULT_ENV_PREFIX:-}" ]] && printf 'ENV_PREFIX\t%s\n' "$CLASS_DEFAULT_ENV_PREFIX"
        [[ -n "${CLASS_DEFAULT_WORKING_DIR:-}" ]] && printf 'PWD_AT_SUBMIT\t%s\n' "$CLASS_DEFAULT_WORKING_DIR"
        [[ -n "${CLASS_DEFAULT_RUN_USER:-}" ]] && printf 'RUN_USER\t%s\n' "$CLASS_DEFAULT_RUN_USER"
        [[ -n "${CLASS_DEFAULT_SUBMIT_USER:-}" ]] && printf 'SUBMIT_USER\t%s\n' "$CLASS_DEFAULT_SUBMIT_USER"
        [[ -n "${CLASS_DEFAULT_SANDBOX_LEVEL:-}" ]] && printf 'SANDBOX_LEVEL\t%s\n' "$CLASS_DEFAULT_SANDBOX_LEVEL"
        [[ -n "${CLASS_DEFAULT_RUNTIME_CAPS:-}" ]] && printf 'RUNTIME_CAPS\t%s\n' "$CLASS_DEFAULT_RUNTIME_CAPS"
        [[ -n "${CLASS_DEFAULT_RUNTIME_CAP_INTERVAL:-}" ]] && printf 'RUNTIME_CAP_INTERVAL\t%s\n' "$CLASS_DEFAULT_RUNTIME_CAP_INTERVAL"
        [[ -n "${CLASS_DEFAULT_RUNTIME_CAP_PORTS:-}" ]] && printf 'RUNTIME_CAP_PORTS\t%s\n' "$CLASS_DEFAULT_RUNTIME_CAP_PORTS"
        [[ -n "${CLASS_DEFAULT_SECCOMP_PROFILE:-}" ]] && printf 'SECCOMP_PROFILE\t%s\n' "$CLASS_DEFAULT_SECCOMP_PROFILE"
        [[ -n "${CLASS_DEFAULT_SECCOMP_ALLOW:-}" ]] && printf 'SECCOMP_ALLOW\t%s\n' "$CLASS_DEFAULT_SECCOMP_ALLOW"

        [[ -n "${CLASS_DEFAULT_CPU_SECONDS:-}" ]] && printf 'CPU_SECONDS\t%s\n' "$CLASS_DEFAULT_CPU_SECONDS"
        [[ -n "${CLASS_DEFAULT_WALL_SECONDS:-}" ]] && printf 'WALL_SECONDS\t%s\n' "$CLASS_DEFAULT_WALL_SECONDS"
        [[ -n "${CLASS_DEFAULT_BILLING_CYCLES:-}" ]] && printf 'BILLING_CYCLES\t%s\n' "$CLASS_DEFAULT_BILLING_CYCLES"
        [[ -n "${CLASS_DEFAULT_BILLING_UNIT_SECONDS:-}" ]] && printf 'BILLING_UNIT_SECONDS\t%s\n' "$CLASS_DEFAULT_BILLING_UNIT_SECONDS"
        [[ -n "${CLASS_DEFAULT_BILLING_GRACE_SECONDS:-}" ]] && printf 'BILLING_GRACE_SECONDS\t%s\n' "$CLASS_DEFAULT_BILLING_GRACE_SECONDS"
        [[ -n "${CLASS_DEFAULT_BILLING_POLICY:-}" ]] && printf 'BILLING_POLICY\t%s\n' "$CLASS_DEFAULT_BILLING_POLICY"
        [[ -n "${CLASS_DEFAULT_NET_USAGE_INTERFACE:-}" ]] && printf 'NET_USAGE_INTERFACE\t%s\n' "$CLASS_DEFAULT_NET_USAGE_INTERFACE"
        [[ -n "${CLASS_DEFAULT_NET_USAGE_DIRECTION:-}" ]] && printf 'NET_USAGE_DIRECTION\t%s\n' "$CLASS_DEFAULT_NET_USAGE_DIRECTION"
        [[ -n "${CLASS_DEFAULT_NET_USAGE_LIMIT_BYTES:-}" ]] && printf 'NET_USAGE_LIMIT_BYTES\t%s\n' "$CLASS_DEFAULT_NET_USAGE_LIMIT_BYTES"
        [[ -n "${CLASS_DEFAULT_NET_USAGE_ALLOWANCE_BYTES:-}" ]] && printf 'NET_USAGE_ALLOWANCE_BYTES\t%s\n' "$CLASS_DEFAULT_NET_USAGE_ALLOWANCE_BYTES"
        [[ -n "${CLASS_DEFAULT_NET_USAGE_COUNTER_FILE:-}" ]] && printf 'NET_USAGE_COUNTER_FILE\t%s\n' "$CLASS_DEFAULT_NET_USAGE_COUNTER_FILE"
        [[ -n "${CLASS_DEFAULT_NET_USAGE_POLICY:-}" ]] && printf 'NET_USAGE_POLICY\t%s\n' "$CLASS_DEFAULT_NET_USAGE_POLICY"
    )
}

_queue_expand_job_template() {
    local template="$1"
    local id="$2"
    local name="$3"
    local root="$(_queue_root)"
    local out="$template"

    out="${out//\$\{JOB_ID\}/$id}"
    out="${out//\$\{JOB_NAME\}/$name}"
    out="${out//\$\{QUEUEBASH_ROOT\}/$root}"
    out="${out//\$\{QUEUE_ROOT\}/$root}"

    printf '%s\n' "$out"
}

_queue_append_class_defaults_to_job_file() {
    local job_file="$1"
    local class="${2:-DEFAULT}"
    local id="${3:-}"
    local name="${4:-}"
    local key value expanded
    local applied=0

    [[ -f "$job_file" ]] || return 0
    [[ -z "$id" ]] && id="$(basename "$job_file" .job)"
    [[ -z "$name" ]] && name="$(_queue_job_name "$job_file" 2>/dev/null || true)"

    # Append defaults after submit has written its built-in values. The last
    # assignment wins when the job file is sourced, which makes class defaults
    # visible/auditable while still keeping the original submitted baseline.
    while IFS=$'\t' read -r key value; do
        [[ -n "$key" ]] || continue

        case "$key" in
            OUTPUT_DIR|ENV_PREFIX|LOG_TAG|PWD_AT_SUBMIT)
                expanded="$(_queue_expand_job_template "$value" "$id" "$name")"
                ;;
            *)
                expanded="$value"
                ;;
        esac

        printf '%s=%q\n' "$key" "$expanded" >> "$job_file"
        applied=$((applied + 1))
    done < <(_queue_class_load_defaults_for_class "$class")

    if [[ "$applied" -gt 0 ]]; then
        printf 'CLASS_DEFAULTS_APPLIED_AT=%q\n' "$(date -Is 2>/dev/null || date)" >> "$job_file"
        printf 'CLASS_DEFAULTS_SOURCE=%q\n' "$class" >> "$job_file"
    fi
}

_queue_class_defaults_show() {
    local class="${1:-DEFAULT}"
    local any=0

    while IFS=$'\t' read -r key value; do
        [[ -n "$key" ]] || continue
        any=1
        printf '  %-32s %s\n' "$key" "$value"
    done < <(_queue_class_load_defaults_for_class "$class")

    [[ "$any" -eq 0 ]] && echo "  none"
}

_queue_next_job() {
    # Contract:
    #   stdout MUST contain only the selected pending job path, or nothing.
    #   Class/plugin/preflight output must never leak to stdout, because the
    #   worker captures this function with command substitution and treats the
    #   result as a path.
    _queue_dispatch_trace_log "${QUEUEBASH_WORKER_ID:-?}" "entered _queue_next_job"

    local root="$(_queue_root)"
    local best=""
    local best_pri="-999999"
    local best_id=""
    local f id pri
    local seen=0
    local tmp class_rc line

    shopt -s nullglob
    for f in "$root/pending"/*.job; do
        [[ -f "$f" ]] || continue

        seen=$((seen + 1))
        id="$(basename "$f" .job)"
        _queue_dispatch_trace_log "${QUEUEBASH_WORKER_ID:-?}" "candidate $id $(_queue_job_name "$f" 2>/dev/null || true)"

        if ! _queue_job_retry_due "$f"; then
            _queue_dispatch_trace_log "${QUEUEBASH_WORKER_ID:-?}" "skip $id retry-not-due"
            continue
        fi

        if ! _queue_job_schedule_due "$f"; then
            _queue_dispatch_trace_log "${QUEUEBASH_WORKER_ID:-?}" "skip $id schedule-not-due"
            continue
        fi

        if ! _queue_job_dependencies_satisfied "$f"; then
            _queue_dispatch_trace_log "${QUEUEBASH_WORKER_ID:-?}" "skip $id dependencies-not-satisfied"
            continue
        fi

        _queue_dispatch_trace_log "${QUEUEBASH_WORKER_ID:-?}" "class check start $id"

        tmp="$(mktemp)"
        if _queue_class_available "$f" >"$tmp" 2>&1; then
            class_rc=0
        else
            class_rc="$?"
        fi

        if [[ -s "$tmp" ]]; then
            while IFS= read -r line; do
                _queue_dispatch_trace_log "${QUEUEBASH_WORKER_ID:-?}" "class output $id: $line"
            done < "$tmp"
        fi
        rm -f "$tmp"

        if [[ "$class_rc" -ne 0 ]]; then
            _queue_dispatch_trace_log "${QUEUEBASH_WORKER_ID:-?}" "skip $id class-or-resource-blocked rc=$class_rc"
            continue
        fi

        _queue_dispatch_trace_log "${QUEUEBASH_WORKER_ID:-?}" "class check ok $id"

        pri="$(_queue_job_pri "$f")"

        if (( pri > best_pri )); then
            best="$f"
            best_pri="$pri"
            best_id="$id"
            _queue_dispatch_trace_log "${QUEUEBASH_WORKER_ID:-?}" "best now $id pri=$pri"
        elif (( pri == best_pri )); then
            if [[ -z "$best_id" || "$id" < "$best_id" ]]; then
                best="$f"
                best_id="$id"
                _queue_dispatch_trace_log "${QUEUEBASH_WORKER_ID:-?}" "best tie-break now $id pri=$pri"
            fi
        fi
    done
    shopt -u nullglob

    if [[ "$seen" -eq 0 ]]; then
        _queue_dispatch_trace_log "${QUEUEBASH_WORKER_ID:-?}" "no pending candidates found"
    fi

    if [[ -n "$best" ]]; then
        _queue_dispatch_trace_log "${QUEUEBASH_WORKER_ID:-?}" "selected $best_id pri=$best_pri"
        printf '%s\n' "$best"
    else
        _queue_dispatch_trace_log "${QUEUEBASH_WORKER_ID:-?}" "no runnable candidate selected"
    fi
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


_queue_strip_resubmit_runtime_fields() {
    local f="$1"
    local tmp

    [[ -f "$f" ]] || return 0
    tmp="$(mktemp)"

    awk '
        /^RUNNER_USED=/ { next }
        /^RUN_PID=/ { next }
        /^RUN_PGID=/ { next }
        /^RUN_STARTED_AT=/ { next }
        /^EXEC_FINISHED_AT=/ { next }
        /^EXIT_CODE=/ { next }
        /^DURATION_SECONDS=/ { next }
        /^SYSTEMD_UNIT=/ { next }
        /^SYSTEMD_UNIT_RAW=/ { next }
        /^SYSTEMD_MAIN_PID=/ { next }
        /^PAYLOAD_PID=/ { next }
        /^LOG_BYTES=/ { next }
        /^LOG_COMPRESSED=/ { next }
        /^LOG_COMPRESSED_AT=/ { next }
        /^LOG_PATH=/ { next }
        /^JOB_CLASS_CLAIMED=/ { next }
        /^JOB_CLASS_CLAIMED_AT=/ { next }
        /^QUEUEBASH_INHERITED_ENV_FROM=/ { next }
        /^QUEUEBASH_INHERITED_ENV_KEYS=/ { next }

        /^CLASS_DEFAULTS_APPLIED_AT=/ { next }
        /^CLASS_DEFAULTS_SOURCE=/ { next }
        /^TIMEOUT=/ { next }
        /^KILL_AFTER=/ { next }
        /^LOG_TAG=/ { next }
        /^OUTPUT_DIR=/ { next }
        /^ENV_PREFIX=/ { next }
        /^CPU_SECONDS=/ { next }
        /^WALL_SECONDS=/ { next }
        /^BILLING_CYCLES=/ { next }
        /^BILLING_UNIT_SECONDS=/ { next }
        /^BILLING_GRACE_SECONDS=/ { next }
        /^BILLING_POLICY=/ { next }

        /^RUNNER=/ { next }
        /^CPU_LIMIT=/ { next }
        /^MEM_LIMIT=/ { next }
        /^MAX_LOG_SIZE_BYTES=/ { next }
        /^ALLOW_LARGE_LOG=/ { next }
        /^LOG_OVERFLOW_POLICY=/ { next }
        /^RUN_USER=/ { next }
        /^SUBMIT_USER=/ { next }

        { print }
    ' "$f" > "$tmp"

    mv "$tmp" "$f"
}

_queue_resubmit_apply_current_class_defaults() {
    local job_file="$1"
    local id="${2:-}"
    local class name

    [[ -f "$job_file" ]] || return 0
    [[ -z "$id" ]] && id="$(basename "$job_file" .job)"
    name="$(_queue_job_name "$job_file" 2>/dev/null || true)"
    class="$(_queue_class_for_job_file "$job_file" 2>/dev/null || echo DEFAULT)"

    _queue_strip_resubmit_runtime_fields "$job_file"
    _queue_append_class_defaults_to_job_file "$job_file" "$class" "$id" "$name"
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
            printf 'RETRIES_DONE=%q\n' "0"
            printf 'RETRY_BACKOFF=%q\n' "${RETRY_BACKOFF:-0}"
            printf 'RETRY_NOT_BEFORE_EPOCH=%q\n' "0"
            printf 'NOT_BEFORE_EPOCH=%q\n' "0"

            # Resubmit intentionally does not preserve old class-derived
            # resource/cap defaults.  The current class definition is applied
            # after this intent-only record is written.
            printf 'CPU_LIMIT=%q\n' ""
            printf 'MEM_LIMIT=%q\n' ""
            printf 'MAX_LOG_SIZE_BYTES=%q\n' "${QUEUEBASH_MAX_LOG_SIZE_BYTES:-52428800}"
            printf 'ALLOW_LARGE_LOG=%q\n' "0"
            printf 'LOG_OVERFLOW_POLICY=%q\n' "${QUEUEBASH_LOG_OVERFLOW_POLICY:-stderr-only}"
            printf 'RUNNER=%q\n' "${QUEUEBASH_RUNNER:-auto}"

            [[ -n "${JOB_CLASS:-}" ]] && printf 'JOB_CLASS=%q\n' "$JOB_CLASS"
            [[ -n "${SECURITY_AUTHORISATION_CODE:-}" ]] && printf 'SECURITY_AUTHORISATION_CODE=%q\n' "$SECURITY_AUTHORISATION_CODE"
            [[ -n "${SECURITY_EXCEPTION_REASON:-}" ]] && printf 'SECURITY_EXCEPTION_REASON=%q\n' "$SECURITY_EXCEPTION_REASON"
            [[ -n "${SECURITY_EXEMPTION_TYPE:-}" ]] && printf 'SECURITY_EXEMPTION_TYPE=%q\n' "$SECURITY_EXEMPTION_TYPE"
            [[ -n "${SECURITY_EXEMPTION_DETAIL:-}" ]] && printf 'SECURITY_EXEMPTION_DETAIL=%q\n' "$SECURITY_EXEMPTION_DETAIL"
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
    ) || return 1

    _queue_resubmit_apply_current_class_defaults "$dest" "$new_id"
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

# Legacy text QueueManager readline completion removed in 0.16.14.

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

    source "$job" >/dev/null 2>&1 || true
    _queue_net_usage_job_finish_record "$job"
    source "$job" >/dev/null 2>&1 || true
    if [[ "$exit_code" -eq 0 ]] && _queue_net_usage_should_fail_current_job; then
        exit_code=87
    fi

    local started finished start_epoch finish_epoch duration log_bytes
    started="$(grep '^RUN_STARTED_AT=' "$job" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null || true)"
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
    command -v systemctl >/dev/null 2>&1 || return 1

    # systemd-run --user only works when this shell can talk to the user's
    # systemd manager over the user bus.  XDG_RUNTIME_DIR being set is not
    # enough; su/runuser shells often inherit an unusable or inaccessible bus.
    [[ -n "${XDG_RUNTIME_DIR:-}" ]] || return 1
    [[ -S "${XDG_RUNTIME_DIR}/bus" ]] || return 1

    systemctl --user show-environment >/dev/null 2>&1 || return 1

    return 0
}


_queue_systemd_user_service_status_text() {
    command -v systemd-run >/dev/null 2>&1 || { echo "systemd-run-not-found"; return 0; }
    command -v systemctl >/dev/null 2>&1 || { echo "systemctl-not-found"; return 0; }
    [[ -n "${XDG_RUNTIME_DIR:-}" ]] || { echo "xdg-runtime-dir-not-set"; return 0; }
    [[ -S "${XDG_RUNTIME_DIR}/bus" ]] || { echo "user-bus-missing"; return 0; }
    systemctl --user show-environment >/dev/null 2>&1 || { echo "user-bus-unusable"; return 0; }
    echo "user-bus-ok"
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




_queue_duration_to_seconds() {
    local v="${1:-}"

    [[ -n "$v" ]] || return 1

    case "$v" in
        *ms)
            # Round up milliseconds to one second for process timeout purposes.
            local n="${v%ms}"
            [[ "$n" =~ ^[0-9]+$ ]] || return 1
            if (( n <= 0 )); then echo 0; else echo $(( (n + 999) / 1000 )); fi
            ;;
        *s)
            local n="${v%s}"
            [[ "$n" =~ ^[0-9]+$ ]] || return 1
            echo "$n"
            ;;
        *m)
            local n="${v%m}"
            [[ "$n" =~ ^[0-9]+$ ]] || return 1
            echo $(( n * 60 ))
            ;;
        *h)
            local n="${v%h}"
            [[ "$n" =~ ^[0-9]+$ ]] || return 1
            echo $(( n * 3600 ))
            ;;
        *d)
            local n="${v%d}"
            [[ "$n" =~ ^[0-9]+$ ]] || return 1
            echo $(( n * 86400 ))
            ;;
        *)
            [[ "$v" =~ ^[0-9]+$ ]] || return 1
            echo "$v"
            ;;
    esac
}

_queue_seconds_to_duration() {
    local s="${1:-}"
    [[ "$s" =~ ^[0-9]+$ ]] || return 1
    printf '%ss\n' "$s"
}



_queue_expiry_to_epoch() {
    local v="${1:-}"
    [[ -n "$v" && "$v" != "never" ]] || return 1
    case "$v" in
        +*)
            local rel="${v#+}" secs now
            secs="$(_queue_duration_to_seconds "$rel" 2>/dev/null || true)"
            [[ "$secs" =~ ^[0-9]+$ ]] || return 1
            now="$(date +%s 2>/dev/null || echo 0)"
            [[ "$now" =~ ^[0-9]+$ ]] || return 1
            echo $((now + secs))
            ;;
        *)
            date -d "$v" +%s 2>/dev/null || return 1
            ;;
    esac
}

_queue_expiry_is_expired() {
    local expires="${1:-}"
    [[ -n "$expires" && "$expires" != "never" ]] || return 1
    local exp now
    exp="$(_queue_expiry_to_epoch "$expires" 2>/dev/null || true)"
    [[ "$exp" =~ ^[0-9]+$ ]] || return 1
    now="$(date +%s 2>/dev/null || echo 0)"
    [[ "$now" =~ ^[0-9]+$ ]] || return 1
    (( now >= exp ))
}

_queue_cap_refresh() {
    local dir="${1:-}"
    local src family dst backup ts any=0 rc=0
    local root cap_dir backup_dir

    if [[ -z "$dir" ]]; then
        echo "Usage: queue caps refresh <directory>" >&2
        return 2
    fi
    if [[ ! -d "$dir" ]]; then
        echo "queue caps refresh: directory not found: $dir" >&2
        return 1
    fi

    root="$(_queue_root)"
    cap_dir="$root/caps.d"
    backup_dir="$cap_dir/.backup"

    if ! mkdir -p "$cap_dir" "$backup_dir"; then
        echo "queue caps refresh: cannot create cap directory or backup directory under: $cap_dir" >&2
        echo "queue caps refresh: check ownership/permissions for selected queue root: $root" >&2
        return 1
    fi
    if [[ ! -d "$cap_dir" || ! -w "$cap_dir" || ! -d "$backup_dir" || ! -w "$backup_dir" ]]; then
        echo "queue caps refresh: cap directory is not writable: $cap_dir" >&2
        echo "queue caps refresh: backup directory is not writable: $backup_dir" >&2
        echo "queue caps refresh: check ownership/permissions for selected queue root: $root" >&2
        return 1
    fi

    shopt -s nullglob
    for src in "$dir"/*.sh; do
        any=1
        family="$(basename "$src" .sh)"
        dst="$cap_dir/${family}.sh"
        if ! bash -n "$src" >/dev/null 2>&1; then
            echo "queue caps refresh: syntax check failed: $src" >&2
            rc=1
            continue
        fi
        if [[ -f "$dst" ]]; then
            ts="$(date +%Y%m%d_%H%M%S_%N)"
            backup="$backup_dir/${family}.${ts}.sh"
            if ! cp "$dst" "$backup"; then
                echo "queue caps refresh: failed to back up existing cap plugin: $dst" >&2
                rc=1
                continue
            fi
        else
            backup=""
        fi
        echo "Refreshing cap plugin family=$family source=$src"
        if ! cp "$src" "$dst"; then
            echo "queue caps refresh: failed to replace cap plugin: $dst" >&2
            rc=1
            continue
        fi
        chmod 0700 "$dst" 2>/dev/null || true
        echo "Replaced cap plugin: $dst"
        [[ -n "$backup" ]] && echo "Backup: $backup"
    done
    shopt -u nullglob

    if [[ "$any" -eq 0 ]]; then
        echo "queue caps refresh: no .sh cap plugins found in $dir" >&2
        return 1
    fi
    return "$rc"
}

_queue_cap_plugin_dirs() {
    printf '%s\n' "$(_queue_root)/caps.d"
    [[ -n "${QUEUEBASH_CAP_PLUGIN_SOURCE_DIR:-}" ]] && printf '%s\n' "$QUEUEBASH_CAP_PLUGIN_SOURCE_DIR"
}

_queue_cap_plugin_files() {
    local d
    for d in $(_queue_cap_plugin_dirs); do
        [[ -d "$d" ]] || continue
        shopt -s nullglob
        printf '%s\n' "$d"/*.sh
        shopt -u nullglob
    done
}

_queue_cap_plugins_source_all() {
    local f
    for f in $(_queue_cap_plugin_files); do
        source "$f" 2>/dev/null || echo "cap_plugin_source_failed: $f" >&2
    done
}

_queue_cap_plugin_candidates_for_current_job() {
    local func
    _queue_cap_plugins_source_all
    while IFS= read -r func; do
        "$func" 2>/dev/null || true
    done < <(declare -F | awk '{print $3}' | grep '^queue_cap_candidate_' | sort)
}

_queue_cap_plugins_list() {
    local f
    for f in $(_queue_cap_plugin_files); do
        (
            source "$f" 2>/dev/null || {
                echo "INVALID helper=$(basename "$f") source_failed"
                exit 0
            }
            if declare -F queue_cap_facilities >/dev/null 2>&1; then
                queue_cap_facilities
            else
                echo "INVALID helper=$(basename "$f") missing queue_cap_facilities"
            fi
        )
    done
}

_queue_caps_effective_timeout_seconds_from_current_job() {
    local best="" wall_s line kind seconds plugin detail

    if [[ -n "${TIMEOUT:-}" ]]; then
        wall_s="$(_queue_duration_to_seconds "$TIMEOUT" 2>/dev/null || true)"
        if [[ "$wall_s" =~ ^[0-9]+$ && "$wall_s" -gt 0 ]]; then
            best="$wall_s"
        fi
    fi

    while IFS=$'\t' read -r kind seconds plugin detail; do
        [[ "$kind" == "timeout" ]] || continue
        [[ "$seconds" =~ ^[0-9]+$ && "$seconds" -gt 0 ]] || continue
        if [[ -z "$best" || "$seconds" -lt "$best" ]]; then
            best="$seconds"
        fi
    done < <(_queue_cap_plugin_candidates_for_current_job)

    [[ -n "$best" ]] || return 1
    echo "$best"
}

_queue_netdev_counter_bytes() {
    local iface="${1:-}"
    local dir="${2:-rx_tx}"
    local counter_file="${3:-}"
    local base="/sys/class/net/$iface/statistics"
    local rx tx

    if [[ -n "$counter_file" ]]; then
        cat "$counter_file" 2>/dev/null
        return
    fi

    [[ -n "$iface" && -d "$base" ]] || return 1

    rx="$(cat "$base/rx_bytes" 2>/dev/null || echo 0)"
    tx="$(cat "$base/tx_bytes" 2>/dev/null || echo 0)"
    [[ "$rx" =~ ^[0-9]+$ ]] || rx=0
    [[ "$tx" =~ ^[0-9]+$ ]] || tx=0

    case "$dir" in
        rx) echo "$rx" ;;
        tx) echo "$tx" ;;
        rx_tx|total|*) echo $((rx + tx)) ;;
    esac
}

_queue_parse_bytes() {
    local v="${1:-}" n unit
    [[ -n "$v" ]] || return 1
    if [[ "$v" =~ ^([0-9]+)([KkMmGgTt]?[Bb]?)?$ ]]; then
        n="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[2]}"
        case "$unit" in
            ""|B|b) echo "$n" ;;
            K|k|KB|kb|Kb|kB) echo $((n * 1024)) ;;
            M|m|MB|mb|Mb|mB) echo $((n * 1024 * 1024)) ;;
            G|g|GB|gb|Gb|gB) echo $((n * 1024 * 1024 * 1024)) ;;
            T|t|TB|tb|Tb|tB) echo $((n * 1024 * 1024 * 1024 * 1024)) ;;
            *) return 1 ;;
        esac
    else
        return 1
    fi
}

_queue_net_usage_job_start_record() {
    local job_file="$1"
    local iface="${NET_USAGE_INTERFACE:-}"
    local dir="${NET_USAGE_DIRECTION:-rx_tx}"
    local counter_file="${NET_USAGE_COUNTER_FILE:-}"
    local counter now

    [[ -n "$iface" ]] || return 0
    counter="$(_queue_netdev_counter_bytes "$iface" "$dir" "$counter_file" 2>/dev/null || true)"
    [[ "$counter" =~ ^[0-9]+$ ]] || return 0
    now="$(date -Is 2>/dev/null || date)"

    {
        printf 'NET_USAGE_INTERFACE=%q\n' "$iface"
        printf 'NET_USAGE_DIRECTION=%q\n' "$dir"
        [[ -n "$counter_file" ]] && printf 'NET_USAGE_COUNTER_FILE=%q\n' "$counter_file"
        printf 'NET_USAGE_START_BYTES=%q\n' "$counter"
        printf 'NET_USAGE_STARTED_AT=%q\n' "$now"
    } >> "$job_file"
}

_queue_net_usage_job_finish_record() {
    local job_file="$1"
    local iface="${NET_USAGE_INTERFACE:-}"
    local dir="${NET_USAGE_DIRECTION:-rx_tx}"
    local counter_file="${NET_USAGE_COUNTER_FILE:-}"
    local start="${NET_USAGE_START_BYTES:-}"
    local limit="${NET_USAGE_LIMIT_BYTES:-}"
    local policy="${NET_USAGE_POLICY:-mark-failed}"
    local end used now limit_b exceeded=0

    [[ -n "$iface" && "$start" =~ ^[0-9]+$ ]] || return 0
    end="$(_queue_netdev_counter_bytes "$iface" "$dir" "$counter_file" 2>/dev/null || true)"
    [[ "$end" =~ ^[0-9]+$ ]] || return 0
    (( end >= start )) && used=$((end - start)) || used=0
    now="$(date -Is 2>/dev/null || date)"

    if [[ -n "$limit" ]]; then
        limit_b="$(_queue_parse_bytes "$limit" 2>/dev/null || echo "$limit")"
        if [[ "$limit_b" =~ ^[0-9]+$ && "$used" -gt "$limit_b" ]]; then
            exceeded=1
        fi
    fi

    {
        printf 'NET_USAGE_END_BYTES=%q\n' "$end"
        printf 'NET_USAGE_USED_BYTES=%q\n' "$used"
        printf 'NET_USAGE_FINISHED_AT=%q\n' "$now"
        [[ -n "$limit" ]] && printf 'NET_USAGE_LIMIT_BYTES=%q\n' "$limit"
        printf 'NET_USAGE_EXCEEDED=%q\n' "$exceeded"
        printf 'NET_USAGE_POLICY=%q\n' "$policy"
    } >> "$job_file"

    if [[ "$exceeded" -eq 1 ]]; then
        _queue_log_event "net_usage_exceeded" "${JOB_ID:-$(basename "$job_file" .job)}" "${JOB_NAME:-}" "running" "iface=$iface used_bytes=$used limit=$limit policy=$policy"
    fi
}

_queue_net_usage_should_fail_current_job() {
    [[ "${NET_USAGE_EXCEEDED:-0}" == "1" ]] || return 1
    case "${NET_USAGE_POLICY:-mark-failed}" in
        ignore|record-only) return 1 ;;
        mark-failed|fail|fail-job) return 0 ;;
        *) return 0 ;;
    esac
}



_queue_caps_effective_timeout_seconds_from_values() {
    local wall="${1:-}"
    local billing_unit="${2:-}"
    local billing_cycles="${3:-}"
    local billing_grace="${4:-0}"

    local best="" wall_s billing_s

    if [[ -n "$wall" ]]; then
        wall_s="$(_queue_duration_to_seconds "$wall" 2>/dev/null || true)"
        if [[ "$wall_s" =~ ^[0-9]+$ && "$wall_s" -gt 0 ]]; then
            best="$wall_s"
        fi
    fi

    billing_s="$(_queue_caps_billing_timeout_seconds "$billing_unit" "$billing_cycles" "$billing_grace" 2>/dev/null || true)"
    if [[ "$billing_s" =~ ^[0-9]+$ && "$billing_s" -gt 0 ]]; then
        if [[ -z "$best" || "$billing_s" -lt "$best" ]]; then
            best="$billing_s"
        fi
    fi

    [[ -n "$best" ]] || return 1
    echo "$best"
}

_queue_caps_effective_timeout_for_current_job() {
    local best
    best="$(_queue_caps_effective_timeout_seconds_from_current_job 2>/dev/null || true)"
    [[ "$best" =~ ^[0-9]+$ && "$best" -gt 0 ]] || return 1
    _queue_seconds_to_duration "$best"
}

_queue_caps_append_defaults_to_job_file() {
    local job_file="$1"
    local class="$2"
    [[ -f "$job_file" ]] || return 0

    local class_file
    class_file="$(_queue_class_file "$class")"
    [[ -f "$class_file" ]] || return 0

    (
        CLASS_DEFAULT_CPU_SECONDS=""
        CLASS_DEFAULT_WALL_SECONDS=""
        CLASS_DEFAULT_BILLING_CYCLES=""
        CLASS_DEFAULT_BILLING_UNIT_SECONDS=""
        CLASS_DEFAULT_BILLING_GRACE_SECONDS=""
        CLASS_DEFAULT_BILLING_POLICY=""

        source "$class_file" >/dev/null 2>&1 || exit 0

        [[ -n "${CLASS_DEFAULT_CPU_SECONDS:-}" ]] && printf 'CPU_SECONDS=%q\n' "$CLASS_DEFAULT_CPU_SECONDS"
        [[ -n "${CLASS_DEFAULT_WALL_SECONDS:-}" ]] && printf 'WALL_SECONDS=%q\n' "$CLASS_DEFAULT_WALL_SECONDS"
        [[ -n "${CLASS_DEFAULT_BILLING_CYCLES:-}" ]] && printf 'BILLING_CYCLES=%q\n' "$CLASS_DEFAULT_BILLING_CYCLES"
        [[ -n "${CLASS_DEFAULT_BILLING_UNIT_SECONDS:-}" ]] && printf 'BILLING_UNIT_SECONDS=%q\n' "$CLASS_DEFAULT_BILLING_UNIT_SECONDS"
        [[ -n "${CLASS_DEFAULT_BILLING_GRACE_SECONDS:-}" ]] && printf 'BILLING_GRACE_SECONDS=%q\n' "$CLASS_DEFAULT_BILLING_GRACE_SECONDS"
        [[ -n "${CLASS_DEFAULT_BILLING_POLICY:-}" ]] && printf 'BILLING_POLICY=%q\n' "$CLASS_DEFAULT_BILLING_POLICY"
    ) >> "$job_file"
}

_queue_caps_explain_current_job() {
    local wall="${TIMEOUT:-}"
    local kill_after="${KILL_AFTER:-}"
    local cpu_seconds="${CPU_SECONDS:-}"
    local wall_seconds="${WALL_SECONDS:-}"
    local policy="${CAP_POLICY:-shortest-cap-wins}"
    local runtime_caps="${RUNTIME_CAPS:-}"
    local runtime_interval="${RUNTIME_CAP_INTERVAL:-}"
    local runtime_ports="${RUNTIME_CAP_PORTS:-}"
    local display_sandbox="${SANDBOX_LEVEL:-}"
    local display_seccomp_allow="${SECCOMP_ALLOW:-}"
    local wall_s="" effective_s="" effective=""
    local line kind seconds plugin detail

    # queue explain should show the effective security posture, not merely the
    # class defaults captured at submit time.  Workers apply these overlays
    # before launching; pending jobs need the same visible calculation.
    if [[ -n "${EXCEPTION_SANDBOX_OVERRIDE:-}" ]]; then
        display_sandbox="$(_queue_sandbox_normalise_level "$EXCEPTION_SANDBOX_OVERRIDE" 2>/dev/null || true)"
        [[ -z "$display_sandbox" ]] && display_sandbox="off"
    fi
    if [[ -n "${EXCEPTION_DROP_CAP:-}" ]]; then
        runtime_caps="$(_queue_runtime_caps_drop_list "$runtime_caps" "$EXCEPTION_DROP_CAP" 2>/dev/null || true)"
    fi
    if [[ -n "${EXCEPTION_ADD_PORT:-}" ]]; then
        runtime_ports="$(_queue_ports_add_list "$runtime_ports" "$EXCEPTION_ADD_PORT" 2>/dev/null || true)"
    fi
    if [[ -n "${EXCEPTION_SECCOMP_ALLOW:-}" ]]; then
        display_seccomp_allow="${display_seccomp_allow:+$display_seccomp_allow }${EXCEPTION_SECCOMP_ALLOW}"
    fi

    [[ -n "$wall" ]] && wall_s="$(_queue_duration_to_seconds "$wall" 2>/dev/null || true)"
    effective_s="$(_queue_caps_effective_timeout_seconds_from_current_job 2>/dev/null || true)"
    [[ "$effective_s" =~ ^[0-9]+$ ]] && effective="$(_queue_seconds_to_duration "$effective_s")"

    echo "Execution caps"
    [[ -n "$wall" ]] && echo "  wall timeout:       $wall${wall_s:+ ($wall_s seconds)}"
    [[ -n "$kill_after" ]] && echo "  kill after:         $kill_after"
    [[ -n "$cpu_seconds" ]] && echo "  CPU seconds:        $cpu_seconds (metadata; live CPU enforcement is future work)"
    [[ -n "$wall_seconds" ]] && echo "  wall seconds:       $wall_seconds (metadata)"
    [[ -n "$display_sandbox" ]] && echo "  sandbox:            ${display_sandbox:-off}"
    [[ -n "${SECCOMP_PROFILE:-}" ]] && echo "  seccomp:            ${SECCOMP_PROFILE:-}"
    [[ -n "$display_seccomp_allow" ]] && echo "  seccomp allow:      ${display_seccomp_allow:-}"
    [[ -n "$runtime_caps" ]] && echo "  runtime caps:       $runtime_caps${runtime_interval:+ interval=${runtime_interval}s}${runtime_ports:+ ports=$runtime_ports}"
    if [[ -n "$runtime_caps" ]]; then
        local normalised unknown
        normalised="$(_queue_runtime_caps_normalise "$runtime_caps" 2>/dev/null || true)"
        unknown="$(_queue_runtime_caps_unknown_list "$runtime_caps" 2>/dev/null || true)"
        [[ -n "$normalised" && "$normalised" != "$runtime_caps" ]] && echo "  runtime caps norm:  $normalised"
        [[ -n "$unknown" ]] && echo "  runtime warning:    unknown cap(s): $unknown"
    fi
    if [[ "${RUNTIME_CAP_VIOLATED:-0}" == "1" || -n "${RUNTIME_CAP_VIOLATION:-}" ]]; then
        echo "  runtime result:     blocked"
        [[ -n "${RUNTIME_CAP_VIOLATION:-}" ]] && echo "  runtime violation:  ${RUNTIME_CAP_VIOLATION}"
        [[ -n "${RUNTIME_CAP_VIOLATION_PID:-}" ]] && echo "  violation pid:      ${RUNTIME_CAP_VIOLATION_PID}"
        [[ -n "${RUNTIME_CAP_VIOLATED_AT:-}" ]] && echo "  violation time:     ${RUNTIME_CAP_VIOLATED_AT}"
    fi
    [[ -n "${RUNTIME_CAP_WARNING:-}" ]] && echo "  runtime warning:    ${RUNTIME_CAP_WARNING}"

    while IFS=$'\t' read -r kind seconds plugin detail; do
        [[ "$kind" == "timeout" ]] || continue
        [[ "$seconds" =~ ^[0-9]+$ ]] || continue
        echo "  plugin timeout:     $(_queue_seconds_to_duration "$seconds") ($seconds seconds) source=$plugin${detail:+ $detail}"
    done < <(_queue_cap_plugin_candidates_for_current_job)

    echo "  policy:             $policy"
    echo "  effective timeout:  ${effective:-none}"
}

_queue_emit_timeout_wrapper_argv() {
    local timeout_value="${1:-}"
    local kill_after="${2:-}"

    [[ -n "$timeout_value" ]] || return 0

    # GNU coreutils timeout syntax. The runnable class can also gate the
    # availability of the command, but the runner emits a clear failure if a
    # class requests TIMEOUT without timeout being installed.
    printf '%s\0' timeout --signal=TERM
    [[ -n "$kill_after" ]] && printf '%s\0' "--kill-after=$kill_after"
    printf '%s\0' "$timeout_value"
}


_queue_current_user_name() {
    id -un 2>/dev/null || printf '%s\n' "${USER:-}"
}

_queue_can_switch_user() {
    local user="${1:-}"
    [[ -n "$user" ]] || return 1
    [[ "$user" == "$(_queue_current_user_name)" ]] && return 1
    [[ "$(id -u 2>/dev/null || echo 99999)" == "0" ]] || return 2
    id "$user" >/dev/null 2>&1 || return 3
    command -v runuser >/dev/null 2>&1 || command -v sudo >/dev/null 2>&1 || return 4
    return 0
}

_queue_emit_user_switch_prefix() {
    local user="${1:-}"
    [[ -n "$user" ]] || return 0
    [[ "$user" == "$(_queue_current_user_name)" ]] && return 0

    if [[ "$(id -u 2>/dev/null || echo 99999)" != "0" ]]; then
        printf '%s\0' /bin/sh -c "echo queue run: RUN_USER=$user requires root >&2; exit 126"
        return 1
    fi

    if ! id "$user" >/dev/null 2>&1; then
        printf '%s\0' /bin/sh -c "echo queue run: RUN_USER=$user does not exist >&2; exit 126"
        return 1
    fi

    if command -v runuser >/dev/null 2>&1; then
        printf '%s\0' runuser -u "$user" --
        return 0
    fi
    if command -v sudo >/dev/null 2>&1; then
        printf '%s\0' sudo -u "$user" --
        return 0
    fi

    printf '%s\0' /bin/sh -c "echo queue run: cannot switch to RUN_USER=$user; runuser/sudo not found >&2; exit 126"
    return 1
}



_queue_security_policy_statement_name() {
    printf '%s\n' "${QUEUEBASH_CLASS_POLICY_STATEMENT:-default}"
}

_queue_policy_words_merge_unique() {
    local existing="${1:-}" incoming="${2:-}" word out=""
    for word in $existing $incoming; do
        [[ -n "$word" ]] || continue
        if ! _queue_security_policy_value_in_list "$word" "$out"; then
            out="${out:+$out }$word"
        fi
    done
    printf '%s\n' "$out"
}

_queue_policy_requirement_rank() {
    case "${1,,}" in
        authorisation|authorization) echo 3 ;;
        reason) echo 2 ;;
        reason-or-authorisation|reason-or-authorization|either) echo 1 ;;
        off|none|"") echo 0 ;;
        *) echo 1 ;;
    esac
}

_queue_policy_requirement_max() {
    local current="${1:-}" incoming="${2:-}" cr ir
    [[ -n "$incoming" ]] || { printf '%s\n' "$current"; return 0; }
    cr="$(_queue_policy_requirement_rank "$current")"
    ir="$(_queue_policy_requirement_rank "$incoming")"
    if [[ "$ir" -gt "$cr" ]]; then
        printf '%s\n' "$incoming"
    else
        printf '%s\n' "$current"
    fi
}

_queue_policy_signature_requirement_rank() {
    case "${1,,}" in
        always|required) echo 3 ;;
        if-trusted-key|if-trusted-keys|trusted|auto|"") echo 2 ;;
        off|none|legacy) echo 1 ;;
        *) echo 2 ;;
    esac
}

_queue_policy_signature_requirement_max() {
    local current="${1:-}" incoming="${2:-}" cr ir
    [[ -n "$incoming" ]] || { printf '%s\n' "$current"; return 0; }
    cr="$(_queue_policy_signature_requirement_rank "$current")"
    ir="$(_queue_policy_signature_requirement_rank "$incoming")"
    if [[ "$ir" -gt "$cr" ]]; then
        printf '%s\n' "$incoming"
    else
        printf '%s\n' "$current"
    fi
}

_queue_policy_source_file_var() {
    local file="${1:-}" var="${2:-}"
    [[ -n "$file" && -n "$var" && -f "$file" ]] || return 0
    (
        unset "$var"
        # Policy statement files are trusted bashqueues policy data files.
        # shellcheck disable=SC1090
        source "$file" >/dev/null 2>&1 || exit 0
        printf '%s\n' "${!var:-}"
    )
}

_queue_security_policy_statement_source() {
    local requested="${1:-}" name file names seen=0
    local agg_user_sandbox="" agg_user_seccomp="" agg_exception_req="" agg_weak_req=""
    local agg_weak_sandbox="" agg_weak_seccomp="" agg_block_classes="" agg_block_hashes=""
    local agg_block_words="" agg_block_patterns="" agg_block_class_req="" agg_block_command_req=""
    local agg_sig_req="" val

    if [[ -n "$requested" ]]; then
        file="$(_queue_policy_file class-statement "$requested" 2>/dev/null || true)"
        [[ -n "$file" && -f "$file" ]] || return 1
        # shellcheck disable=SC1090
        source "$file" >/dev/null 2>&1 || return 1
        return 0
    fi

    names="$(_queue_policy_list class-statement 2>/dev/null || true)"
    if [[ -z "$names" ]]; then
        names="$(_queue_security_policy_statement_name)"
    fi

    for name in $names; do
        file="$(_queue_policy_file class-statement "$name" 2>/dev/null || true)"
        [[ -n "$file" && -f "$file" ]] || continue
        seen=1

        val="$(_queue_policy_source_file_var "$file" CLASS_POLICY_USER_SANDBOX_POLICIES)"
        agg_user_sandbox="$(_queue_policy_words_merge_unique "$agg_user_sandbox" "$val")"
        val="$(_queue_policy_source_file_var "$file" CLASS_POLICY_USER_SECCOMP_POLICIES)"
        agg_user_seccomp="$(_queue_policy_words_merge_unique "$agg_user_seccomp" "$val")"

        val="$(_queue_policy_source_file_var "$file" CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE)"
        agg_exception_req="$(_queue_policy_requirement_max "$agg_exception_req" "$val")"
        val="$(_queue_policy_source_file_var "$file" CLASS_POLICY_WEAK_POLICY_REQUIRE)"
        agg_weak_req="$(_queue_policy_requirement_max "$agg_weak_req" "$val")"

        val="$(_queue_policy_source_file_var "$file" CLASS_POLICY_SANDBOX_REASON_REQUIRED)"
        agg_weak_sandbox="$(_queue_policy_words_merge_unique "$agg_weak_sandbox" "$val")"
        val="$(_queue_policy_source_file_var "$file" CLASS_POLICY_SECCOMP_REASON_REQUIRED)"
        agg_weak_seccomp="$(_queue_policy_words_merge_unique "$agg_weak_seccomp" "$val")"

        val="$(_queue_policy_source_file_var "$file" CLASS_POLICY_BLOCK_CLASS_NAMES)"
        agg_block_classes="$(_queue_policy_words_merge_unique "$agg_block_classes" "$val")"
        val="$(_queue_policy_source_file_var "$file" CLASS_POLICY_BLOCK_COMMAND_HASHES)"
        agg_block_hashes="$(_queue_policy_words_merge_unique "$agg_block_hashes" "$val")"
        val="$(_queue_policy_source_file_var "$file" CLASS_POLICY_BLOCK_COMMAND_WORDS)"
        agg_block_words="$(_queue_policy_words_merge_unique "$agg_block_words" "$val")"
        val="$(_queue_policy_source_file_var "$file" CLASS_POLICY_BLOCK_COMMAND_NAMES)"
        agg_block_words="$(_queue_policy_words_merge_unique "$agg_block_words" "$val")"
        val="$(_queue_policy_source_file_var "$file" CLASS_POLICY_BLOCK_COMMAND_PATTERNS)"
        agg_block_patterns="$(_queue_policy_words_merge_unique "$agg_block_patterns" "$val")"

        val="$(_queue_policy_source_file_var "$file" CLASS_POLICY_BLOCK_CLASS_REQUIRE)"
        agg_block_class_req="$(_queue_policy_requirement_max "$agg_block_class_req" "$val")"
        val="$(_queue_policy_source_file_var "$file" CLASS_POLICY_BLOCK_COMMAND_REQUIRE)"
        agg_block_command_req="$(_queue_policy_requirement_max "$agg_block_command_req" "$val")"

        val="$(_queue_policy_source_file_var "$file" CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED)"
        agg_sig_req="$(_queue_policy_signature_requirement_max "$agg_sig_req" "$val")"

        # Source every discovered statement so trusted signer variables and any
        # future scalar policy knobs are visible.  Known cumulative knobs are
        # normalised back to aggregate values below so one statement cannot
        # accidentally erase another statement's emergency blocks.
        # shellcheck disable=SC1090
        source "$file" >/dev/null 2>&1 || true
    done

    [[ "$seen" -eq 1 ]] || return 1

    CLASS_POLICY_USER_SANDBOX_POLICIES="$agg_user_sandbox"
    CLASS_POLICY_USER_SECCOMP_POLICIES="$agg_user_seccomp"
    CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE="${agg_exception_req:-${CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE:-reason-or-authorisation}}"
    CLASS_POLICY_WEAK_POLICY_REQUIRE="${agg_weak_req:-${CLASS_POLICY_WEAK_POLICY_REQUIRE:-reason-or-authorisation}}"
    CLASS_POLICY_SANDBOX_REASON_REQUIRED="$agg_weak_sandbox"
    CLASS_POLICY_SECCOMP_REASON_REQUIRED="$agg_weak_seccomp"
    CLASS_POLICY_BLOCK_CLASS_NAMES="$agg_block_classes"
    CLASS_POLICY_BLOCK_COMMAND_HASHES="$agg_block_hashes"
    CLASS_POLICY_BLOCK_COMMAND_WORDS="$agg_block_words"
    CLASS_POLICY_BLOCK_COMMAND_NAMES="$agg_block_words"
    CLASS_POLICY_BLOCK_COMMAND_PATTERNS="$agg_block_patterns"
    CLASS_POLICY_BLOCK_CLASS_REQUIRE="${agg_block_class_req:-${CLASS_POLICY_BLOCK_CLASS_REQUIRE:-authorisation}}"
    CLASS_POLICY_BLOCK_COMMAND_REQUIRE="${agg_block_command_req:-${CLASS_POLICY_BLOCK_COMMAND_REQUIRE:-authorisation}}"
    CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="${agg_sig_req:-${CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED:-if-trusted-key}}"
}

_queue_security_policy_value_in_list() {
    local value="$1" list="$2" item
    for item in $list; do
        [[ "${item,,}" == "${value,,}" ]] && return 0
    done
    return 1
}

_queue_security_sandbox_rank() {
    case "${1,,}" in
        off|none) echo 0 ;;
        restrict-egress|queue-default) echo 1 ;;
        network-none) echo 2 ;;
        strict) echo 3 ;;
        *) echo 0 ;;
    esac
}

_queue_security_seccomp_rank() {
    case "${1,,}" in
        off|none) echo 0 ;;
        docker-default|queue-default) echo 1 ;;
        strict) echo 2 ;;
        *) echo 0 ;;
    esac
}

_queue_authorisation_normalise_code() {
    local c="${1:-}"
    c="${c^^}"
    [[ "$c" =~ ^[A-Z0-9]{1,5}$ ]] || return 1
    printf '%s\n' "$c"
}

_queue_command_hash_from_args() {
    local raw=""
    if [[ "$#" -gt 0 ]]; then
        printf -v raw '%q ' "$@"
    fi
    printf '%s' "$raw" | sha256sum | awk '{print $1}'
}

_queue_command_shell_words_from_args() {
    # Human-readable, shell-escaped representation of an argv array.  Used only
    # for policy diagnostics and glob-style emergency command blocks; the
    # cryptographic binding remains _queue_command_hash_from_args.
    local raw=""
    if [[ "$#" -gt 0 ]]; then
        printf -v raw '%q ' "$@"
        raw="${raw% }"
    fi
    printf '%s
' "$raw"
}

_queue_policy_hash_value_in_list() {
    local hash="${1:-}" list="${2:-}" item
    [[ -n "$hash" && -n "$list" ]] || return 1
    for item in $list; do
        item="${item//,/}"
        [[ -n "$item" ]] || continue
        if [[ "${hash,,}" == "${item,,}" || "${hash:0:${#item},,}" == "${item,,}" ]]; then
            return 0
        fi
    done
    return 1
}

_queue_policy_command_word_in_list() {
    local argv0="${1:-}" list="${2:-}" item base
    [[ -n "$argv0" && -n "$list" ]] || return 1
    base="$(basename -- "$argv0" 2>/dev/null || printf '%s' "$argv0")"
    for item in $list; do
        item="${item//,/}"
        [[ -n "$item" ]] || continue
        if [[ "${argv0,,}" == "${item,,}" || "${base,,}" == "${item,,}" ]]; then
            return 0
        fi
    done
    return 1
}

_queue_policy_command_pattern_matches() {
    local rendered="${1:-}" patterns="${2:-}" pat
    [[ -n "$rendered" && -n "$patterns" ]] || return 1
    # Patterns are shell globs separated by newlines or semicolons.  This allows
    # an emergency /etc policy to block a family such as '*exiftool*' quickly,
    # while command-hash blocks remain the preferred exact mechanism.
    while IFS= read -r pat; do
        [[ -n "$pat" ]] || continue
        [[ "$rendered" == $pat ]] && return 0
    done < <(printf '%s
' "$patterns" | tr ';' '
')
    return 1
}


_queue_authorisation_key_name_ok() {
    [[ "${1:-}" =~ ^[A-Za-z0-9_.@+-]{1,64}$ ]]
}

_queue_authorisation_key_suffix() {
    local s="${1:-}"
    s="${s^^}"
    s="${s//[^A-Z0-9]/_}"
    [[ -n "$s" ]] || s="UNKNOWN"
    printf '%s\n' "$s"
}

_queue_authorisation_actor_user() {
    id -un 2>/dev/null || printf '%s\n' "${USER:-unknown}"
}

_queue_authorisation_actor_queue_root() {
    local actor actor_root selected_root_owner selected_user active_root
    if [[ -n "${QUEUEBASH_AUTHORISATION_KEY_ROOT:-}" ]]; then
        # Test/admin escape hatch: points at the keys directory itself.
        dirname "${QUEUEBASH_AUTHORISATION_KEY_ROOT%/}"
        return 0
    fi

    actor="$(_queue_authorisation_actor_user)"
    actor_root="$(_queue_root_for_user "$actor" 2>/dev/null || true)"
    active_root="$(_queue_root)"
    selected_user="${QUEUEBASH_SELECTED_USER:-}"

    # Key management belongs to the operator/signer identity, not to a foreign
    # selected target queue.  Root using `queue --queue-user hc3 ...` must manage
    # and read /root/.queuebash/keys, while the job and authorisation record live
    # in /home/hc3/.queuebash.
    if [[ -n "$actor_root" ]]; then
        if [[ -n "$selected_user" && "$selected_user" != "$actor" ]]; then
            printf '%s\n' "$actor_root"
            return 0
        fi
        selected_root_owner="$(_queue_root_owner_user 2>/dev/null || true)"
        if [[ -n "$selected_root_owner" && "$selected_root_owner" != "$actor" && "$active_root" != "$actor_root" ]]; then
            printf '%s\n' "$actor_root"
            return 0
        fi
    fi

    # Preserve ordinary single-user/test behaviour where QUEUEBASH_ROOT is an
    # explicit temporary queue root and there is no foreign selected user.
    printf '%s\n' "$active_root"
}

_queue_authorisation_key_root() {
    if [[ -n "${QUEUEBASH_AUTHORISATION_KEY_ROOT:-}" ]]; then
        printf '%s\n' "${QUEUEBASH_AUTHORISATION_KEY_ROOT%/}"
        return 0
    fi
    printf '%s/keys\n' "$(_queue_authorisation_actor_queue_root)"
}

_queue_authorisation_signer_key_root() {
    local signer="${1:-}" signer_root actor
    # Signing keys belong to the signer/admin identity, not to the selected
    # target queue.  Root authorising hc3's queue must therefore read
    # /root/.queuebash/keys/private/root.ed25519.pem, not
    # /home/hc3/.queuebash/keys/private/root.ed25519.pem.
    if [[ -n "${QUEUEBASH_AUTHORISATION_KEY_ROOT:-}" ]]; then
        printf '%s\n' "${QUEUEBASH_AUTHORISATION_KEY_ROOT%/}"
        return 0
    fi
    actor="$(_queue_authorisation_actor_user)"
    if [[ -z "$signer" || "$signer" == "$actor" ]]; then
        _queue_authorisation_key_root
        return 0
    fi
    signer_root="$(_queue_root_for_user "$signer" 2>/dev/null || true)"
    if [[ -n "$signer_root" ]]; then
        printf '%s/keys\n' "$signer_root"
        return 0
    fi
    _queue_authorisation_key_root
}

_queue_authorisation_private_key_file() {
    local name="${1:-}"
    _queue_authorisation_key_name_ok "$name" || return 1
    printf '%s/private/%s.ed25519.pem\n' "$(_queue_authorisation_key_root)" "$name"
}

_queue_authorisation_signer_private_key_file() {
    local signer="${1:-}" name="${2:-}"
    [[ -n "$name" ]] || name="$signer"
    _queue_authorisation_key_name_ok "$name" || return 1
    printf '%s/private/%s.ed25519.pem\n' "$(_queue_authorisation_signer_key_root "$signer")" "$name"
}

_queue_authorisation_public_key_file() {
    local name="${1:-}"
    _queue_authorisation_key_name_ok "$name" || return 1
    printf '%s/public/%s.ed25519.pub.pem\n' "$(_queue_authorisation_key_root)" "$name"
}

_queue_authorisation_key_meta_file() {
    local name="${1:-}"
    _queue_authorisation_key_name_ok "$name" || return 1
    printf '%s/meta/%s.env\n' "$(_queue_authorisation_key_root)" "$name"
}

_queue_base64_one_line() {
    base64 "$@" | tr -d '\n'
}

_queue_base64_decode() {
    base64 -d "$@" 2>/dev/null || base64 --decode "$@"
}

_queue_authorisation_public_key_sha256_file() {
    local f="${1:-}"
    [[ -f "$f" ]] || return 1
    sha256sum "$f" | awk '{print $1}'
}

_queue_authorisation_keygen() {
    local kind="${1:-authorisation}" name="" force=0 priv pub meta created pub_sha pub_b64 key_id suffix
    [[ "$kind" == "authorisation" || "$kind" == "auth" ]] || { echo "Usage: queue keygen authorisation NAME [--force]" >&2; return 2; }
    shift || true
    name="${1:-}"; [[ -n "$name" ]] && shift || true
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --force) force=1; shift ;;
            *) echo "queue keygen authorisation: unexpected argument: $1" >&2; return 2 ;;
        esac
    done
    [[ -n "$name" ]] || name="$(id -un 2>/dev/null || echo root)"
    _queue_authorisation_key_name_ok "$name" || { echo "queue keygen authorisation: key name must be 1-64 safe characters" >&2; return 2; }
    command -v openssl >/dev/null 2>&1 || { echo "queue keygen authorisation: openssl is required for Ed25519 keys" >&2; return 3; }
    priv="$(_queue_authorisation_private_key_file "$name")" || return 2
    pub="$(_queue_authorisation_public_key_file "$name")" || return 2
    meta="$(_queue_authorisation_key_meta_file "$name")" || return 2
    if [[ "$force" -ne 1 && ( -e "$priv" || -e "$pub" || -e "$meta" ) ]]; then
        echo "queue keygen authorisation: key already exists: $name (use --force to replace)" >&2
        return 1
    fi
    mkdir -p "$(dirname "$priv")" "$(dirname "$pub")" "$(dirname "$meta")"
    chmod 0700 "$(dirname "$priv")" 2>/dev/null || true
    chmod 0755 "$(dirname "$pub")" "$(dirname "$meta")" 2>/dev/null || true
    umask 077
    openssl genpkey -algorithm ED25519 -out "$priv" >/dev/null 2>&1 || { echo "queue keygen authorisation: openssl failed generating private key" >&2; return 1; }
    chmod 0600 "$priv" 2>/dev/null || true
    openssl pkey -in "$priv" -pubout -out "$pub" >/dev/null 2>&1 || { rm -f "$priv"; echo "queue keygen authorisation: openssl failed deriving public key" >&2; return 1; }
    chmod 0644 "$pub" 2>/dev/null || true
    created="$(date -Is 2>/dev/null || date)"
    pub_sha="$(_queue_authorisation_public_key_sha256_file "$pub")"
    key_id="${pub_sha:0:16}"
    pub_b64="$(_queue_base64_one_line "$pub")"
    {
        printf 'KEY_NAME=%q\n' "$name"
        printf 'KEY_ID=%q\n' "$key_id"
        printf 'KEY_ALGORITHM=%q\n' "Ed25519"
        printf 'KEY_CREATED_AT=%q\n' "$created"
        printf 'KEY_STATUS=%q\n' "active"
        printf 'KEY_PURPOSE=%q\n' "queue-authorisation-signing"
        printf 'PUBLIC_KEY_SHA256=%q\n' "$pub_sha"
        printf 'PUBLIC_KEY_FILE=%q\n' "$pub"
        printf 'PRIVATE_KEY_FILE=%q\n' "$priv"
    } > "$meta"
    chmod 0644 "$meta" 2>/dev/null || true
    suffix="$(_queue_authorisation_key_suffix "$name")"
    echo "key:       $name"
    echo "key_id:    $key_id"
    echo "algorithm: Ed25519"
    echo "private:   $priv"
    echo "public:    $pub"
    echo "public_sha256: $pub_sha"
    echo ""
    echo "Policy statement lines for policies.d/class-statement/default.env or /etc/bashqueues/policies.d/class-statement/default.env:"
    printf 'CLASS_POLICY_AUTHORISATION_SIGNER_%s_PUBLIC_KEY_SHA256=%q\n' "$suffix" "$pub_sha"
    printf 'CLASS_POLICY_AUTHORISATION_SIGNER_%s_PUBLIC_KEY_PEM_B64=%q\n' "$suffix" "$pub_b64"
}

_queue_authorisation_keys_list() {
    local f line name key_id alg status pub_sha
    shopt -s nullglob
    for f in "$(_queue_authorisation_key_root)"/meta/*.env; do
        line="$(KEY_NAME="" KEY_ID="" KEY_ALGORITHM="" KEY_STATUS="" PUBLIC_KEY_SHA256=""; source "$f" >/dev/null 2>&1 || exit 9; printf '%s\t%s\t%s\t%s\t%s\n' "${KEY_NAME:-$(basename "$f" .env)}" "${KEY_ID:-}" "${KEY_ALGORITHM:-}" "${KEY_STATUS:-}" "${PUBLIC_KEY_SHA256:-}")" || continue
        IFS=$'\t' read -r name key_id alg status pub_sha <<< "$line"
        printf '%-16s key_id=%-16s algorithm=%-8s status=%-8s public_sha=%s\n' "$name" "$key_id" "$alg" "$status" "${pub_sha:0:16}"
    done
    shopt -u nullglob
}

_queue_authorisation_keys_show() {
    local name="${1:-}" meta pub suffix pub_sha pub_b64
    [[ -n "$name" ]] || { echo "Usage: queue keys show NAME" >&2; return 2; }
    meta="$(_queue_authorisation_key_meta_file "$name")" || { echo "queue keys show: invalid key name" >&2; return 2; }
    [[ -f "$meta" ]] || { echo "queue keys show: key not found: $name" >&2; return 1; }
    sed -n '1,120p' "$meta" | sed '/PRIVATE_KEY_FILE=/d'
    pub="$(_queue_authorisation_public_key_file "$name")" || return 2
    if [[ -f "$pub" ]]; then
        pub_sha="$(_queue_authorisation_public_key_sha256_file "$pub")"
        pub_b64="$(_queue_base64_one_line "$pub")"
        suffix="$(_queue_authorisation_key_suffix "$name")"
        echo "POLICY_SIGNER_SUFFIX=$suffix"
        printf 'CLASS_POLICY_AUTHORISATION_SIGNER_%s_PUBLIC_KEY_SHA256=%q\n' "$suffix" "$pub_sha"
        printf 'CLASS_POLICY_AUTHORISATION_SIGNER_%s_PUBLIC_KEY_PEM_B64=%q\n' "$suffix" "$pub_b64"
    fi
}

_queue_authorisation_payload_text() {
    local code="$1" admin="$2" user="$3" cmd_hash="$4" created="$5" expires="$6" reason="$7" queue_root="$8"
    local reason_sha
    reason_sha="$(printf '%s' "$reason" | sha256sum | awk '{print $1}')"
    printf 'BQAUTH-V1\n'
    printf 'code=%s\n' "$code"
    printf 'queue_root=%s\n' "$queue_root"
    printf 'admin=%s\n' "$admin"
    printf 'user=%s\n' "$user"
    printf 'command_sha256=%s\n' "$cmd_hash"
    printf 'created_at=%s\n' "$created"
    printf 'expires_at=%s\n' "$expires"
    printf 'reason_sha256=%s\n' "$reason_sha"
}

_queue_authorisation_policy_public_key_b64() {
    local signer="${1:-}" suffix var
    _queue_security_policy_statement_source >/dev/null 2>&1 || return 1
    suffix="$(_queue_authorisation_key_suffix "$signer")"
    var="CLASS_POLICY_AUTHORISATION_SIGNER_${suffix}_PUBLIC_KEY_PEM_B64"
    printf '%s\n' "${!var:-}"
}

_queue_authorisation_policy_public_key_sha() {
    local signer="${1:-}" suffix var
    _queue_security_policy_statement_source >/dev/null 2>&1 || return 1
    suffix="$(_queue_authorisation_key_suffix "$signer")"
    var="CLASS_POLICY_AUTHORISATION_SIGNER_${suffix}_PUBLIC_KEY_SHA256"
    printf '%s\n' "${!var:-}"
}

_queue_authorisation_signature_requirement() {
    _queue_security_policy_statement_source >/dev/null 2>&1 || { echo "off"; return 0; }
    printf '%s\n' "${CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED:-if-trusted-key}"
}

_queue_authorisation_policy_file_path() {
    local name="${1:-$(_queue_security_policy_statement_name)}"
    _queue_policy_file class-statement "$name" 2>/dev/null || true
}

_queue_authorisation_signature_admin_requirement() {
    # Prints one of:
    #   required      policy requires this admin's authorisation to be signed
    #   optional      unsigned legacy authorisation is allowed
    #   untrusted     policy has a trust list and this admin is not on it
    #   no-public-key signature is mandatory but no public key is declared for this admin
    #   invalid-mode  policy mode is not recognised
    local admin="${1:-}" mode pub_b64
    mode="$(_queue_authorisation_signature_requirement)"
    pub_b64="$(_queue_authorisation_policy_public_key_b64 "$admin")"
    case "${mode,,}" in
        off|none|legacy) echo "optional"; return 0 ;;
        always|required)
            [[ -n "$pub_b64" ]] && { echo "required"; return 0; }
            echo "no-public-key"; return 1
            ;;
        if-trusted-key|if-trusted-keys|trusted|auto|"")
            [[ -n "$pub_b64" ]] && { echo "required"; return 0; }
            if _queue_authorisation_policy_has_any_public_keys; then
                echo "untrusted"
                return 1
            fi
            echo "optional"
            return 0
            ;;
        *) echo "invalid-mode"; return 1 ;;
    esac
}

_queue_authorisation_policy_show() {
    local file mode signers suffix sha_var has_any="no"
    file="$(_queue_authorisation_policy_file_path)"
    mode="$(_queue_authorisation_signature_requirement)"
    _queue_authorisation_policy_has_any_public_keys && has_any="yes"
    echo "class_policy_statement: ${QUEUEBASH_CLASS_POLICY_STATEMENT:-default}"
    echo "policy_file: ${file:-not-found}"
    echo "signature_required: $mode"
    echo "signing_key_root: $(_queue_authorisation_key_root)"
    echo "trusted_public_keys_present: $has_any"
    signers="$(_queue_authorisation_policy_signers_list 2>/dev/null || true)"
    if [[ -z "$signers" ]]; then
        echo "trusted_signers: none"
        return 0
    fi
    echo "trusted_signers: $signers"
    for suffix in $signers; do
        sha_var="CLASS_POLICY_AUTHORISATION_SIGNER_${suffix}_PUBLIC_KEY_SHA256"
        echo "signer_${suffix}: public_sha=${!sha_var:-}"
    done
}

_queue_authorisation_sign_fields() {
    local code="$1" admin="$2" user="$3" cmd_hash="$4" created="$5" expires="$6" reason="$7" key_name="$8"
    local priv payload sig sig_b64 payload_sha
    [[ -n "$key_name" ]] || key_name="$admin"
    priv="$(_queue_authorisation_signer_private_key_file "$admin" "$key_name")" || return 1
    [[ -f "$priv" ]] || return 1
    command -v openssl >/dev/null 2>&1 || return 1
    payload="$(mktemp)" || return 1
    sig="$(mktemp)" || { rm -f "$payload"; return 1; }
    _queue_authorisation_payload_text "$code" "$admin" "$user" "$cmd_hash" "$created" "$expires" "$reason" "$(_queue_root)" > "$payload"
    payload_sha="$(sha256sum "$payload" | awk '{print $1}')"
    if ! openssl pkeyutl -sign -rawin -inkey "$priv" -in "$payload" -out "$sig" >/dev/null 2>&1; then
        rm -f "$payload" "$sig"
        return 1
    fi
    sig_b64="$(_queue_base64_one_line "$sig")"
    rm -f "$payload" "$sig"
    printf '%s\t%s\t%s\n' "$key_name" "$payload_sha" "$sig_b64"
}

_queue_authorisation_verify_signature_loaded() {
    local mode pub_b64 expected_sha pubfile payload sigfile actual_sha payload_sha expected_payload_sha
    mode="$(_queue_authorisation_signature_requirement)"
    pub_b64="$(_queue_authorisation_policy_public_key_b64 "${AUTHORISATION_ADMIN:-}")"
    expected_sha="$(_queue_authorisation_policy_public_key_sha "${AUTHORISATION_ADMIN:-}")"
    case "${mode,,}" in
        off|none|legacy) echo "valid-unsigned"; return 0 ;;
        always|required)
            [[ -n "$pub_b64" ]] || { echo "invalid-no-policy-public-key"; return 1; }
            ;;
        if-trusted-key|if-trusted-keys|trusted|auto|"")
            if [[ -z "$pub_b64" ]]; then
                if _queue_authorisation_policy_has_any_public_keys; then
                    echo "invalid-untrusted-admin"
                    return 1
                fi
                echo "valid-unsigned"
                return 0
            fi
            ;;
        *) echo "invalid-policy-signature-mode"; return 1 ;;
    esac
    [[ -n "${AUTHORISATION_SIGNATURE_B64:-}" ]] || { echo "invalid-missing-signature"; return 1; }
    pubfile="$(mktemp)" || return 1
    payload="$(mktemp)" || { rm -f "$pubfile"; return 1; }
    sigfile="$(mktemp)" || { rm -f "$pubfile" "$payload"; return 1; }
    printf '%s' "$pub_b64" | _queue_base64_decode > "$pubfile" || { rm -f "$pubfile" "$payload" "$sigfile"; echo "invalid-policy-public-key"; return 1; }
    actual_sha="$(_queue_authorisation_public_key_sha256_file "$pubfile" 2>/dev/null || true)"
    if [[ -n "$expected_sha" && "$actual_sha" != "$expected_sha" ]]; then
        rm -f "$pubfile" "$payload" "$sigfile"
        echo "invalid-policy-public-key-sha"
        return 1
    fi
    _queue_authorisation_payload_text "${AUTHORISATION_CODE:-}" "${AUTHORISATION_ADMIN:-}" "${AUTHORISATION_USER:-}" "${AUTHORISATION_COMMAND_SHA256:-}" "${AUTHORISATION_CREATED_AT:-}" "${AUTHORISATION_EXPIRES_AT:-never}" "${AUTHORISATION_REASON:-}" "${AUTHORISATION_QUEUE_ROOT:-$(_queue_root)}" > "$payload"
    payload_sha="$(sha256sum "$payload" | awk '{print $1}')"
    expected_payload_sha="${AUTHORISATION_SIGNATURE_PAYLOAD_SHA256:-}"
    if [[ -n "$expected_payload_sha" && "$payload_sha" != "$expected_payload_sha" ]]; then
        rm -f "$pubfile" "$payload" "$sigfile"
        echo "invalid-payload-hash"
        return 1
    fi
    printf '%s' "${AUTHORISATION_SIGNATURE_B64:-}" | _queue_base64_decode > "$sigfile" || { rm -f "$pubfile" "$payload" "$sigfile"; echo "invalid-signature-b64"; return 1; }
    if openssl pkeyutl -verify -rawin -pubin -inkey "$pubfile" -sigfile "$sigfile" -in "$payload" >/dev/null 2>&1; then
        rm -f "$pubfile" "$payload" "$sigfile"
        echo "valid-signed"
        return 0
    fi
    rm -f "$pubfile" "$payload" "$sigfile"
    echo "invalid-signature"
    return 1
}

_queue_authorisation_dir() {
    printf '%s\n' "$(_queue_root)/authorisations"
}

_queue_authorisation_file() {
    local code
    code="$(_queue_authorisation_normalise_code "${1:-}")" || return 1
    printf '%s/%s.env\n' "$(_queue_authorisation_dir)" "$code"
}

_queue_authorisation_publish_file_permissions() {
    # Authorisation records are queue evidence.  They may be created by root
    # while operating inside another user's selected queue, so they must not
    # inherit root-only readability (for example 0640 root:root).  Publish them
    # read-only and world-readable so the queue owner/panel can validate them
    # without changing the record owner/group or relying on a particular group.
    local file="${1:-}"
    [[ -n "$file" && -e "$file" ]] || return 0
    chmod 0444 "$file" 2>/dev/null || chmod 0644 "$file" 2>/dev/null || true
}

_queue_authorisation_policy_has_any_public_keys() {
    _queue_security_policy_statement_source >/dev/null 2>&1 || return 1
    compgen -A variable CLASS_POLICY_AUTHORISATION_SIGNER_ 2>/dev/null | grep -q '_PUBLIC_KEY_PEM_B64$'
}

_queue_authorisation_policy_signers_list() {
    local var s out=""
    _queue_security_policy_statement_source >/dev/null 2>&1 || return 1
    for var in $(compgen -A variable CLASS_POLICY_AUTHORISATION_SIGNER_ 2>/dev/null | LC_ALL=C sort); do
        [[ "$var" == *_PUBLIC_KEY_PEM_B64 ]] || continue
        [[ -n "${!var:-}" ]] || continue
        s="${var#CLASS_POLICY_AUTHORISATION_SIGNER_}"
        s="${s%_PUBLIC_KEY_PEM_B64}"
        out+=" ${s}"
    done
    printf '%s\n' "${out# }"
}

_queue_authorisation_generate_code() {
    local root code try
    root="$(_queue_root)"
    mkdir -p "$root/authorisations"
    for try in 1 2 3 4 5 6 7 8 9 10; do
        code="$(LC_ALL=C tr -dc 'A-Z0-9' </dev/urandom 2>/dev/null | head -c 5 || true)"
        if [[ -z "$code" ]]; then
            code="$(date +%s%N | sha256sum | tr -dc 'A-Z0-9' | head -c 5)"
        fi
        [[ -n "$code" && ! -e "$root/authorisations/$code.env" ]] && { printf '%s\n' "$code"; return 0; }
    done
    return 1
}

_queue_authorisation_generate() {
    local admin="" user="" reason="" expires="never" code="" key_name="" command=() cmd_hash file created sign_line sig_key sig_payload_sha sig_b64 sig_need integrity tmpfile
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --admin) admin="${2:-}"; shift 2 ;;
            --user) user="${2:-}"; shift 2 ;;
            --reason) reason="${2:-}"; shift 2 ;;
            --expires|--expires-at) expires="${2:-}"; shift 2 ;;
            --code) code="${2:-}"; shift 2 ;;
            --key|--signing-key) key_name="${2:-}"; shift 2 ;;
            --) shift; command=("$@"); break ;;
            *) echo "queue authorisation generate: unexpected argument: $1" >&2; return 2 ;;
        esac
    done
    [[ -n "$admin" ]] || admin="$(id -un 2>/dev/null || echo unknown)"
    [[ -n "$user" ]] || user="$(id -un 2>/dev/null || echo unknown)"
    [[ "${#command[@]}" -gt 0 ]] || { echo "Usage: queue authorisation generate --admin ADMIN --user USER [--reason TEXT] [--expires never] -- <command>" >&2; return 2; }
    if [[ -n "$code" ]]; then
        code="$(_queue_authorisation_normalise_code "$code")" || { echo "queue authorisation generate: code must be 1-5 case-insensitive letters/numbers" >&2; return 2; }
    else
        code="$(_queue_authorisation_generate_code)" || { echo "queue authorisation generate: unable to allocate code" >&2; return 1; }
    fi
    cmd_hash="$(_queue_command_hash_from_args "${command[@]}")"
    file="$(_queue_authorisation_file "$code")" || return 2
    [[ ! -e "$file" ]] || { echo "queue authorisation generate: code already exists: $code" >&2; return 1; }
    mkdir -p "$(dirname "$file")"
    created="$(date -Is 2>/dev/null || date)"
    sign_line="$(_queue_authorisation_sign_fields "$code" "$admin" "$user" "$cmd_hash" "$created" "$expires" "$reason" "$key_name" 2>/dev/null || true)"
    IFS=$'\t' read -r sig_key sig_payload_sha sig_b64 <<< "$sign_line"
    sig_need="$(_queue_authorisation_signature_admin_requirement "$admin" 2>/dev/null || true)"
    case "$sig_need" in
        required)
            [[ -n "$sig_b64" ]] || { echo "queue authorisation generate: policy requires a valid signature for admin '$admin' but no matching private key could sign this authorisation" >&2; return 1; }
            ;;
        untrusted)
            echo "queue authorisation generate: admin '$admin' is not trusted by the active class policy statement" >&2; return 1 ;;
        no-public-key)
            echo "queue authorisation generate: policy requires signed authorisations but declares no public key for admin '$admin'" >&2; return 1 ;;
        invalid-mode)
            echo "queue authorisation generate: invalid CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED mode" >&2; return 1 ;;
    esac
    tmpfile="$(mktemp "$(_queue_authorisation_dir)/.${code}.candidate.XXXXXX")" || { echo "queue authorisation generate: unable to create candidate file" >&2; return 1; }
    {
        printf 'AUTHORISATION_CODE=%q\n' "$code"
        printf 'AUTHORISATION_ADMIN=%q\n' "$admin"
        printf 'AUTHORISATION_USER=%q\n' "$user"
        printf 'AUTHORISATION_QUEUE_ROOT=%q\n' "$(_queue_root)"
        printf 'AUTHORISATION_COMMAND_SHA256=%q\n' "$cmd_hash"
        printf 'AUTHORISATION_CREATED_AT=%q\n' "$created"
        printf 'AUTHORISATION_EXPIRES_AT=%q\n' "$expires"
        printf 'AUTHORISATION_STATUS=%q\n' "active"
        printf 'AUTHORISATION_REASON=%q\n' "$reason"
        [[ -n "$sig_b64" ]] && printf 'AUTHORISATION_SIGNING_KEY=%q\n' "$sig_key"
        [[ -n "$sig_payload_sha" ]] && printf 'AUTHORISATION_SIGNATURE_PAYLOAD_SHA256=%q\n' "$sig_payload_sha"
        [[ -n "$sig_b64" ]] && printf 'AUTHORISATION_SIGNATURE_B64=%q\n' "$sig_b64"
        printf 'AUTHORISATION_COMMAND=('; printf ' %q' "${command[@]}"; printf ' )\n'
    } > "$tmpfile" || { rm -f "$tmpfile"; echo "queue authorisation generate: failed to create authorisation candidate" >&2; return 1; }
    integrity="$(_queue_authorisation_file_status "$tmpfile" 2>/dev/null || true)"
    if [[ "$integrity" != "valid-signed" && "$integrity" != "valid-unsigned" ]]; then
        rm -f "$tmpfile"
        if [[ "$integrity" == "invalid-missing-signature" && "$sig_need" == "required" ]]; then
            echo "queue authorisation generate: policy requires a valid signature for admin '$admin' but no matching private key could sign this authorisation" >&2
        else
            echo "queue authorisation generate: refused to create invalid authorisation candidate: ${integrity:-invalid}" >&2
        fi
        return 1
    fi
    if [[ "$sig_need" == "required" && "$integrity" != "valid-signed" ]]; then
        rm -f "$tmpfile"
        echo "queue authorisation generate: policy requires a valid signature for admin '$admin' but no matching private key could sign this authorisation" >&2
        return 1
    fi
    mv "$tmpfile" "$file" || { rm -f "$tmpfile"; echo "queue authorisation generate: failed to publish authorisation file" >&2; return 1; }
    _queue_authorisation_publish_file_permissions "$file"
    echo "authorisation: $code"
    echo "queue:         $(_queue_root)"
    echo "admin:         $admin"
    echo "user:          $user"
    echo "command_sha:   $cmd_hash"
    [[ -n "$sig_b64" ]] && echo "signature:     signed" || echo "signature:     unsigned"
}

_queue_authorisation_validate() {
    local code="${1:-}" user="${2:-}" reason_context="${3:-submit}" file cmd_hash now exp
    shift 3 || true
    code="$(_queue_authorisation_normalise_code "$code")" || { echo "queue $reason_context: invalid authorisation code: ${1:-}" >&2; return 2; }
    file="$(_queue_authorisation_file "$code")" || return 2
    [[ -f "$file" ]] || { echo "queue $reason_context: authorisation not found in this queue: $code" >&2; return 1; }
    (
        AUTHORISATION_CODE=""; AUTHORISATION_ADMIN=""; AUTHORISATION_USER=""; AUTHORISATION_COMMAND_SHA256=""; AUTHORISATION_EXPIRES_AT="never"; AUTHORISATION_STATUS="active"
        AUTHORISATION_COMMAND=()
        source "$file" >/dev/null 2>&1 || exit 10
        [[ "${AUTHORISATION_STATUS,,}" == "active" ]] || { echo "queue $reason_context: authorisation is not active: $code" >&2; exit 11; }
        [[ -z "${AUTHORISATION_USER:-}" || "${AUTHORISATION_USER}" == "$user" || "${AUTHORISATION_USER}" == "*" ]] || { echo "queue $reason_context: authorisation $code is for user ${AUTHORISATION_USER}, not $user" >&2; exit 12; }
        if [[ "${#AUTHORISATION_COMMAND[@]}" -eq 0 || "$(_queue_command_hash_from_args "${AUTHORISATION_COMMAND[@]}")" != "${AUTHORISATION_COMMAND_SHA256:-}" ]]; then
            echo "queue $reason_context: authorisation $code file integrity check failed" >&2
            exit 15
        fi
        cmd_hash="$(_queue_command_hash_from_args "$@")"
        [[ -n "${AUTHORISATION_COMMAND_SHA256:-}" && "$cmd_hash" == "$AUTHORISATION_COMMAND_SHA256" ]] || { echo "queue $reason_context: authorisation $code does not match this command" >&2; exit 13; }
        if [[ -n "${AUTHORISATION_EXPIRES_AT:-}" && "${AUTHORISATION_EXPIRES_AT}" != "never" ]]; then
            now="$(date +%s 2>/dev/null || echo 0)"; exp="$(date -d "$AUTHORISATION_EXPIRES_AT" +%s 2>/dev/null || echo 0)"
            [[ "$exp" -le 0 || "$now" -le "$exp" ]] || { echo "queue $reason_context: authorisation $code expired at $AUTHORISATION_EXPIRES_AT" >&2; exit 14; }
        fi
        sig_status="$(_queue_authorisation_verify_signature_loaded)" || { echo "queue $reason_context: authorisation $code signature check failed: $sig_status" >&2; exit 16; }
        exit 0
    )
}


_queue_authorisation_find_valid_for_command() {
    # Prints the first valid, active, unexpired authorisation code in the selected
    # queue that matches USER and the exact command argv supplied after USER.
    local user="${1:-}" f code
    shift || true
    [[ -n "$user" && "$#" -gt 0 ]] || return 1
    shopt -s nullglob
    for f in "$(_queue_authorisation_dir)"/*.env; do
        [[ -r "$f" ]] || continue
        code="$(basename "$f" .env)"
        if _queue_authorisation_validate "$code" "$user" auto "$@" >/dev/null 2>&1; then
            shopt -u nullglob
            printf '%s\n' "$code"
            return 0
        fi
    done
    shopt -u nullglob
    return 1
}

_queue_job_append_security_exemption() {
    local jobf="${1:-}" type="${2:-}" detail="${3:-}" code="${4:-}"
    local id state action
    [[ -n "$jobf" && -f "$jobf" && -n "$type" ]] || return 0
    case "$type" in
        code-approved) action="run_with_authorisation" ;;
        description-approved) action="run_with_reason" ;;
        policy-approved) action="run_with_policy_grant" ;;
        *) action="run_with_exemption" ;;
    esac
    {
        printf '
# Security exemption recorded at %q
' "$(date -Is 2>/dev/null || date)"
        printf 'SECURITY_EXEMPTION_TYPE=%q
' "$type"
        [[ -n "$detail" ]] && printf 'SECURITY_EXEMPTION_DETAIL=%q
' "$detail"
        [[ -n "$code" ]] && printf 'SECURITY_AUTHORISATION_CODE=%q
' "$code"
        printf 'SECURITY_EXEMPTION_ACTION=%q
' "$action"
    } >> "$jobf" 2>/dev/null || true
    id="$(basename "$jobf" .job)"
    state="$(basename "$(dirname "$jobf")")"
    _queue_log_event "security_exemption" "$id" "$(_queue_job_name "$jobf" 2>/dev/null || echo -)" "$state" "type=$type action=$action${code:+ code=$code}${detail:+ detail=$detail}" 2>/dev/null || true
}

_queue_authorisation_file_status() {
    local file="${1:-}"
    [[ -f "$file" ]] || { echo "missing"; return 1; }
    (
        AUTHORISATION_CODE=""; AUTHORISATION_ADMIN=""; AUTHORISATION_USER=""; AUTHORISATION_COMMAND_SHA256=""; AUTHORISATION_EXPIRES_AT="never"; AUTHORISATION_STATUS="active"; AUTHORISATION_REASON=""
        AUTHORISATION_COMMAND=()
        # shellcheck disable=SC1090
        if [[ ! -r "$file" ]]; then
            echo "invalid-unreadable"
            exit 1
        fi
        source "$file" >/dev/null 2>&1 || { echo "invalid-source"; exit 1; }
        if [[ "${AUTHORISATION_STATUS,,}" != "active" ]]; then
            echo "invalid-status:${AUTHORISATION_STATUS:-unset}"
            exit 1
        fi
        if [[ -n "${AUTHORISATION_EXPIRES_AT:-}" && "${AUTHORISATION_EXPIRES_AT}" != "never" ]]; then
            local now exp
            now="$(date +%s 2>/dev/null || echo 0)"
            exp="$(date -d "$AUTHORISATION_EXPIRES_AT" +%s 2>/dev/null || echo 0)"
            if [[ "$exp" -gt 0 && "$now" -gt "$exp" ]]; then
                echo "invalid-expired"
                exit 1
            fi
        fi
        if [[ "${#AUTHORISATION_COMMAND[@]}" -eq 0 ]]; then
            echo "invalid-no-command"
            exit 1
        fi
        local declared
        declared="$(_queue_command_hash_from_args "${AUTHORISATION_COMMAND[@]}")"
        if [[ -z "${AUTHORISATION_COMMAND_SHA256:-}" || "$declared" != "$AUTHORISATION_COMMAND_SHA256" ]]; then
            echo "invalid-command-hash"
            exit 1
        fi
        local sig_status
        sig_status="$(_queue_authorisation_verify_signature_loaded)" || { echo "$sig_status"; exit 1; }
        echo "$sig_status"
        exit 0
    )
}

_queue_authorisation_list() {
    local f code user admin status exp hash integrity line
    shopt -s nullglob
    for f in "$(_queue_authorisation_dir)"/*.env; do
        [[ -f "$f" ]] || continue
        if line="$(
            AUTHORISATION_CODE=""; AUTHORISATION_ADMIN=""; AUTHORISATION_USER=""; AUTHORISATION_COMMAND_SHA256=""; AUTHORISATION_EXPIRES_AT="never"; AUTHORISATION_STATUS="unknown"; AUTHORISATION_COMMAND=()
            # shellcheck disable=SC1090
            [[ -r "$f" ]] || exit 8
            source "$f" >/dev/null 2>&1 || exit 9
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${AUTHORISATION_CODE:-$(basename "$f" .env)}" "${AUTHORISATION_USER:-}" "${AUTHORISATION_ADMIN:-}" "${AUTHORISATION_STATUS:-}" "${AUTHORISATION_EXPIRES_AT:-}" "${AUTHORISATION_COMMAND_SHA256:-}"
        )"; then
            IFS=$'\t' read -r code user admin status exp hash <<< "$line"
        else
            code="$(basename "$f" .env)"
            user=""
            admin=""
            status="invalid-source"
            exp=""
            hash=""
        fi
        integrity="$(_queue_authorisation_file_status "$f" 2>/dev/null || true)"
        [[ -n "$integrity" ]] || integrity="invalid"
        printf '%-5s user=%-12s admin=%-12s status=%-14s integrity=%-24s expires=%-20s command=%s\n' "$code" "$user" "$admin" "$status" "$integrity" "$exp" "${hash:0:16}"
    done
    shopt -u nullglob
}

_queue_authorisation_from_job_command() {
    local jobf="${1:-}"
    [[ -f "$jobf" ]] || return 1
    (
        COMMAND=()
        # shellcheck disable=SC1090
        source "$jobf" >/dev/null 2>&1 || exit 1
        [[ "${#COMMAND[@]}" -gt 0 ]] || exit 2
        _queue_command_hash_from_args "${COMMAND[@]}"
    )
}

_queue_authorise_job() {
    local qid="${1:-}" reason="" admin="" user="" expires="never" code="" key_name="" jobf cmd_hash file created before_owner after_owner sign_line sig_key sig_payload_sha sig_b64 sig_need integrity tmpfile
    shift || true
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --reason) reason="${2:-}"; shift 2 ;;
            --admin) admin="${2:-}"; shift 2 ;;
            --user) user="${2:-}"; shift 2 ;;
            --expires|--expires-at) expires="${2:-}"; shift 2 ;;
            --code) code="${2:-}"; shift 2 ;;
            --key|--signing-key) key_name="${2:-}"; shift 2 ;;
            *) echo "queue authorise: unexpected argument: $1" >&2; return 2 ;;
        esac
    done
    [[ -n "$qid" ]] || { echo "Usage: queue authorise <qid> [--reason TEXT] [--code CODE]" >&2; return 2; }
    jobf="$(_queue_job_file_for_id_any_state "$qid")" || { echo "queue authorise: job not found: $qid" >&2; return 1; }
    [[ -n "$admin" ]] || admin="$(id -un 2>/dev/null || echo unknown)"
    # Existing-job authorisation is approval for the queue owner / selected queue user,
    # not necessarily for the shell user that is performing the approval and not
    # necessarily for a stale SUBMIT_USER field.  This matters when root is operating
    # in another user's queue via `queue --queue-user USER authorise QID`: admin=root,
    # target user=USER.
    [[ -n "$user" ]] || user="${QUEUEBASH_SELECTED_USER:-}"
    [[ -n "$user" ]] || user="$(_queue_root_owner_user 2>/dev/null || true)"
    [[ -n "$user" ]] || user="$(_queue_job_var_value "$jobf" SUBMIT_USER 2>/dev/null || true)"
    [[ -n "$user" ]] || user="$(id -un 2>/dev/null || echo unknown)"
    if [[ -n "$code" ]]; then
        code="$(_queue_authorisation_normalise_code "$code")" || { echo "queue authorise: code must be 1-5 case-insensitive letters/numbers" >&2; return 2; }
    else
        code="$(_queue_authorisation_generate_code)" || { echo "queue authorise: unable to allocate code" >&2; return 1; }
    fi
    file="$(_queue_authorisation_file "$code")" || return 2
    [[ ! -e "$file" ]] || { echo "queue authorise: code already exists: $code" >&2; return 1; }
    cmd_hash="$(_queue_authorisation_from_job_command "$jobf")" || { echo "queue authorise: job has no readable COMMAND array: $qid" >&2; return 1; }
    created="$(date -Is 2>/dev/null || date)"
    sign_line="$(_queue_authorisation_sign_fields "$code" "$admin" "$user" "$cmd_hash" "$created" "$expires" "$reason" "$key_name" 2>/dev/null || true)"
    IFS=$'\t' read -r sig_key sig_payload_sha sig_b64 <<< "$sign_line"
    sig_need="$(_queue_authorisation_signature_admin_requirement "$admin" 2>/dev/null || true)"
    case "$sig_need" in
        required)
            [[ -n "$sig_b64" ]] || { echo "queue authorise: policy requires a valid signature for admin '$admin' but no matching private key could sign this authorisation" >&2; return 1; }
            ;;
        untrusted)
            echo "queue authorise: admin '$admin' is not trusted by the active class policy statement" >&2; return 1 ;;
        no-public-key)
            echo "queue authorise: policy requires signed authorisations but declares no public key for admin '$admin'" >&2; return 1 ;;
        invalid-mode)
            echo "queue authorise: invalid CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED mode" >&2; return 1 ;;
    esac
    mkdir -p "$(dirname "$file")"
    tmpfile="$(mktemp "$(_queue_authorisation_dir)/.${code}.candidate.XXXXXX")" || { echo "queue authorise: unable to create authorisation candidate" >&2; return 1; }
    (
        COMMAND=()
        # shellcheck disable=SC1090
        source "$jobf" >/dev/null 2>&1 || exit 1
        {
            printf 'AUTHORISATION_CODE=%q\n' "$code"
            printf 'AUTHORISATION_ADMIN=%q\n' "$admin"
            printf 'AUTHORISATION_USER=%q\n' "$user"
            printf 'AUTHORISATION_QUEUE_ROOT=%q\n' "$(_queue_root)"
            printf 'AUTHORISATION_COMMAND_SHA256=%q\n' "$cmd_hash"
            printf 'AUTHORISATION_CREATED_AT=%q\n' "$created"
            printf 'AUTHORISATION_EXPIRES_AT=%q\n' "$expires"
            printf 'AUTHORISATION_STATUS=%q\n' "active"
            printf 'AUTHORISATION_REASON=%q\n' "$reason"
            printf 'AUTHORISATION_JOB_ID=%q\n' "$qid"
            [[ -n "$sig_b64" ]] && printf 'AUTHORISATION_SIGNING_KEY=%q\n' "$sig_key"
            [[ -n "$sig_payload_sha" ]] && printf 'AUTHORISATION_SIGNATURE_PAYLOAD_SHA256=%q\n' "$sig_payload_sha"
            [[ -n "$sig_b64" ]] && printf 'AUTHORISATION_SIGNATURE_B64=%q\n' "$sig_b64"
            printf 'AUTHORISATION_COMMAND=('; printf ' %q' "${COMMAND[@]}"; printf ' )\n'
        } > "$tmpfile"
    ) || { rm -f "$tmpfile"; echo "queue authorise: failed to create authorisation candidate" >&2; return 1; }
    integrity="$(_queue_authorisation_file_status "$tmpfile" 2>/dev/null || true)"
    if [[ "$integrity" != "valid-signed" && "$integrity" != "valid-unsigned" ]]; then
        rm -f "$tmpfile"
        if [[ "$integrity" == "invalid-missing-signature" && "$sig_need" == "required" ]]; then
            echo "queue authorise: policy requires a valid signature for admin '$admin' but no matching private key could sign this authorisation" >&2
        else
            echo "queue authorise: refused to stamp invalid authorisation candidate: ${integrity:-invalid}" >&2
        fi
        return 1
    fi
    if [[ "$sig_need" == "required" && "$integrity" != "valid-signed" ]]; then
        rm -f "$tmpfile"
        echo "queue authorise: policy requires a valid signature for admin '$admin' but no matching private key could sign this authorisation" >&2
        return 1
    fi
    mv "$tmpfile" "$file" || { rm -f "$tmpfile"; echo "queue authorise: failed to publish authorisation file" >&2; return 1; }
    _queue_authorisation_publish_file_permissions "$file"

    before_owner="$(stat -c '%u:%g' "$jobf" 2>/dev/null || true)"
    {
        printf '\n# Security authorisation stamped by queue authorise at %q\n' "$created"
        printf 'SECURITY_AUTHORISATION_CODE=%q\n' "$code"
        printf 'SECURITY_AUTHORISATION_ADMIN=%q\n' "$admin"
        printf 'SECURITY_AUTHORISATION_AT=%q\n' "$created"
        [[ -n "$reason" ]] && printf 'SECURITY_AUTHORISATION_REASON=%q\n' "$reason"
    } >> "$jobf"
    after_owner="$(stat -c '%u:%g' "$jobf" 2>/dev/null || true)"
    if [[ -n "$before_owner" && -n "$after_owner" && "$before_owner" != "$after_owner" ]]; then
        echo "queue authorise: WARNING: job file owner/group changed unexpectedly: $before_owner -> $after_owner" >&2
    fi
    echo "authorised: $qid"
    echo "authorisation: $code"
    echo "admin: $admin"
    echo "user: $user"
    [[ -n "$sig_b64" ]] && echo "signature: signed" || echo "signature: unsigned"
    echo "integrity: $(_queue_authorisation_file_status "$file" 2>/dev/null || true)"
    echo "job_file: $jobf"
}


_queue_class_policy_user_suffix() {
    local s="${1:-}"
    s="${s^^}"
    s="${s//[^A-Z0-9]/_}"
    [[ -n "$s" ]] || s="UNKNOWN"
    printf '%s\n' "$s"
}

_queue_class_policy_values_all_in_list() {
    # $1 = requested values, comma/space separated. $2 = allowed values, comma/space separated.
    local requested="${1:-}" allowed=" ${2//,/ } " v
    requested="${requested//,/ }"
    [[ -n "${requested// /}" ]] || return 0
    for v in $requested; do
        [[ " $allowed " == *" $v "* || " $allowed " == *" * "* || " $allowed " == *" all "* ]] || return 1
    done
    return 0
}

_queue_class_policy_user_grant_values() {
    # Prints standing and command-specific grant values for a user and grant name.
    # Grant names intentionally match policy suffixes such as ALLOW_ADD_PORTS.
    local user="${1:-}" grant="${2:-}" cmd_hash="${3:-}" us hs var out=""
    us="$(_queue_class_policy_user_suffix "$user")"
    hs="${cmd_hash^^}"
    hs="${hs//[^A-Z0-9]/_}"
    for var in \
        "CLASS_POLICY_USER_${us}_${grant}" \
        "CLASS_POLICY_USER_${us}_GENERAL_${grant}" \
        "CLASS_POLICY_USER_ALL_${grant}" \
        "CLASS_POLICY_USER_ALL_GENERAL_${grant}"; do
        [[ -n "${!var:-}" ]] && out+=" ${!var}"
    done
    if [[ -n "$hs" ]]; then
        for var in \
            "CLASS_POLICY_USER_${us}_COMMAND_${hs}_${grant}" \
            "CLASS_POLICY_USER_${us}_COMMAND_${hs:0:16}_${grant}" \
            "CLASS_POLICY_USER_ALL_COMMAND_${hs}_${grant}" \
            "CLASS_POLICY_USER_ALL_COMMAND_${hs:0:16}_${grant}"; do
            [[ -n "${!var:-}" ]] && out+=" ${!var}"
        done
    fi
    printf '%s\n' "${out# }"
}

_queue_class_policy_user_grant_covers() {
    local user="${1:-}" grant="${2:-}" requested="${3:-}" cmd_hash="${4:-}" values
    [[ -n "${requested//,/}" ]] || return 0
    values="$(_queue_class_policy_user_grant_values "$user" "$grant" "$cmd_hash")"
    [[ -n "$values" ]] || return 1
    _queue_class_policy_values_all_in_list "$requested" "$values"
}

_queue_class_policy_user_exception_grants_cover() {
    local user="$1" sandbox_override="$2" seccomp_allow="$3" drop_cap="$4" add_port="$5" cmd_hash="$6"
    [[ -z "$sandbox_override" ]] || _queue_class_policy_user_grant_covers "$user" ALLOW_SANDBOX_OVERRIDES "$sandbox_override" "$cmd_hash" || return 1
    [[ -z "$seccomp_allow" ]] || _queue_class_policy_user_grant_covers "$user" ALLOW_SECCOMP_ALLOWS "$seccomp_allow" "$cmd_hash" || return 1
    [[ -z "$drop_cap" ]] || _queue_class_policy_user_grant_covers "$user" ALLOW_DROP_CAPS "$drop_cap" "$cmd_hash" || return 1
    [[ -z "$add_port" ]] || _queue_class_policy_user_grant_covers "$user" ALLOW_ADD_PORTS "$add_port" "$cmd_hash" || return 1
    return 0
}

_queue_class_policy_user_weak_policy_grant_covers() {
    local user="$1" sandbox_level="$2" seccomp_profile="$3" cmd_hash="$4" weak_sandbox_reason="$5" weak_seccomp_reason="$6"
    if [[ -n "$weak_sandbox_reason" ]] && _queue_security_policy_value_in_list "$sandbox_level" "$weak_sandbox_reason"; then
        _queue_class_policy_user_grant_covers "$user" ALLOW_SANDBOX_POLICIES "$sandbox_level" "$cmd_hash" || return 1
    fi
    if [[ -n "$weak_seccomp_reason" ]] && _queue_security_policy_value_in_list "$seccomp_profile" "$weak_seccomp_reason"; then
        _queue_class_policy_user_grant_covers "$user" ALLOW_SECCOMP_POLICIES "$seccomp_profile" "$cmd_hash" || return 1
    fi
    return 0
}

_queue_submit_policy_check() {
    local class="$1" submit_user="$2" reason="$3" auth_code="$4" sandbox_level="$5" seccomp_profile="$6" exception_sandbox="$7" exception_seccomp="$8" exception_drop="$9" exception_port="${10}" sandbox_explicit="${11:-0}" seccomp_explicit="${12:-0}"
    shift 12 || true
    local allowed_sandbox allowed_seccomp exception_requires_reason weak_sandbox_reason weak_seccomp_reason mode=none cmd_hash auto_code grant_detail=""
    QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_TYPE=""
    QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_DETAIL=""
    QUEUEBASH_SUBMIT_AUTO_AUTHORISATION_CODE=""
    _queue_security_policy_statement_source >/dev/null 2>&1 || return 0
    allowed_sandbox="${CLASS_POLICY_USER_SANDBOX_POLICIES:-}"
    allowed_seccomp="${CLASS_POLICY_USER_SECCOMP_POLICIES:-}"
    exception_requires_reason="${CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE:-reason-or-authorisation}"
    weak_sandbox_reason="${CLASS_POLICY_SANDBOX_REASON_REQUIRED:-off}"
    weak_seccomp_reason="${CLASS_POLICY_SECCOMP_REASON_REQUIRED:-off}"
    cmd_hash="$(_queue_command_hash_from_args "$@")"

    if [[ -n "$allowed_sandbox" && -n "$sandbox_level" ]]; then
        _queue_security_policy_value_in_list "$sandbox_level" "$allowed_sandbox" || { echo "queue submit: sandbox policy '$sandbox_level' is not in user-selectable range: $allowed_sandbox" >&2; return 2; }
    fi
    if [[ -n "$allowed_seccomp" && -n "$seccomp_profile" ]]; then
        _queue_security_policy_value_in_list "$seccomp_profile" "$allowed_seccomp" || { echo "queue submit: seccomp policy '$seccomp_profile' is not in user-selectable range: $allowed_seccomp" >&2; return 2; }
    fi

    if [[ -n "$exception_sandbox$exception_seccomp$exception_drop$exception_port" ]]; then
        if _queue_class_policy_user_exception_grants_cover "$submit_user" "$exception_sandbox" "$exception_seccomp" "$exception_drop" "$exception_port" "$cmd_hash"; then
            QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_TYPE="policy-approved"
            QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_DETAIL="standing policy grant covers requested exception overlay"
            return 0
        fi
        mode="$exception_requires_reason"
    elif [[ "$sandbox_explicit" == "1" && -n "$weak_sandbox_reason" ]] && _queue_security_policy_value_in_list "$sandbox_level" "$weak_sandbox_reason"; then
        if _queue_class_policy_user_weak_policy_grant_covers "$submit_user" "$sandbox_level" "$seccomp_profile" "$cmd_hash" "$weak_sandbox_reason" "$weak_seccomp_reason"; then
            QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_TYPE="policy-approved"
            QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_DETAIL="standing policy grant covers weak sandbox/seccomp selection"
            return 0
        fi
        mode="${CLASS_POLICY_WEAK_POLICY_REQUIRE:-reason-or-authorisation}"
    elif [[ "$seccomp_explicit" == "1" && -n "$weak_seccomp_reason" ]] && _queue_security_policy_value_in_list "$seccomp_profile" "$weak_seccomp_reason"; then
        if _queue_class_policy_user_weak_policy_grant_covers "$submit_user" "$sandbox_level" "$seccomp_profile" "$cmd_hash" "$weak_sandbox_reason" "$weak_seccomp_reason"; then
            QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_TYPE="policy-approved"
            QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_DETAIL="standing policy grant covers weak sandbox/seccomp selection"
            return 0
        fi
        mode="${CLASS_POLICY_WEAK_POLICY_REQUIRE:-reason-or-authorisation}"
    fi

    case "$mode" in
        none|off|"") return 0 ;;
        reason)
            [[ -n "$reason" ]] || { echo "queue submit: this security policy requires --reason TEXT" >&2; return 2; }
            QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_TYPE="description-approved"
            QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_DETAIL="$reason"
            ;;
        authorisation|authorization)
            if [[ -z "$auth_code" ]]; then
                auto_code="$(_queue_authorisation_find_valid_for_command "$submit_user" "$@" 2>/dev/null || true)"
                [[ -n "$auto_code" ]] || { echo "queue submit: this security policy requires --authorisation CODE" >&2; return 2; }
                auth_code="$auto_code"
                QUEUEBASH_SUBMIT_AUTO_AUTHORISATION_CODE="$auto_code"
            fi
            _queue_authorisation_validate "$auth_code" "$submit_user" submit "$@" || return $?
            QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_TYPE="code-approved"
            QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_DETAIL="command-bound authorisation $auth_code"
            ;;
        reason-or-authorisation|reason-or-authorization|either)
            if [[ -n "$reason" ]]; then
                QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_TYPE="description-approved"
                QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_DETAIL="$reason"
            else
                if [[ -z "$auth_code" ]]; then
                    auto_code="$(_queue_authorisation_find_valid_for_command "$submit_user" "$@" 2>/dev/null || true)"
                    [[ -n "$auto_code" ]] || { echo "queue submit: this security exception requires --reason TEXT or --authorisation CODE" >&2; return 2; }
                    auth_code="$auto_code"
                    QUEUEBASH_SUBMIT_AUTO_AUTHORISATION_CODE="$auto_code"
                fi
                _queue_authorisation_validate "$auth_code" "$submit_user" submit "$@" || return $?
                QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_TYPE="code-approved"
                QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_DETAIL="command-bound authorisation $auth_code"
            fi
            ;;
        *) echo "queue submit: invalid class policy requirement mode: $mode" >&2; return 2 ;;
    esac
}

_queue_job_policy_execution_check() {
    # Worker-side policy gate.  This is deliberately earlier than class claims,
    # asset preflight, dynamic preflight, global claims and payload launch.
    # If a job is contrary to the active class-policy statement, it must have a
    # standing grant or a valid command-bound authorisation.  A submit-time
    # --reason is audit text only at execution time; it is not permission to run
    # once an admin/site policy is present.
    local jobf="${1:-}"
    [[ -f "$jobf" ]] || { echo "job file not found"; return 1; }
    (
        JOB_CLASS=""; SUBMIT_USER=""; SANDBOX_LEVEL=""; SECCOMP_PROFILE=""; SECURITY_SANDBOX_EXPLICIT="0"; SECURITY_SECCOMP_EXPLICIT="0"
        EXCEPTION_SANDBOX_OVERRIDE=""; EXCEPTION_SECCOMP_ALLOW=""; EXCEPTION_DROP_CAP=""; EXCEPTION_ADD_PORT=""
        SECURITY_AUTHORISATION_CODE=""; SECURITY_EXCEPTION_REASON=""; SECURITY_EXEMPTION_TYPE=""; SECURITY_EXEMPTION_DETAIL=""
        COMMAND=()
        # shellcheck disable=SC1090
        source "$jobf" >/dev/null 2>&1 || { echo "job file could not be sourced for policy check"; exit 1; }
        local policy_file policy_origin
        policy_file="$(_queue_policy_file class-statement "$(_queue_security_policy_statement_name)" 2>/dev/null || true)"
        [[ -n "$policy_file" && -f "$policy_file" ]] || exit 0
        policy_origin="$(_queue_policy_origin "$policy_file" 2>/dev/null || echo unknown)"
        # The terminal execution gate is for shared/admin policy, normally
        # /etc/bashqueues/policies.d/class-statement/default.env.  Bundled policy
        # remains submit-time guidance/default behaviour unless promoted into the
        # shared/admin policy location.
        [[ "$policy_origin" == "shared" || "${QUEUEBASH_POLICY_BLOCK_ENFORCE:-}" == "1" ]] || exit 0
        _queue_security_policy_statement_source >/dev/null 2>&1 || exit 0
        [[ "${#COMMAND[@]}" -gt 0 ]] || { echo "job has no COMMAND array for policy check"; exit 1; }

        local submit_user cmd_hash command_text argv0 allowed_sandbox allowed_seccomp weak_sandbox weak_seccomp block_classes block_hashes block_words block_patterns contrary details auth_out
        local sandbox_level seccomp_profile sandbox_explicit seccomp_explicit
        submit_user="${SUBMIT_USER:-${QUEUEBASH_SELECTED_USER:-}}"
        [[ -n "$submit_user" ]] || submit_user="$(_queue_root_owner_user 2>/dev/null || true)"
        [[ -n "$submit_user" ]] || submit_user="$(id -un 2>/dev/null || echo unknown)"
        cmd_hash="$(_queue_command_hash_from_args "${COMMAND[@]}")"
        command_text="$(_queue_command_shell_words_from_args "${COMMAND[@]}")"
        argv0="${COMMAND[0]:-}"
        sandbox_level="${SANDBOX_LEVEL:-off}"
        seccomp_profile="${SECCOMP_PROFILE:-off}"
        sandbox_explicit="${SECURITY_SANDBOX_EXPLICIT:-0}"
        seccomp_explicit="${SECURITY_SECCOMP_EXPLICIT:-0}"
        allowed_sandbox="${CLASS_POLICY_USER_SANDBOX_POLICIES:-}"
        allowed_seccomp="${CLASS_POLICY_USER_SECCOMP_POLICIES:-}"
        weak_sandbox="${CLASS_POLICY_SANDBOX_REASON_REQUIRED:-off}"
        weak_seccomp="${CLASS_POLICY_SECCOMP_REASON_REQUIRED:-off}"
        block_classes="${CLASS_POLICY_BLOCK_CLASS_NAMES:-}"
        block_hashes="${CLASS_POLICY_BLOCK_COMMAND_HASHES:-}"
        block_words="${CLASS_POLICY_BLOCK_COMMAND_WORDS:-${CLASS_POLICY_BLOCK_COMMAND_NAMES:-}}"
        block_patterns="${CLASS_POLICY_BLOCK_COMMAND_PATTERNS:-}"
        contrary=0
        details=()
        local required_mode="none" req_mode
        _queue_policy_gate_raise_requirement() {
            case "${1:-}" in
                authorisation|authorization) required_mode="authorisation" ;;
                reason)
                    [[ "$required_mode" != "authorisation" ]] && required_mode="reason" ;;
                reason-or-authorisation|reason-or-authorization|either)
                    [[ "$required_mode" == "none" ]] && required_mode="reason-or-authorisation" ;;
            esac
        }

        if [[ -n "$block_classes" && -n "${JOB_CLASS:-}" ]]; then
            if _queue_security_policy_value_in_list "${JOB_CLASS}" "$block_classes"; then
                if ! _queue_class_policy_user_grant_covers "$submit_user" ALLOW_BLOCKED_CLASSES "${JOB_CLASS}" "$cmd_hash"; then
                    contrary=1
                    _queue_policy_gate_raise_requirement "${CLASS_POLICY_BLOCK_CLASS_REQUIRE:-authorisation}"
                    details+=("class '${JOB_CLASS}' is policy-blocked by CLASS_POLICY_BLOCK_CLASS_NAMES")
                else
                    _queue_job_append_security_exemption "$jobf" "policy-approved" "standing policy grant covers blocked class ${JOB_CLASS}" ""
                fi
            fi
        fi
        if [[ -n "$block_hashes" ]] && _queue_policy_hash_value_in_list "$cmd_hash" "$block_hashes"; then
            if ! _queue_class_policy_user_grant_covers "$submit_user" ALLOW_BLOCKED_COMMAND_HASHES "$cmd_hash" "$cmd_hash"; then
                contrary=1
                _queue_policy_gate_raise_requirement "${CLASS_POLICY_BLOCK_COMMAND_REQUIRE:-authorisation}"
                details+=("command hash '${cmd_hash:0:16}' is policy-blocked by CLASS_POLICY_BLOCK_COMMAND_HASHES")
            else
                _queue_job_append_security_exemption "$jobf" "policy-approved" "standing policy grant covers blocked command hash ${cmd_hash:0:16}" ""
            fi
        fi
        if [[ -n "$block_words" ]] && _queue_policy_command_word_in_list "$argv0" "$block_words"; then
            if ! _queue_class_policy_user_grant_covers "$submit_user" ALLOW_BLOCKED_COMMAND_WORDS "$argv0" "$cmd_hash"; then
                contrary=1
                _queue_policy_gate_raise_requirement "${CLASS_POLICY_BLOCK_COMMAND_REQUIRE:-authorisation}"
                details+=("command word '${argv0}' is policy-blocked by CLASS_POLICY_BLOCK_COMMAND_WORDS")
            else
                _queue_job_append_security_exemption "$jobf" "policy-approved" "standing policy grant covers blocked command word $argv0" ""
            fi
        fi
        if [[ -n "$block_patterns" ]] && _queue_policy_command_pattern_matches "$command_text" "$block_patterns"; then
            if ! _queue_class_policy_user_grant_covers "$submit_user" ALLOW_BLOCKED_COMMAND_PATTERNS "$command_text" "$cmd_hash"; then
                contrary=1
                _queue_policy_gate_raise_requirement "${CLASS_POLICY_BLOCK_COMMAND_REQUIRE:-authorisation}"
                details+=("command '$command_text' is policy-blocked by CLASS_POLICY_BLOCK_COMMAND_PATTERNS")
            else
                _queue_job_append_security_exemption "$jobf" "policy-approved" "standing policy grant covers blocked command pattern" ""
            fi
        fi

        if [[ -n "$allowed_sandbox" && -n "$sandbox_level" ]]; then
            if ! _queue_security_policy_value_in_list "$sandbox_level" "$allowed_sandbox"; then
                contrary=1; _queue_policy_gate_raise_requirement "authorisation"; details+=("sandbox policy '$sandbox_level' is outside selectable range '$allowed_sandbox'")
            fi
        fi
        if [[ -n "$allowed_seccomp" && -n "$seccomp_profile" ]]; then
            if ! _queue_security_policy_value_in_list "$seccomp_profile" "$allowed_seccomp"; then
                contrary=1; _queue_policy_gate_raise_requirement "authorisation"; details+=("seccomp policy '$seccomp_profile' is outside selectable range '$allowed_seccomp'")
            fi
        fi
        if [[ -n "${EXCEPTION_SANDBOX_OVERRIDE:-}${EXCEPTION_SECCOMP_ALLOW:-}${EXCEPTION_DROP_CAP:-}${EXCEPTION_ADD_PORT:-}" ]]; then
            if ! _queue_class_policy_user_exception_grants_cover "$submit_user" "${EXCEPTION_SANDBOX_OVERRIDE:-}" "${EXCEPTION_SECCOMP_ALLOW:-}" "${EXCEPTION_DROP_CAP:-}" "${EXCEPTION_ADD_PORT:-}" "$cmd_hash"; then
                contrary=1
                _queue_policy_gate_raise_requirement "${CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE:-reason-or-authorisation}"
                [[ -n "${EXCEPTION_SANDBOX_OVERRIDE:-}" ]] && details+=("sandbox override ${EXCEPTION_SANDBOX_OVERRIDE}")
                [[ -n "${EXCEPTION_SECCOMP_ALLOW:-}" ]] && details+=("seccomp allow ${EXCEPTION_SECCOMP_ALLOW}")
                [[ -n "${EXCEPTION_DROP_CAP:-}" ]] && details+=("drop runtime cap ${EXCEPTION_DROP_CAP}")
                [[ -n "${EXCEPTION_ADD_PORT:-}" ]] && details+=("add runtime port ${EXCEPTION_ADD_PORT}")
            else
                _queue_job_append_security_exemption "$jobf" "policy-approved" "standing policy grant covers requested exception overlay" ""
            fi
        fi
        if [[ "$sandbox_explicit" == "1" && -n "$weak_sandbox" ]] && _queue_security_policy_value_in_list "$sandbox_level" "$weak_sandbox"; then
            if ! _queue_class_policy_user_weak_policy_grant_covers "$submit_user" "$sandbox_level" "$seccomp_profile" "$cmd_hash" "$weak_sandbox" "$weak_seccomp"; then
                contrary=1; _queue_policy_gate_raise_requirement "${CLASS_POLICY_WEAK_POLICY_REQUIRE:-reason-or-authorisation}"; details+=("weak sandbox policy '$sandbox_level'")
            else
                _queue_job_append_security_exemption "$jobf" "policy-approved" "standing policy grant covers weak sandbox policy $sandbox_level" ""
            fi
        fi
        if [[ "$seccomp_explicit" == "1" && -n "$weak_seccomp" ]] && _queue_security_policy_value_in_list "$seccomp_profile" "$weak_seccomp"; then
            if ! _queue_class_policy_user_weak_policy_grant_covers "$submit_user" "$sandbox_level" "$seccomp_profile" "$cmd_hash" "$weak_sandbox" "$weak_seccomp"; then
                contrary=1; _queue_policy_gate_raise_requirement "${CLASS_POLICY_WEAK_POLICY_REQUIRE:-reason-or-authorisation}"; details+=("weak seccomp policy '$seccomp_profile'")
            else
                _queue_job_append_security_exemption "$jobf" "policy-approved" "standing policy grant covers weak seccomp policy $seccomp_profile" ""
            fi
        fi

        [[ "$contrary" -eq 0 ]] && exit 0

        if [[ -n "${SECURITY_AUTHORISATION_CODE:-}" ]]; then
            if auth_out="$(_queue_authorisation_validate "$SECURITY_AUTHORISATION_CODE" "$submit_user" policy "${COMMAND[@]}" 2>&1)"; then
                _queue_job_append_security_exemption "$jobf" "code-approved" "command-bound authorisation $SECURITY_AUTHORISATION_CODE" "$SECURITY_AUTHORISATION_CODE"
                exit 0
            fi
            printf 'policy-contrary job has invalid authorisation %s for user %s: %s\n' "$SECURITY_AUTHORISATION_CODE" "$submit_user" "$auth_out"
        else
            if [[ -n "${SECURITY_EXCEPTION_REASON:-}" && ( "$required_mode" == "reason" || "$required_mode" == "reason-or-authorisation" || "$required_mode" == "none" ) ]]; then
                _queue_job_append_security_exemption "$jobf" "description-approved" "$SECURITY_EXCEPTION_REASON" ""
                exit 0
            fi
            local found_auth
            found_auth="$(_queue_authorisation_find_valid_for_command "$submit_user" "${COMMAND[@]}" 2>/dev/null || true)"
            if [[ -n "$found_auth" ]]; then
                _queue_job_append_security_exemption "$jobf" "code-approved" "on-file command-bound authorisation $found_auth" "$found_auth"
                exit 0
            fi
            printf 'policy-contrary job has no SECURITY_AUTHORISATION_CODE and no on-file command-bound authorisation for user %s\n' "$submit_user"
        fi
        printf 'policy details:'
        local d
        for d in "${details[@]}"; do printf ' %s;' "$d"; done
        printf '\n'
        printf 'resubmit this command with a valid, unexpired, command-bound authorisation; the same authorisation may be reused for resubmissions of this exact command until it expires\n'
        exit 1
    )
}

# Backward-compatible literals kept for static tests/docs: queue policies edit sandbox|seccomp NAME; queue policies create sandbox|seccomp NAME
_queue_policy_valid_kind() {
    case "${1:-}" in sandbox|seccomp|class-statement) return 0 ;; *) return 1 ;; esac
}

_queue_policy_valid_name() {
    [[ "${1:-}" =~ ^[A-Za-z0-9_.@+-]+$ ]]
}

_queue_policy_shared_root() {
    printf '%s\n' "${QUEUEBASH_SHARED_POLICY_ROOT:-/etc/bashqueues/policies.d}"
}

_queue_policy_source_root() {
    local source_dir="${QUEUEBASH_POLICY_SOURCE_DIR:-}" script_dir
    if [[ -z "$source_dir" && -n "${BASH_SOURCE[0]:-}" ]]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P || true)"
        [[ -n "$script_dir" && -d "$script_dir/policies.d" ]] && source_dir="$script_dir/policies.d"
    fi
    [[ -z "$source_dir" && -d "./policies.d" ]] && source_dir="./policies.d"
    printf '%s\n' "$source_dir"
}

_queue_policy_file() {
    local kind="${1:-}" name="${2:-}" root source_root shared_root
    _queue_policy_valid_kind "$kind" || return 1
    _queue_policy_valid_name "$name" || return 1

    # Precedence is intentional:
    #   1. shared/admin policy folder, normally /etc/bashqueues/policies.d
    #   2. queue-root personal policy folder
    #   3. bundled repository policy folder
    # If two policies have the same kind/name, the shared/admin policy wins.
    shared_root="$(_queue_policy_shared_root)"
    if [[ -f "$shared_root/$kind/$name.env" ]]; then
        printf '%s\n' "$shared_root/$kind/$name.env"
        return 0
    fi

    root="$(_queue_root)"
    if [[ -f "$root/policies.d/$kind/$name.env" ]]; then
        printf '%s\n' "$root/policies.d/$kind/$name.env"
        return 0
    fi

    source_root="$(_queue_policy_source_root)"
    if [[ -n "$source_root" && -f "$source_root/$kind/$name.env" ]]; then
        printf '%s\n' "$source_root/$kind/$name.env"
        return 0
    fi

    return 1
}

_queue_policy_exists() {
    _queue_policy_file "${1:-}" "${2:-}" >/dev/null 2>&1
}

_queue_policy_list() {
    local kind="${1:-}" root source_root shared_root f
    _queue_policy_valid_kind "$kind" || return 1
    root="$(_queue_root)"
    source_root="$(_queue_policy_source_root)"
    shared_root="$(_queue_policy_shared_root)"
    {
        shopt -s nullglob
        for f in "$source_root/$kind"/*.env "$root/policies.d/$kind"/*.env "$shared_root/$kind"/*.env; do
            [[ -f "$f" ]] && basename "$f" .env
        done
        shopt -u nullglob
    } | sort -u
}

_queue_policy_origin() {
    local file="${1:-}" root shared_root source_root
    root="$(_queue_root)"
    shared_root="$(_queue_policy_shared_root)"
    source_root="$(_queue_policy_source_root)"
    case "$file" in
        "$shared_root"/*) printf '%s\n' shared ;;
        "$root"/policies.d/*) printf '%s\n' personal ;;
        "$source_root"/*) printf '%s\n' bundled ;;
        *) printf '%s\n' unknown ;;
    esac
}

_queue_policy_edit_target_file() {
    # Prints the file path to edit/create for a policy.
    # Default behaviour is intentionally admin-friendly: root edits the shared
    # site policy under /etc/bashqueues/policies.d, normal users edit their
    # queue-local policy under $QUEUEBASH_ROOT/policies.d.  --shared and
    # --personal are explicit overrides used by tests and automation.
    local scope="${1:-auto}" kind="${2:-}" name="${3:-}" root base
    _queue_policy_valid_kind "$kind" || return 1
    _queue_policy_valid_name "$name" || return 1
    case "$scope" in
        auto|"")
            if [[ "$(id -u 2>/dev/null || echo 1)" == "0" ]]; then
                base="$(_queue_policy_shared_root)"
            else
                root="$(_queue_root)"
                base="$root/policies.d"
            fi
            ;;
        shared|site|admin|etc)
            base="$(_queue_policy_shared_root)"
            ;;
        personal|queue|user)
            root="$(_queue_root)"
            base="$root/policies.d"
            ;;
        *) return 1 ;;
    esac
    printf '%s/%s/%s.env\n' "$base" "$kind" "$name"
}

_queue_policy_emit_template() {
    local kind="${1:-}" name="${2:-}"
    echo "# bashqueues $kind policy: $name"
    echo "QUEUEBASH_POLICY_KIND=$kind"
    echo "QUEUEBASH_POLICY_NAME=$name"
    case "$kind" in
        sandbox)
            echo 'SANDBOX_SYSTEMD_PROPERTIES=()'
            echo 'SANDBOX_DIRECT_PREFIX=()'
            echo 'SANDBOX_DIRECT_WARNING=""'
            ;;
        seccomp)
            echo 'SECCOMP_SYSTEMD_PROPERTIES=()'
            ;;
        class-statement)
            echo 'CLASS_POLICY_USER_SANDBOX_POLICIES="off network-none restrict-egress strict queue-default"'
            echo 'CLASS_POLICY_USER_SECCOMP_POLICIES="off docker-default strict queue-default"'
            echo 'CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE="reason-or-authorisation"'
            echo 'CLASS_POLICY_WEAK_POLICY_REQUIRE="reason-or-authorisation"'
            echo '# Weak policies below are only treated as weak when explicitly requested on submit/class paths.'
            echo 'CLASS_POLICY_SANDBOX_REASON_REQUIRED="off"'
            echo 'CLASS_POLICY_SECCOMP_REASON_REQUIRED="off"'
            echo 'CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="if-trusted-key"'
            ;;
    esac
}

_queue_policy_sha256() {
    local file="${1:-}"
    [[ -f "$file" ]] || return 1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        wc -c < "$file" | awk '{print "size:"$1}'
    fi
}

_queue_policy_explain_effective_class_statement() {
    local name file
    echo "=== effective class-statement policy ==="
    echo "mode: merged"
    echo "loaded files:"
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        file="$(_queue_policy_file class-statement "$name" 2>/dev/null || true)"
        [[ -n "$file" && -f "$file" ]] || continue
        printf '  %-20s %-8s %s\n' "$name" "$(_queue_policy_origin "$file")" "$file"
    done < <(_queue_policy_list class-statement)

    if ! _queue_security_policy_statement_source >/dev/null 2>&1; then
        echo "status: no class-statement policy files found"
        return 1
    fi

    echo
    echo "effective values:"
    printf '  CLASS_POLICY_USER_SANDBOX_POLICIES=%q\n' "${CLASS_POLICY_USER_SANDBOX_POLICIES:-}"
    printf '  CLASS_POLICY_USER_SECCOMP_POLICIES=%q\n' "${CLASS_POLICY_USER_SECCOMP_POLICIES:-}"
    printf '  CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE=%q\n' "${CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE:-}"
    printf '  CLASS_POLICY_WEAK_POLICY_REQUIRE=%q\n' "${CLASS_POLICY_WEAK_POLICY_REQUIRE:-}"
    printf '  CLASS_POLICY_SANDBOX_REASON_REQUIRED=%q\n' "${CLASS_POLICY_SANDBOX_REASON_REQUIRED:-}"
    printf '  CLASS_POLICY_SECCOMP_REASON_REQUIRED=%q\n' "${CLASS_POLICY_SECCOMP_REASON_REQUIRED:-}"
    printf '  CLASS_POLICY_BLOCK_CLASS_NAMES=%q\n' "${CLASS_POLICY_BLOCK_CLASS_NAMES:-}"
    printf '  CLASS_POLICY_BLOCK_CLASS_REQUIRE=%q\n' "${CLASS_POLICY_BLOCK_CLASS_REQUIRE:-}"
    printf '  CLASS_POLICY_BLOCK_COMMAND_HASHES=%q\n' "${CLASS_POLICY_BLOCK_COMMAND_HASHES:-}"
    printf '  CLASS_POLICY_BLOCK_COMMAND_WORDS=%q\n' "${CLASS_POLICY_BLOCK_COMMAND_WORDS:-${CLASS_POLICY_BLOCK_COMMAND_NAMES:-}}"
    printf '  CLASS_POLICY_BLOCK_COMMAND_PATTERNS=%q\n' "${CLASS_POLICY_BLOCK_COMMAND_PATTERNS:-}"
    printf '  CLASS_POLICY_BLOCK_COMMAND_REQUIRE=%q\n' "${CLASS_POLICY_BLOCK_COMMAND_REQUIRE:-}"
    printf '  CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED=%q\n' "${CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED:-}"
}

_queue_policy_quote_array_assignment() {
    local var="$1"; shift || true
    printf '%s=(' "$var"
    local item
    for item in "$@"; do
        printf ' %q' "$item"
    done
    printf ' )\n'
}

_queue_policy_source_file() {
    local kind="${1:-}" name="${2:-}" file
    file="$(_queue_policy_file "$kind" "$name")" || return 1
    # Policy files are data files installed from trusted bashqueues policy dirs.
    # Shared/admin policies intentionally win over personal policies with the
    # same name so operators can define site policy centrally.
    # shellcheck disable=SC1090
    source "$file"
}

_queue_append_policy_snapshot_to_job_file() {
    local job_file="${1:-}" file origin hash sandbox_name seccomp_name
    [[ -f "$job_file" ]] || return 0

    (
        SANDBOX_LEVEL=""
        SECCOMP_PROFILE=""
        EXCEPTION_SANDBOX_OVERRIDE=""
        EXCEPTION_SECCOMP_ALLOW=""
        # shellcheck disable=SC1090
        source "$job_file" >/dev/null 2>&1 || exit 0

        printf 'SECURITY_POLICY_SNAPSHOT_AT=%q\n' "$(date -Is 2>/dev/null || date)"

        sandbox_name="$(_queue_sandbox_normalise_level "${SANDBOX_LEVEL:-off}")"
        if [[ -n "$sandbox_name" ]]; then
            file="$(_queue_policy_file sandbox "$sandbox_name" 2>/dev/null || true)"
            if [[ -n "$file" && -f "$file" ]]; then
                SANDBOX_SYSTEMD_PROPERTIES=()
                SANDBOX_DIRECT_PREFIX=()
                SANDBOX_DIRECT_WARNING=""
                # shellcheck disable=SC1090
                source "$file" >/dev/null 2>&1 || true
                origin="$(_queue_policy_origin "$file")"
                hash="$(_queue_policy_sha256 "$file" 2>/dev/null || true)"
                printf 'SANDBOX_POLICY_NAME=%q\n' "$sandbox_name"
                printf 'SANDBOX_POLICY_FILE=%q\n' "$file"
                printf 'SANDBOX_POLICY_ORIGIN=%q\n' "$origin"
                printf 'SANDBOX_POLICY_SHA256=%q\n' "$hash"
                _queue_policy_quote_array_assignment SANDBOX_POLICY_SYSTEMD_PROPERTIES "${SANDBOX_SYSTEMD_PROPERTIES[@]:-}"
                _queue_policy_quote_array_assignment SANDBOX_POLICY_DIRECT_PREFIX "${SANDBOX_DIRECT_PREFIX[@]:-}"
                printf 'SANDBOX_POLICY_DIRECT_WARNING=%q\n' "${SANDBOX_DIRECT_WARNING:-}"
            fi
        fi

        seccomp_name="$(_queue_seccomp_normalise_profile "${SECCOMP_PROFILE:-off}")"
        if [[ -n "$seccomp_name" ]]; then
            file="$(_queue_policy_file seccomp "$seccomp_name" 2>/dev/null || true)"
            if [[ -n "$file" && -f "$file" ]]; then
                SECCOMP_SYSTEMD_PROPERTIES=()
                # shellcheck disable=SC1090
                source "$file" >/dev/null 2>&1 || true
                origin="$(_queue_policy_origin "$file")"
                hash="$(_queue_policy_sha256 "$file" 2>/dev/null || true)"
                printf 'SECCOMP_POLICY_NAME=%q\n' "$seccomp_name"
                printf 'SECCOMP_POLICY_FILE=%q\n' "$file"
                printf 'SECCOMP_POLICY_ORIGIN=%q\n' "$origin"
                printf 'SECCOMP_POLICY_SHA256=%q\n' "$hash"
                _queue_policy_quote_array_assignment SECCOMP_POLICY_SYSTEMD_PROPERTIES "${SECCOMP_SYSTEMD_PROPERTIES[@]:-}"
            fi
        fi
    ) >> "$job_file"
}
_queue_sandbox_normalise_level() {
    local level="${1:-}"
    case "$level" in
        ""|off|none) echo "" ;;
        *)
            if _queue_policy_valid_name "$level" && _queue_policy_exists sandbox "$level"; then
                echo "$level"
            else
                echo ""
            fi
            ;;
    esac
}

_queue_emit_sandbox_systemd_props() {
    local level prop
    level="$(_queue_sandbox_normalise_level "${1:-}")"
    [[ -n "$level" ]] || return 0

    # Prefer the per-QID policy snapshot written at submit time. This makes the
    # executed policy auditable and immune to later edits of a same-named policy.
    if [[ "${SANDBOX_POLICY_NAME:-}" == "$level" && "${#SANDBOX_POLICY_SYSTEMD_PROPERTIES[@]}" -gt 0 ]]; then
        for prop in "${SANDBOX_POLICY_SYSTEMD_PROPERTIES[@]:-}"; do
            [[ -n "$prop" ]] && printf '%s\0' -p "$prop"
        done
        return 0
    fi

    SANDBOX_SYSTEMD_PROPERTIES=()
    SANDBOX_DIRECT_PREFIX=()
    if ! _queue_policy_source_file sandbox "$level"; then
        return 0
    fi

    for prop in "${SANDBOX_SYSTEMD_PROPERTIES[@]:-}"; do
        [[ -n "$prop" ]] && printf '%s\0' -p "$prop"
    done
}

_queue_emit_sandbox_direct_prefix() {
    local level item
    level="$(_queue_sandbox_normalise_level "${1:-}")"
    [[ -n "$level" ]] || return 0

    if [[ "${SANDBOX_POLICY_NAME:-}" == "$level" ]]; then
        if [[ "${#SANDBOX_POLICY_DIRECT_PREFIX[@]}" -gt 0 ]]; then
            printf '%s\0' "${SANDBOX_POLICY_DIRECT_PREFIX[@]}"
            return 0
        elif [[ -n "${SANDBOX_POLICY_DIRECT_WARNING:-}" ]]; then
            echo "WARNING: $SANDBOX_POLICY_DIRECT_WARNING" >&2
            return 0
        fi
    fi

    SANDBOX_SYSTEMD_PROPERTIES=()
    SANDBOX_DIRECT_PREFIX=()
    SANDBOX_DIRECT_WARNING=""
    if ! _queue_policy_source_file sandbox "$level"; then
        return 0
    fi

    if [[ "${#SANDBOX_DIRECT_PREFIX[@]}" -gt 0 ]]; then
        printf '%s\0' "${SANDBOX_DIRECT_PREFIX[@]}"
    elif [[ -n "${SANDBOX_DIRECT_WARNING:-}" ]]; then
        echo "WARNING: $SANDBOX_DIRECT_WARNING" >&2
    fi
}

_queue_seccomp_normalise_profile() {
    local profile="${1:-}"
    case "$profile" in
        ""|off|none) echo "" ;;
        *)
            if _queue_policy_valid_name "$profile" && _queue_policy_exists seccomp "$profile"; then
                echo "$profile"
            else
                echo ""
            fi
            ;;
    esac
}

_queue_emit_seccomp_systemd_props() {
    local profile allow item prop
    profile="$(_queue_seccomp_normalise_profile "${1:-}")"
    allow="${2:-}"

    if [[ -n "$profile" ]]; then
        if [[ "${SECCOMP_POLICY_NAME:-}" == "$profile" && "${#SECCOMP_POLICY_SYSTEMD_PROPERTIES[@]}" -gt 0 ]]; then
            for prop in "${SECCOMP_POLICY_SYSTEMD_PROPERTIES[@]:-}"; do
                [[ -n "$prop" ]] && printf '%s\0' -p "$prop"
            done
        else
            SECCOMP_SYSTEMD_PROPERTIES=()
            if _queue_policy_source_file seccomp "$profile"; then
                for prop in "${SECCOMP_SYSTEMD_PROPERTIES[@]:-}"; do
                    [[ -n "$prop" ]] && printf '%s\0' -p "$prop"
                done
            fi
        fi
    fi

    # Exception overlays may punch carefully-audited holes such as @debug for strace.
    # Systemd accepts multiple SystemCallFilter= properties; later allow-lists are
    # intentionally emitted as separate properties for auditability in launch_argv.
    for item in $allow; do
        [[ -n "$item" ]] || continue
        printf '%s\0' -p "SystemCallFilter=$item"
    done
}

_queue_runtime_caps_drop_list() {
    local caps="${1:-}" drops="${2:-}" cap drop out="" skip
    caps="$(_queue_runtime_caps_normalise "$caps" 2>/dev/null || true)"
    drops="$(_queue_runtime_caps_normalise "$drops" 2>/dev/null || true)"
    for cap in $caps; do
        skip=0
        for drop in $drops; do
            [[ "$cap" == "$drop" ]] && skip=1
        done
        [[ "$skip" -eq 1 ]] && continue
        out="${out:+$out,}$cap"
    done
    printf '%s\n' "$out"
}

_queue_ports_add_list() {
    local ports="${1:-}" add="${2:-}"
    ports="${ports// /,}"
    add="${add// /,}"
    ports="${ports#,}"; ports="${ports%,}"
    add="${add#,}"; add="${add%,}"
    if [[ -n "$ports" && -n "$add" ]]; then
        printf '%s,%s\n' "$ports" "$add"
    elif [[ -n "$add" ]]; then
        printf '%s\n' "$add"
    else
        printf '%s\n' "$ports"
    fi
}

_queue_apply_security_exception_overlays_for_current_job() {
    # Merge class defaults with job-level exception overlays.  This happens in
    # the worker, after the job record is sourced and before launch_argv is built.
    # Exceptions are intentionally visible in queue explain and job history; they
    # are escape hatches, not invisible policy edits.
    local effective_sandbox effective_caps effective_ports effective_seccomp_allow

    effective_sandbox="${SANDBOX_LEVEL:-off}"
    if [[ -n "${EXCEPTION_SANDBOX_OVERRIDE:-}" ]]; then
        effective_sandbox="$(_queue_sandbox_normalise_level "$EXCEPTION_SANDBOX_OVERRIDE")"
        [[ -z "$effective_sandbox" ]] && effective_sandbox="off"
    fi

    effective_caps="${RUNTIME_CAPS:-}"
    if [[ -n "${EXCEPTION_DROP_CAP:-}" ]]; then
        effective_caps="$(_queue_runtime_caps_drop_list "$effective_caps" "$EXCEPTION_DROP_CAP")"
    fi

    effective_ports="${RUNTIME_CAP_PORTS:-}"
    if [[ -n "${EXCEPTION_ADD_PORT:-}" ]]; then
        effective_ports="$(_queue_ports_add_list "$effective_ports" "$EXCEPTION_ADD_PORT")"
    fi

    effective_seccomp_allow="${SECCOMP_ALLOW:-}"
    if [[ -n "${EXCEPTION_SECCOMP_ALLOW:-}" ]]; then
        effective_seccomp_allow="${effective_seccomp_allow:+$effective_seccomp_allow }${EXCEPTION_SECCOMP_ALLOW}"
    fi

    SANDBOX_LEVEL="$effective_sandbox"
    RUNTIME_CAPS="$effective_caps"
    RUNTIME_CAP_PORTS="$effective_ports"
    SECCOMP_ALLOW="$effective_seccomp_allow"
    export SANDBOX_LEVEL RUNTIME_CAPS RUNTIME_CAP_PORTS SECCOMP_PROFILE SECCOMP_ALLOW
}

_queue_runtime_caps_normalise() {
    # Operators naturally use both runtime:no_spawn_shell and
    # no-spawn-shell spelling.  Runtime caps are matched internally in
    # kebab-case so underscore spelling does not silently disable a cap.
    local caps="${1:-${RUNTIME_CAPS:-}}"
    caps="${caps//_/ -}"
    caps="${caps//-/ -}"
    # The two substitutions above intentionally route all words through the
    # whitespace normaliser below; collapse commas/semicolons/pipes too.
    caps="${1:-${RUNTIME_CAPS:-}}"
    caps="${caps//_/-}"
    caps="${caps//,/ }"
    caps="${caps//;/ }"
    caps="${caps//|/ }"
    printf '%s\n' "$caps" | awk '{for (i=1;i<=NF;i++) if ($i != "") print $i}' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

_queue_runtime_caps_is_known() {
    case "$1" in
        no-spawn-shell|no-network-tools|no-network-sockets|only-local-sockets|only-port) return 0 ;;
        '') return 0 ;;
        *) return 1 ;;
    esac
}

_queue_runtime_caps_unknown_list() {
    local cap unknown=""
    for cap in $(_queue_runtime_caps_normalise "${1:-${RUNTIME_CAPS:-}}" 2>/dev/null); do
        if ! _queue_runtime_caps_is_known "$cap"; then
            unknown+="${unknown:+,}$cap"
        fi
    done
    printf '%s\n' "$unknown"
}

_queue_runtime_caps_has() {
    local want="$1" cap
    for cap in $(_queue_runtime_caps_normalise "${RUNTIME_CAPS:-}" 2>/dev/null); do
        [[ "$cap" == "$want" ]] && return 0
    done
    return 1
}

_queue_runtime_caps_pids() {
    local root_pid="${1:-}" pgid="${2:-}" p pid seen=" "
    [[ -n "$root_pid" ]] && printf '%s\n' "$root_pid"
    if [[ -n "$pgid" ]]; then
        pgrep -g "$pgid" 2>/dev/null || true
    fi
    if [[ -n "$root_pid" ]]; then
        local frontier=("$root_pid") next=()
        while [[ "${#frontier[@]}" -gt 0 ]]; do
            next=()
            for p in "${frontier[@]}"; do
                while IFS= read -r pid; do
                    [[ -n "$pid" ]] || continue
                    [[ "$seen" == *" $pid "* ]] && continue
                    seen+="$pid "
                    printf '%s\n' "$pid"
                    next+=("$pid")
                done < <(pgrep -P "$p" 2>/dev/null || true)
            done
            frontier=("${next[@]}")
        done
    fi | awk 'NF && !seen[$1]++'
}

_queue_runtime_caps_cmdline() {
    local pid="$1"
    tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | sed 's/[[:space:]]\+$//'
}

_queue_runtime_caps_exe_base() {
    local pid="$1" exe=""
    exe="$(readlink "/proc/$pid/exe" 2>/dev/null || true)"
    basename "$exe" 2>/dev/null || true
}

_queue_runtime_caps_lsof_sockets() {
    local pid="$1"
    command -v lsof >/dev/null 2>&1 || return 1
    lsof -nP -a -p "$pid" -i 2>/dev/null | awk 'NR>1 {print; found=1} END {exit found?0:1}'
}

_queue_runtime_caps_lsof_local_only_violation() {
    # Reads lsof -i output on stdin.  Returns success and prints the first
    # violating line when an INET socket is not localhost-only.  LISTEN on
    # *:PORT or 0.0.0.0:PORT is deliberately a violation.
    local line name
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        name="${line##* }"
        case "$line" in
            *' 127.0.0.1:'*|*' localhost:'*|*' [::1]:'*|*' ::1:'*)
                continue
                ;;
            *)
                printf '%s\n' "$line"
                return 0
                ;;
        esac
    done
    return 1
}

_queue_runtime_caps_port_allowed() {
    local port="$1" spec="${RUNTIME_CAP_PORTS:-}" item lo hi
    [[ "$port" =~ ^[0-9]+$ ]] || return 1
    spec="${spec// /,}"
    spec="${spec//;/,}"
    spec="${spec//:/,}"
    spec="${spec//|/,}"
    IFS=',' read -r -a _queue_runtime_port_items <<< "$spec"
    for item in "${_queue_runtime_port_items[@]}"; do
        [[ -n "$item" ]] || continue
        if [[ "$item" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            lo="${BASH_REMATCH[1]}"; hi="${BASH_REMATCH[2]}"
            [[ "$port" -ge "$lo" && "$port" -le "$hi" ]] && return 0
        elif [[ "$item" =~ ^[0-9]+$ ]]; then
            [[ "$port" -eq "$item" ]] && return 0
        fi
    done
    return 1
}

_queue_runtime_caps_socket_policy_port() {
    # For TCP client connections, evaluate the remote port after ->.
    # For LISTEN/UDP sockets, evaluate the bound/local port.  This avoids
    # blocking normal localhost clients because their ephemeral local port is
    # not in the allow-list.
    local line="$1" name side port
    name="${line##* }"
    side="$name"
    if [[ "$side" == *'->'* ]]; then
        side="${side##*->}"
    fi
    side="${side%% *}"
    port="${side##*:}"
    port="${port%%-*}"
    port="${port%%/*}"
    [[ "$port" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$port"
}

_queue_runtime_caps_lsof_port_violation() {
    local line port
    [[ -n "${RUNTIME_CAP_PORTS:-}" ]] || { printf '%s\n' 'RUNTIME_CAP_PORTS not set'; return 0; }
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        port="$(_queue_runtime_caps_socket_policy_port "$line" 2>/dev/null || true)"
        [[ -n "$port" ]] || { printf '%s\n' "$line"; return 0; }
        if ! _queue_runtime_caps_port_allowed "$port"; then
            printf '%s\n' "$line"
            return 0
        fi
    done
    return 1
}

_queue_runtime_caps_watchdog() {
    local job_file="$1" log_file="$2" root_pid="$3" pgid="$4" interval="${RUNTIME_CAP_INTERVAL:-1}"
    local pid base cmd sockets reason now
    [[ "$interval" =~ ^[0-9]+$ && "$interval" -gt 0 ]] || interval=1
    [[ -n "${RUNTIME_CAPS:-}" ]] || return 0

    local unknown_caps normalised_caps
    normalised_caps="$(_queue_runtime_caps_normalise "${RUNTIME_CAPS:-}" 2>/dev/null || true)"
    unknown_caps="$(_queue_runtime_caps_unknown_list "${RUNTIME_CAPS:-}" 2>/dev/null || true)"
    if [[ -n "$unknown_caps" ]]; then
        now="$(date -Is 2>/dev/null || date)"
        {
            printf 'RUNTIME_CAP_WARNING=%q\n' "unknown runtime cap(s): $unknown_caps"
            printf 'RUNTIME_CAPS_NORMALISED=%q\n' "$normalised_caps"
        } >> "$job_file"
        {
            echo
            echo "RUNTIME_CAP_WARNING: unknown runtime cap(s): $unknown_caps"
            echo "RUNTIME_CAPS_NORMALISED: ${normalised_caps:-none}"
        } >> "$log_file"
        _queue_log_event "runtime_cap_warning" "${JOB_ID:-$(basename "$job_file" .job)}" "${JOB_NAME:-}" "running" "unknown=$unknown_caps normalised=${normalised_caps:-none}"
    fi

    while kill -0 "$root_pid" 2>/dev/null; do
        while IFS= read -r pid; do
            [[ -n "$pid" && -d "/proc/$pid" ]] || continue
            base="$(_queue_runtime_caps_exe_base "$pid")"
            cmd="$(_queue_runtime_caps_cmdline "$pid")"
            reason=""

            if [[ "$pid" != "$root_pid" ]] && _queue_runtime_caps_has no-spawn-shell; then
                case "$base" in
                    sh|bash|dash|zsh|ksh|mksh|busybox) reason="no-spawn-shell exe=$base cmd=$cmd" ;;
                esac
            fi

            if [[ -z "$reason" ]] && _queue_runtime_caps_has no-network-tools; then
                case "$base" in
                    curl|wget|nc|ncat|netcat|socat|telnet|ssh|scp|sftp|rsync) reason="no-network-tools exe=$base cmd=$cmd" ;;
                esac
            fi

            if [[ -z "$reason" ]] && _queue_runtime_caps_has no-network-sockets; then
                sockets="$(_queue_runtime_caps_lsof_sockets "$pid" 2>/dev/null || true)"
                [[ -n "$sockets" ]] && reason="no-network-sockets pid=$pid exe=$base"
            fi

            if [[ -z "$reason" ]] && _queue_runtime_caps_has only-local-sockets; then
                sockets="$(_queue_runtime_caps_lsof_sockets "$pid" 2>/dev/null || true)"
                if [[ -n "$sockets" ]]; then
                    violation="$(_queue_runtime_caps_lsof_local_only_violation <<< "$sockets" 2>/dev/null || true)"
                    [[ -n "$violation" ]] && reason="only-local-sockets pid=$pid exe=$base socket=$violation"
                fi
            fi

            if [[ -z "$reason" ]] && _queue_runtime_caps_has only-port; then
                sockets="$(_queue_runtime_caps_lsof_sockets "$pid" 2>/dev/null || true)"
                if [[ -n "$sockets" ]]; then
                    violation="$(_queue_runtime_caps_lsof_port_violation <<< "$sockets" 2>/dev/null || true)"
                    [[ -n "$violation" ]] && reason="only-port ports=${RUNTIME_CAP_PORTS:-unset} pid=$pid exe=$base socket=$violation"
                fi
            fi

            if [[ -n "$reason" ]]; then
                now="$(date -Is 2>/dev/null || date)"
                {
                    printf 'RUNTIME_CAP_VIOLATED=%q\n' "1"
                    printf 'RUNTIME_CAP_VIOLATED_AT=%q\n' "$now"
                    printf 'RUNTIME_CAP_VIOLATION=%q\n' "$reason"
                    printf 'RUNTIME_CAP_VIOLATION_PID=%q\n' "$pid"
                } >> "$job_file"
                {
                    echo
                    echo "RUNTIME_CAP_VIOLATION: $reason"
                    [[ -n "${sockets:-}" ]] && { echo "lsof:"; echo "$sockets"; }
                } >> "$log_file"
                _queue_log_event "runtime_cap_violation" "${JOB_ID:-$(basename "$job_file" .job)}" "${JOB_NAME:-}" "running" "$reason"
                if [[ -n "$pgid" && "$pgid" =~ ^[0-9]+$ ]]; then
                    kill -TERM -- "-$pgid" 2>/dev/null || true
                    sleep 1
                    kill -KILL -- "-$pgid" 2>/dev/null || true
                else
                    kill -TERM "$root_pid" 2>/dev/null || true
                    sleep 1
                    kill -KILL "$root_pid" 2>/dev/null || true
                fi
                return 0
            fi
        done < <(_queue_runtime_caps_pids "$root_pid" "$pgid")
        sleep "$interval"
    done
}



_queue_absolutize_systemd_argv0() {
    # systemd-run accepts either a simple executable name found via PATH, or
    # an absolute executable path.  It rejects relative paths containing a
    # slash, such as ./script.sh, even when --working-directory is supplied.
    # Normalise only argv[0]; arguments remain unchanged.
    local cwd="${1:-}"
    shift || true
    local cmd0="${1:-}"
    [[ -n "$cmd0" ]] || return 0
    shift || true

    if [[ "$cmd0" == */* && "$cmd0" != /* ]]; then
        if [[ -n "$cwd" ]]; then
            printf '%s\0' "$cwd/$cmd0"
        else
            printf '%s\0' "$PWD/$cmd0"
        fi
    else
        printf '%s\0' "$cmd0"
    fi

    printf '%s\0' "$@"
}

_queue_emit_systemd_payload_argv() {
    # Emit the command section after systemd-run's "--" marker.
    # If timeout is present, timeout is argv[0] and the payload command is an
    # argument to timeout, so the relative-path executable restriction does not
    # apply directly to the payload.  Without timeout, normalise argv[0].
    local cwd="${1:-}"
    local timeout_value="${2:-}"
    local kill_after="${3:-}"
    shift 3 || true

    if [[ -n "$timeout_value" ]]; then
        _queue_emit_timeout_wrapper_argv "$timeout_value" "$kill_after"
        printf '%s\0' "$@"
    else
        _queue_absolutize_systemd_argv0 "$cwd" "$@"
    fi
}

_queue_build_payload_command() {
    # Prints NUL-separated argv for the actual process to spawn.
    # We prefer systemd-run for CPU/MEM limits. If no limits are requested,
    # use setsid when available so cancel can signal the process group safely.
    local cpu="${1:-}"
    local mem="${2:-}"
    local cwd="${3:-}"
    local runner="${4:-auto}"
    local timeout_value="${5:-}"
    local kill_after="${6:-}"
    local sandbox_level="${7:-}"
    local run_user="${8:-}"
    shift 8

    if [[ "$runner" == "systemd" ]]; then
        if [[ -n "$run_user" && "$run_user" != "$(_queue_current_user_name)" && "$(id -u 2>/dev/null || echo 99999)" == "0" ]]; then
            printf '%s\0' systemd-run --pipe --wait --collect --uid="$run_user"
        elif _queue_systemd_user_service_supported; then
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
            _queue_emit_sandbox_systemd_props "$sandbox_level"
            _queue_emit_seccomp_systemd_props "${SECCOMP_PROFILE:-}" "${SECCOMP_ALLOW:-}"
            [[ -n "$cpu" ]] && printf '%s\0' -p "CPUQuota=$(_queue_normalize_systemd_cpu_quota "$cpu")"
            [[ -n "$mem" ]] && printf '%s\0' -p "MemoryMax=${mem}"
            printf '%s\0' --
            _queue_emit_systemd_payload_argv "$cwd" "$timeout_value" "$kill_after" "$@"
            return 0
        fi
    fi

    _queue_emit_user_switch_prefix "$run_user"
    _queue_emit_sandbox_direct_prefix "$sandbox_level"
    if command -v setsid >/dev/null 2>&1; then
        printf '%s\0' setsid --
    fi
    _queue_emit_timeout_wrapper_argv "$timeout_value" "$kill_after"
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
    printf '  %q' systemd-run --user --pipe --wait --collect -p "CPUQuota=$(_queue_normalize_systemd_cpu_quota "$cpu")" -p "MemoryMax=${mem}" -- /bin/sh -c 'echo queuebash-systemd-probe-ok; pwd; exit 0'
    echo
    echo

    systemd-run --user --pipe --wait --collect \
        --working-directory="$PWD" \
        -p "CPUQuota=$(_queue_normalize_systemd_cpu_quota "$cpu")" \
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

    _queue_print_selected_user_banner

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


_queue_root_running_foreign_payload_user() {
    local run_user="${1:-${RUN_USER:-}}"
    [[ -n "$run_user" ]] || return 1
    [[ "$(id -u 2>/dev/null || echo 99999)" == "0" ]] || return 1
    [[ "$run_user" != "$(_queue_current_user_name 2>/dev/null || id -un 2>/dev/null || echo root)" ]] || return 1
    return 0
}

_queue_runner_for_job() {
    local requested="${1:-auto}"
    local cpu="${2:-}"
    local mem="${3:-}"
    local run_user="${4:-${RUN_USER:-}}"

    requested="${requested:-${QUEUEBASH_RUNNER:-auto}}"

    case "$requested" in
        direct) echo "direct"; return 0 ;;
        systemd)
            if _queue_root_running_foreign_payload_user "$run_user"; then
                echo "systemd-foreign-user-not-used"
                return 1
            fi
            if _queue_systemd_user_service_supported; then
                echo "systemd"
                return 0
            fi
            echo "systemd-unavailable"
            return 1
            ;;
        auto|"")
            # Prefer direct when root is launching a payload as another Unix user.
            # This avoids root trying to enter or depend on another user's
            # systemd --user bus.  Direct+runuser is the predictable fallback
            # for root/operator cross-user execution.
            if _queue_root_running_foreign_payload_user "$run_user"; then
                echo "direct"
                return 0
            fi

            # Otherwise prefer systemd only when the current user's systemd bus
            # is actually usable. su/runuser shells frequently have no usable
            # user bus; auto must fall back to direct rather than selecting a
            # doomed systemd-run --user launch.
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

_queue_log_tail_text() {
    local path="$1"
    local lines="${2:-120}"

    # Use text-safe output for command substitution callers.  Some compressed
    # logs can contain NUL bytes from payload output; bash warns when NULs
    # appear in command substitution, which pollutes queue explain.
    _queue_log_tail "$path" "$lines" | tr -d '\000'
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


_queue_dep_token_status() {
    local dep="$1"
    local root="$(_queue_root)"
    local state f name

    for state in done failed pol_block policy_blocked cancelled interrupted running pending paused deleted; do
        if [[ -f "$root/$state/$dep.job" ]]; then
            printf '%s\n' "$state"
            return 0
        fi

        shopt -s nullglob
        for f in "$root/$state"/*.job; do
            [[ -f "$f" ]] || continue
            name="$(_queue_job_name "$f" 2>/dev/null || true)"
            if [[ "$name" == "$dep" ]]; then
                printf '%s\n' "$state"
                shopt -u nullglob
                return 0
            fi
        done
        shopt -u nullglob
    done

    printf '%s\n' "missing"
}

_queue_file_depends_after_success() {
    local f="$1"
    (
        DEPENDS_AFTER_SUCCESS=""
        source "$f" >/dev/null 2>&1 || exit 0
        printf '%s\n' "${DEPENDS_AFTER_SUCCESS:-}"
    )
}

_queue_file_not_before_epoch() {
    local f="$1"
    (
        NOT_BEFORE_EPOCH=0
        RETRY_NOT_BEFORE_EPOCH=0
        source "$f" >/dev/null 2>&1 || exit 0
        if [[ "${RETRY_NOT_BEFORE_EPOCH:-0}" =~ ^[0-9]+$ && "${RETRY_NOT_BEFORE_EPOCH:-0}" -gt 0 ]]; then
            printf '%s\n' "$RETRY_NOT_BEFORE_EPOCH"
        else
            printf '%s\n' "${NOT_BEFORE_EPOCH:-0}"
        fi
    )
}

_queue_class_for_job_file() {
    local f="$1"
    (
        JOB_CLASS=""
        CLASS=""
        source "$f" >/dev/null 2>&1 || exit 0
        printf '%s\n' "${JOB_CLASS:-${CLASS:-DEFAULT}}"
    )
}

_queue_job_pending_dispatch_diagnose() {
    local f="$1"
    local root="$(_queue_root)"
    local id name class now not_before deps dep dep_state blocked=0
    local class_file tmp out rc

    id="$(basename "$f" .job)"
    name="$(_queue_job_name "$f" 2>/dev/null || true)"
    class="$(_queue_class_for_job_file "$f")"

    echo
    echo "Dispatch decision"

    if [[ "$(basename "$(dirname "$f")")" != "pending" ]]; then
        echo "  status:            not pending"
        echo "  reason:            dispatch diagnosis only applies to pending jobs"
        return 0
    fi

    now="$(date +%s)"
    not_before="$(_queue_file_not_before_epoch "$f")"
    if [[ "$not_before" =~ ^[0-9]+$ && "$not_before" -gt "$now" ]]; then
        echo "  status:            blocked"
        echo "  reason:            scheduled for the future"
        echo "  not_before_epoch:  $not_before"
        if command -v date >/dev/null 2>&1; then
            echo "  not_before_time:   $(date -d "@$not_before" -Is 2>/dev/null || true)"
        fi
        blocked=1
    fi

    deps="$(_queue_file_depends_after_success "$f")"
    if [[ -n "$deps" ]]; then
        echo "  dependencies:"
        for dep in $deps; do
            dep_state="$(_queue_dep_token_status "$dep")"
            case "$dep_state" in
                done)
                    echo "    $dep: satisfied (done)"
                    ;;
                failed|cancelled|interrupted|deleted)
                    echo "    $dep: blocked ($dep_state)"
                    blocked=1
                    ;;
                missing)
                    echo "    $dep: waiting (missing)"
                    blocked=1
                    ;;
                *)
                    echo "    $dep: waiting ($dep_state)"
                    blocked=1
                    ;;
            esac
        done
    else
        echo "  dependencies:      none"
    fi

    echo "  class:             ${class:-DEFAULT}"
    class_file="$(_queue_class_file "${class:-DEFAULT}")"
    if [[ -f "$class_file" ]]; then
        echo "  class file:        $class_file"
    else
        echo "  status:            blocked"
        echo "  reason:            class file missing"
        echo "  class file:        $class_file"
        blocked=1
    fi

    tmp="$(mktemp)"
    if _queue_class_available "$f" >"$tmp" 2>&1; then
        rc=0
    else
        rc="$?"
    fi
    out="$(cat "$tmp")"
    rm -f "$tmp"

    if [[ "$rc" -eq 0 ]]; then
        if [[ "$blocked" -eq 0 ]]; then
            echo "  status:            runnable"
            echo "  reason:            no dispatch blocker detected"
            echo
            echo "Claim/lock snapshot"
            _queue_claims_summary_for_explain
        else
            echo "  class/resource:    available"
        fi
    else
        echo "  status:            blocked"
        echo "  reason:            class/resource gate rejected job"
        echo "  class/resource rc: $rc"
        if [[ -n "$out" ]]; then
            echo "  class/resource output:"
            printf '%s\n' "$out" | sed 's/^/    /'
        fi
    fi
}


_queue_job_file_by_id_any_state() {
    local id="$1"
    local root="$(_queue_root)"
    local st f

    for st in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
        f="$root/$st/$id.job"
        [[ -f "$f" ]] && { printf '%s\n' "$f"; return 0; }
    done
    return 1
}

_queue_job_state_for_file() {
    local f="$1"
    local root="$(_queue_root)"
    local rel

    rel="${f#"$root"/}"
    printf '%s\n' "${rel%%/*}"
}

_queue_job_history_chain_ids() {
    local start="$1"
    local id="$start"
    local f prev seen=" "

    while [[ -n "$id" && "$seen" != *" $id "* ]]; do
        printf '%s\n' "$id"
        seen+="$id "
        f="$(_queue_job_file_by_id_any_state "$id" 2>/dev/null || true)"
        [[ -n "$f" ]] || break
        prev="$(
            RESUBMITTED_FROM=""
            source "$f" >/dev/null 2>&1 || exit 0
            printf '%s\n' "${RESUBMITTED_FROM:-}"
        )"
        id="$prev"
    done | tac
}

_queue_job_history_children_ids() {
    local start="$1"
    local root="$(_queue_root)"
    local st f child

    for st in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
        shopt -s nullglob
        for f in "$root/$st"/*.job; do
            child="$(
                RESUBMITTED_FROM=""
                source "$f" >/dev/null 2>&1 || exit 0
                [[ "${RESUBMITTED_FROM:-}" == "$start" ]] && printf '%s\n' "${JOB_ID:-$(basename "$f" .job)}"
            )"
            [[ -n "$child" ]] && printf '%s\n' "$child"
        done
        shopt -u nullglob
    done | sort -u
}

_queue_job_history_events_for_id() {
    local id="$1"
    local events="$(_queue_root)/events.jsonl"

    [[ -f "$events" ]] || return 0

    grep -F "\"job_id\":\"$id\"" "$events" 2>/dev/null | tail -20 | sed -E '
        s/.*"ts":"([^"]*)".*"event":"([^"]*)".*"state":"([^"]*)".*"detail":"([^"]*)".*/    \1  \2  state=\3  \4/
        t
        s/^/    /
    '
}

_queue_job_history_print_one() {
    local id="$1"
    local f state

    f="$(_queue_job_file_by_id_any_state "$id" 2>/dev/null || true)"
    if [[ -z "$f" ]]; then
        printf '%-36s  %-11s  %s\n' "$id" "missing" "job record not found"
        return 0
    fi

    state="$(_queue_job_state_for_file "$f")"

    (
        JOB_ID="$id"
        JOB_NAME=""
        COMMAND=()
        SUBMITTED_AT=""
        RUN_STARTED_AT=""
        EXEC_FINISHED_AT=""
        EXIT_CODE=""
        DURATION_SECONDS=""
        RESUBMITTED_FROM=""
        RESUBMITTED_AT=""
        RESUBMIT_NOTE=""
        JOB_CLASS=""
        TIMEOUT=""
        KILL_AFTER=""
        CLASS_DEFAULTS_SOURCE=""
        LOG_PATH=""
        source "$f" >/dev/null 2>&1 || exit 0

        local cmd=""
        if declare -p COMMAND >/dev/null 2>&1; then
            printf -v cmd '%q ' "${COMMAND[@]}"
            cmd="${cmd% }"
        fi

        printf '%-36s  %-11s  exit=%-5s  name=%s\n' \
            "${JOB_ID:-$id}" "$state" "${EXIT_CODE:--}" "${JOB_NAME:-}"
        [[ -n "${SUBMITTED_AT:-}" ]] && echo "    submitted:        $SUBMITTED_AT"
        [[ -n "${RUN_STARTED_AT:-}" ]] && echo "    started:          $RUN_STARTED_AT"
        [[ -n "${EXEC_FINISHED_AT:-}" ]] && echo "    finished:         $EXEC_FINISHED_AT"
        [[ -n "${DURATION_SECONDS:-}" ]] && echo "    duration:         ${DURATION_SECONDS}s"
        [[ -n "${JOB_CLASS:-}" ]] && echo "    class:            $JOB_CLASS"
        [[ -n "${TIMEOUT:-}" ]] && echo "    timeout:          $TIMEOUT${KILL_AFTER:+ kill_after=$KILL_AFTER}"
        [[ -n "${CLASS_DEFAULTS_SOURCE:-}" ]] && echo "    class defaults:   $CLASS_DEFAULTS_SOURCE"
        [[ -n "${RESUBMITTED_FROM:-}" ]] && echo "    resubmitted from: $RESUBMITTED_FROM"
        [[ -n "${RESUBMITTED_AT:-}" ]] && echo "    resubmitted at:   $RESUBMITTED_AT"
        [[ -n "${RESUBMIT_NOTE:-}" ]] && echo "    note:             $RESUBMIT_NOTE"
        [[ -n "$cmd" ]] && echo "    command:          $cmd"

        local log_path=""
        if [[ -n "${LOG_PATH:-}" ]]; then
            log_path="$LOG_PATH"
        else
            log_path="$(_queue_log_path "${JOB_ID:-$id}" 2>/dev/null || true)"
        fi
        [[ -n "$log_path" ]] && echo "    log:              $log_path"

        echo "    events:"
        _queue_job_history_events_for_id "${JOB_ID:-$id}" | sed 's/^/  /'
    )
}

_queue_job_history() {
    local selector="${1:-}"
    local id="" f root st
    local -a ids
    local child

    if [[ -z "$selector" ]]; then
        echo "Usage: queue history <job-id|name>" >&2
        return 2
    fi

    if f="$(_queue_job_file_by_id_any_state "$selector" 2>/dev/null)"; then
        id="$(basename "$f" .job)"
    else
        root="$(_queue_root)"
        for st in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
            shopt -s nullglob
            for f in "$root/$st"/*.job; do
                if ( source "$f" >/dev/null 2>&1 && [[ "${JOB_NAME:-}" == "$selector" ]] ); then
                    id="$(basename "$f" .job)"
                fi
            done
            shopt -u nullglob
        done
    fi

    [[ -n "$id" ]] || {
        echo "queue history: job not found: $selector" >&2
        return 1
    }

    echo "=============================================================================="
    echo "QUEUEBASH HISTORY: $id"
    echo "=============================================================================="

    mapfile -t ids < <(_queue_job_history_chain_ids "$id")
    for child in $(_queue_job_history_children_ids "$id"); do
        ids+=("$child")
    done

    local seen=" "
    for id in "${ids[@]}"; do
        [[ -n "$id" ]] || continue
        [[ "$seen" == *" $id "* ]] && continue
        seen+="$id "
        _queue_job_history_print_one "$id"
        echo
    done
}

_queue_job_history_brief_for_explain() {
    local id="$1"
    local events="$(_queue_root)/events.jsonl"
    local f child

    echo "History"
    if [[ -f "$events" ]]; then
        grep -F "\"job_id\":\"$id\"" "$events" 2>/dev/null | tail -6 | sed -E '
            s/.*"ts":"([^"]*)".*"event":"([^"]*)".*"state":"([^"]*)".*"detail":"([^"]*)".*/  \1  \2  state=\3  \4/
            t
            s/^/  /
        '
    fi

    for child in $(_queue_job_history_children_ids "$id"); do
        echo "  resubmitted to: $child"
    done

    f="$(_queue_job_file_by_id_any_state "$id" 2>/dev/null || true)"
    if [[ -n "$f" ]]; then
        (
            RESUBMITTED_FROM=""
            source "$f" >/dev/null 2>&1 || exit 0
            [[ -n "${RESUBMITTED_FROM:-}" ]] && echo "  resubmitted from: $RESUBMITTED_FROM"
        )
    fi

    echo "  full history: queue history $id"
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
    run_user="$(_queue_job_var_value "$f" RUN_USER)"
    runner_planned="$(_queue_runner_for_job "$runner" "$cpu" "$mem" "$run_user" 2>/dev/null || echo unknown)"
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

    echo
    echo "Class defaults applied"
    (
        CLASS_DEFAULTS_APPLIED_AT=""
        CLASS_DEFAULTS_SOURCE=""
        TIMEOUT=""
        KILL_AFTER=""
        LOG_TAG=""
        OUTPUT_DIR=""
        ENV_PREFIX=""
        source "$f" >/dev/null 2>&1 || exit 0
        echo "  source:            ${CLASS_DEFAULTS_SOURCE:-none}"
        [[ -n "${CLASS_DEFAULTS_APPLIED_AT:-}" ]] && echo "  applied at:        $CLASS_DEFAULTS_APPLIED_AT"
        [[ -n "${TIMEOUT:-}" ]] && echo "  timeout:           $TIMEOUT"
        [[ -n "${KILL_AFTER:-}" ]] && echo "  kill after:        $KILL_AFTER"
        [[ -n "${LOG_TAG:-}" ]] && echo "  log tag:           $LOG_TAG"
        [[ -n "${OUTPUT_DIR:-}" ]] && echo "  output dir:        $OUTPUT_DIR"
        [[ -n "${ENV_PREFIX:-}" ]] && echo "  env prefix:        $ENV_PREFIX"
        [[ -n "${PWD_AT_SUBMIT:-}" ]] && echo "  working dir:       $PWD_AT_SUBMIT"
        [[ -n "${SECURITY_POLICY_SNAPSHOT_AT:-}" ]] && echo "  policy snapshot:   $SECURITY_POLICY_SNAPSHOT_AT"
        if [[ -n "${SANDBOX_POLICY_NAME:-}" ]]; then
            echo "  sandbox policy:    ${SANDBOX_POLICY_NAME} (${SANDBOX_POLICY_ORIGIN:-unknown})"
            [[ -n "${SANDBOX_POLICY_SHA256:-}" ]] && echo "  sandbox sha256:    $SANDBOX_POLICY_SHA256"
        fi
        if [[ -n "${SECCOMP_POLICY_NAME:-}" ]]; then
            echo "  seccomp policy:    ${SECCOMP_POLICY_NAME} (${SECCOMP_POLICY_ORIGIN:-unknown})"
            [[ -n "${SECCOMP_POLICY_SHA256:-}" ]] && echo "  seccomp sha256:    $SECCOMP_POLICY_SHA256"
        fi
    )
    echo

    echo
    (
        source "$f" >/dev/null 2>&1 || exit 0
        _queue_caps_explain_current_job
    )
    echo

    if [[ -n "${NET_USAGE_INTERFACE:-}" || -n "${NET_USAGE_USED_BYTES:-}" || -n "${NET_USAGE_ALLOWANCE_BYTES:-}" ]]; then
        echo
        echo "Network usage"
        [[ -n "${NET_USAGE_INTERFACE:-}" ]] && echo "  interface:         $NET_USAGE_INTERFACE"
        [[ -n "${NET_USAGE_DIRECTION:-}" ]] && echo "  direction:         $NET_USAGE_DIRECTION"
        [[ -n "${NET_USAGE_COUNTER_FILE:-}" ]] && echo "  counter file:      $NET_USAGE_COUNTER_FILE"
        [[ -n "${NET_USAGE_ALLOWANCE_BYTES:-}" ]] && echo "  class allowance:   $NET_USAGE_ALLOWANCE_BYTES"
        [[ -n "${NET_USAGE_LIMIT_BYTES:-}" ]] && echo "  job limit:         $NET_USAGE_LIMIT_BYTES"
        [[ -n "${NET_USAGE_START_BYTES:-}" ]] && echo "  start bytes:       $NET_USAGE_START_BYTES"
        [[ -n "${NET_USAGE_END_BYTES:-}" ]] && echo "  end bytes:         $NET_USAGE_END_BYTES"
        [[ -n "${NET_USAGE_USED_BYTES:-}" ]] && echo "  used bytes:        $NET_USAGE_USED_BYTES"
        [[ -n "${NET_USAGE_EXCEEDED:-}" ]] && echo "  exceeded:          $NET_USAGE_EXCEEDED"
        [[ -n "${NET_USAGE_POLICY:-}" ]] && echo "  policy:            $NET_USAGE_POLICY"
    fi

    _queue_global_explain_for_job "$f" "$id"
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

    _queue_exception_explain_for_job "$id"
    _queue_security_exception_guidance_for_job "$id" "$f" "$log"

    echo "Dependencies"
    _queue_job_dependencies_status "$f" | sed 's/^/  /'

    echo

    if [[ "$state" == "pending" ]]; then
        _queue_job_pending_dispatch_diagnose "$f"
    fi

    echo
    _queue_job_history_brief_for_explain "$id"
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
    for state in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
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
    for state in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
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
    for state in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
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
                    done|failed|pol_block|policy_blocked|interrupted|cancelled|deleted|orphan) ;;
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
    printf '%s\n' pending running paused done failed pol_block policy_blocked interrupted cancelled deleted logs workers outputs streams
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

    for state in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
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

    for state in pending running paused done failed pol_block policy_blocked interrupted cancelled; do
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


_queue_cron_spool_dir() { printf '%s\n' "${QUEUEBASH_CRON_SPOOL_DIR:-/var/spool/bashqueues_cron}"; }
_queue_cron_system_dir() { printf '%s\n' "${QUEUEBASH_CRON_SYSTEM_DIR:-/etc/bashqueues_cron.d}"; }
_queue_cron_state_dir() { printf '%s\n' "${QUEUEBASH_CRON_STATE_DIR:-/var/lib/bashqueues/cron}"; }
_queue_cron_ticker_path() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"
    for p in \
        "${QUEUEBASH_CRON_TICKER:-}" \
        "$here/bin/bashqueues-cron-ticker.py" \
        "$here/bashqueues-cron-ticker.py" \
        "/usr/local/libexec/bashqueues/bashqueues-cron-ticker.py" \
        "/usr/local/bin/bashqueues-cron-ticker.py"; do
        [[ -n "$p" && -x "$p" ]] && { printf '%s\n' "$p"; return 0; }
    done
    command -v bashqueues-cron-ticker.py 2>/dev/null || true
}
_queue_cron_line_description() {
    local min="$1" hour="$2" dom="$3" mon="$4" dow="$5"
    local out=""
    case "$min" in
        "*") out="every minute" ;;
        \*/[0-9]*) out="every ${min#*/} minutes" ;;
        [0-9]*) out="at minute $min" ;;
        *) out="minutes '$min'" ;;
    esac
    case "$hour" in
        "*") ;;
        \*/[0-9]*) out="$out, every ${hour#*/} hours" ;;
        [0-9]*) out="$out past hour $hour" ;;
        *) out="$out, hours '$hour'" ;;
    esac
    [[ "$dom" != "*" ]] && out="$out, day-of-month '$dom'"
    [[ "$mon" != "*" ]] && out="$out, month '$mon'"
    [[ "$dow" != "*" ]] && out="$out, weekday '$dow'"
    printf '%s\n' "$out"
}

_queue_cron_entry_hash() {
    local user="$1" command="$2"
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s\0%s' "$user" "$command" | sha256sum | awk '{print $1}'
    else
        printf '%s\0%s' "$user" "$command" | shasum -a 256 | awk '{print $1}'
    fi
}

_queue_cron_stable_class() {
    local user="$1" command="$2" h
    h="$(_queue_cron_entry_hash "$user" "$command")"
    printf 'cron_%s\n' "${h:0:12}"
}

_queue_cron_next_hint() {
    local spec="$1"
    local ticker="$(_queue_cron_ticker_path)"
    if [[ -n "$ticker" && -x "$ticker" ]]; then
        # The ticker is the source of truth for cron matching.  It does not yet
        # expose next-run calculation, so keep this as a cheap human hint rather
        # than inventing a second scheduler here.
        :
    fi
    printf 'next run: calculated by bashqueues-cron.timer/tick at minute boundaries\n'
}


_queue_cron_trim() {
    local s="$1"
    s="${s#${s%%[![:space:]]*}}"
    s="${s%${s##*[![:space:]]}}"
    printf '%s\n' "$s"
}

_queue_cron_comment_directive_value() {
    local raw="$1" key="$2" body
    body="$(_queue_cron_trim "$raw")"
    [[ "$body" == \#* ]] || return 1
    body="${body#\#}"
    body="$(_queue_cron_trim "$body")"
    case "$body" in
        ${key}[[:space:]]*) printf '%s\n' "$(_queue_cron_trim "${body#${key}}")"; return 0 ;;
        bashqueues-${key}[[:space:]]*) printf '%s\n' "$(_queue_cron_trim "${body#bashqueues-${key}}")"; return 0 ;;
        bashqueues_${key}[[:space:]]*) printf '%s\n' "$(_queue_cron_trim "${body#bashqueues_${key}}")"; return 0 ;;
    esac
    return 1
}

_queue_cron_is_assignment_line() {
    local line="$(_queue_cron_trim "$1")"
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]
}

_queue_cron_is_entry_line() {
    local raw="$1" line macro rest a b c d e cmd
    line="${raw%%#*}"
    line="$(_queue_cron_trim "$line")"
    [[ -z "$line" ]] && return 1
    [[ "$line" == \#* ]] && return 1
    _queue_cron_is_assignment_line "$line" && return 1
    if [[ "$line" == @* ]]; then
        macro="${line%%[[:space:]]*}"
        [[ "$macro" == "@reboot" ]] && return 0
        rest="${line#${macro}}"; rest="$(_queue_cron_trim "$rest")"
        [[ -n "$rest" ]]
        return $?
    fi
    read -r a b c d e cmd <<< "$line"
    [[ -n "${a:-}" && -n "${b:-}" && -n "${c:-}" && -n "${d:-}" && -n "${e:-}" && -n "${cmd:-}" ]]
}

_queue_cron_class_for_entry() {
    local file="$1" wanted="$2" n=0 raw val active=""
    [[ -f "$file" ]] || return 1
    while IFS= read -r raw || [[ -n "$raw" ]]; do
        if val="$(_queue_cron_comment_directive_value "$raw" class 2>/dev/null)"; then
            active="$val"
            continue
        fi
        if _queue_cron_is_entry_line "$raw"; then
            n=$((n+1))
            if [[ "$n" -eq "$wanted" ]]; then
                printf '%s\n' "$active"
                return 0
            fi
        fi
    done < "$file"
    return 1
}

_queue_cron_set_class_file() {
    local file="$1" entry_no="$2" class_name="$3" tmp n=0 i raw prev j clear=0 target_i=-1 directive_i=-1
    [[ "$entry_no" =~ ^[0-9]+$ && "$entry_no" -gt 0 ]] || { echo "queue cron class: entry number must be a positive integer" >&2; return 2; }
    [[ -f "$file" ]] || { echo "queue cron class: no bashqueues crontab: $file" >&2; return 1; }
    if [[ "$class_name" == "--clear" || "$class_name" == "clear" || "$class_name" == "none" || "$class_name" == "default" ]]; then
        clear=1
    elif [[ ! "$class_name" =~ ^[A-Za-z0-9_.:-]+$ ]]; then
        echo "queue cron class: invalid class name: $class_name" >&2
        return 2
    fi
    mapfile -t _cron_lines < "$file"
    for i in "${!_cron_lines[@]}"; do
        raw="${_cron_lines[$i]}"
        if _queue_cron_is_entry_line "$raw"; then
            n=$((n+1))
            if [[ "$n" -eq "$entry_no" ]]; then
                target_i="$i"
                break
            fi
        fi
    done
    if [[ "$target_i" -lt 0 ]]; then
        echo "queue cron class: entry $entry_no not found in $file" >&2
        return 1
    fi
    j=$((target_i-1))
    while [[ "$j" -ge 0 ]]; do
        prev="${_cron_lines[$j]}"
        [[ -z "$(_queue_cron_trim "$prev")" ]] && { j=$((j-1)); continue; }
        if _queue_cron_comment_directive_value "$prev" class >/dev/null 2>&1; then
            directive_i="$j"
        fi
        break
    done
    tmp="$(mktemp)" || return 1
    for i in "${!_cron_lines[@]}"; do
        if [[ "$i" -eq "$target_i" && "$directive_i" -lt 0 && "$clear" -ne 1 ]]; then
            printf '#class %s\n' "$class_name" >> "$tmp"
        fi
        if [[ "$i" -eq "$directive_i" ]]; then
            if [[ "$clear" -ne 1 ]]; then
                printf '#class %s\n' "$class_name" >> "$tmp"
            fi
            continue
        fi
        printf '%s\n' "${_cron_lines[$i]}" >> "$tmp"
    done
    if ! cp "$tmp" "$file" 2>/dev/null; then
        rm -f "$tmp"
        echo "queue cron class: cannot write bashqueues crontab: $file" >&2
        return 1
    fi
    chmod 0600 "$file" 2>/dev/null || true
    rm -f "$tmp"
    if [[ "$clear" -eq 1 ]]; then
        echo "Cleared bashqueues class directive for cron entry $entry_no: $file"
    else
        echo "Set bashqueues class for cron entry $entry_no to $class_name: $file"
    fi
}

_queue_cron_set_class_command() {
    local current_user target_user entry_no class_name d f
    current_user="$(id -un 2>/dev/null || echo unknown)"
    target_user="${QUEUEBASH_SELECTED_USER:-$current_user}"
    if [[ "${1:-}" == "--user" ]]; then
        target_user="${2:-}"; shift 2 || true
    elif [[ "${1:-}" != "" && ! "${1:-}" =~ ^[0-9]+$ ]]; then
        target_user="$1"; shift || true
    fi
    entry_no="${1:-}"; class_name="${2:-}"
    if [[ -z "$entry_no" || -z "$class_name" ]]; then
        echo "Usage: queue cron class [USER] ENTRY CLASS|--clear" >&2
        return 2
    fi
    if [[ "$current_user" != "root" && "$target_user" != "$current_user" ]]; then
        echo "queue cron class: only root may edit another user's bashqueues crontab" >&2
        return 1
    fi
    if [[ ! "$target_user" =~ ^[A-Za-z0-9_.-]+$ ]]; then
        echo "queue cron class: invalid user name: $target_user" >&2
        return 2
    fi
    d="$(_queue_cron_spool_dir)"; f="$d/$target_user"
    _queue_cron_set_class_file "$f" "$entry_no" "$class_name"
}

_queue_cron_explain_file() {
    local owner="$1" file="$2" line raw min hour dom mon dow cmd class h desc n=0 active_class="" active_auth="" val generated_class
    [[ -f "$file" ]] || { echo "No bashqueues crontab for $owner: $file" >&2; return 1; }
    if [[ ! -r "$file" ]]; then
        echo "=== cron for $owner ==="
        echo "file: $file"
        echo "status: not readable by $(id -un 2>/dev/null || echo unknown)"
        echo
        return 0
    fi
    echo "=== cron for $owner ==="
    echo "file: $file"
    while IFS= read -r raw || [[ -n "$raw" ]]; do
        if val="$(_queue_cron_comment_directive_value "$raw" class 2>/dev/null)"; then
            active_class="$val"
            continue
        fi
        if val="$(_queue_cron_comment_directive_value "$raw" authorisation 2>/dev/null)" || val="$(_queue_cron_comment_directive_value "$raw" authorization 2>/dev/null)"; then
            active_auth="$val"
            continue
        fi
        line="${raw%%#*}"
        line="${line#${line%%[![:space:]]*}}"
        line="${line%${line##*[![:space:]]}}"
        [[ -z "$line" ]] && continue
        _queue_cron_is_assignment_line "$line" && continue
        if [[ "$line" == @* ]]; then
            local macro rest
            macro="${line%%[[:space:]]*}"
            rest="${line#${macro}}"; rest="${rest#${rest%%[![:space:]]*}}"
            case "$macro" in
                @hourly) min="0"; hour="*"; dom="*"; mon="*"; dow="*"; cmd="$rest" ;;
                @daily|@midnight) min="0"; hour="0"; dom="*"; mon="*"; dow="*"; cmd="$rest" ;;
                @weekly) min="0"; hour="0"; dom="*"; mon="*"; dow="0"; cmd="$rest" ;;
                @monthly) min="0"; hour="0"; dom="1"; mon="*"; dow="*"; cmd="$rest" ;;
                @yearly|@annually) min="0"; hour="0"; dom="1"; mon="1"; dow="*"; cmd="$rest" ;;
                @reboot)
                    n=$((n+1))
                    echo
                    echo "entry $n: $raw"
                    echo "  status: unsupported macro @reboot"
                    echo "  reason: bashqueues cron is queue/timer based; @reboot has no queue-safe equivalent"
                    continue
                    ;;
                *)
                    n=$((n+1))
                    echo
                    echo "entry $n: $raw"
                    echo "  status: unsupported macro $macro"
                    continue
                    ;;
            esac
        else
            read -r min hour dom mon dow cmd <<< "$line"
            if [[ -z "${min:-}" || -z "${hour:-}" || -z "${dom:-}" || -z "${mon:-}" || -z "${dow:-}" || -z "${cmd:-}" ]]; then
                n=$((n+1))
                echo
                echo "entry $n: $raw"
                echo "  status: invalid; expected five cron fields plus command"
                continue
            fi
        fi
        n=$((n+1))
        generated_class="$(_queue_cron_stable_class "$owner" "$cmd")"
        class="${active_class:-$generated_class}"
        h="$(_queue_cron_entry_hash "$owner" "$cmd")"
        desc="$(_queue_cron_line_description "$min" "$hour" "$dom" "$mon" "$dow")"
        echo
        echo "entry $n: $raw"
        echo "  schedule: $min $hour $dom $mon $dow"
        echo "  meaning:  $desc"
        echo "  user:     $owner"
        echo "  command:  $cmd"
        if [[ -n "$active_auth" ]]; then
            echo "  submits:  queue user $owner submit $generated_class --class $class --authorisation $active_auth -- bash -lc $(printf '%q' "$cmd")"
        else
            echo "  submits:  queue user $owner submit $generated_class --class $class -- bash -lc $(printf '%q' "$cmd")"
        fi
        if [[ -n "$active_class" ]]; then
            echo "  class:    $class (explicit #class; generated name would be $generated_class)"
        else
            echo "  class:    $class (generated)"
        fi
        [[ -n "$active_auth" ]] && echo "  auth:     $active_auth (explicit #authorisation)"
        echo "  hash:     ${h:0:16}"
        echo "  state:    one queue job per matching minute; duplicate ticks are suppressed by state markers"
    done < "$file"
    [[ "$n" -gt 0 ]] || echo "No active cron entries."
    echo
}


_queue_cron_systemd_unit_state() {
    local unit="$1"
    if ! command -v systemctl >/dev/null 2>&1; then
        printf 'systemctl unavailable\n'
        return 0
    fi
    local active enabled
    active="$(systemctl is-active "$unit" 2>/dev/null || true)"
    enabled="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
    [[ -n "$active" ]] || active="unknown"
    [[ -n "$enabled" ]] || enabled="unknown"
    printf '%s / %s\n' "$active" "$enabled"
}

_queue_cron_count_active_entries_file() {
    local f="$1" raw n=0
    [[ -r "$f" ]] || { printf '0\n'; return 0; }
    while IFS= read -r raw || [[ -n "$raw" ]]; do
        if _queue_cron_is_entry_line "$raw"; then
            n=$((n+1))
        fi
    done < "$f"
    printf '%s\n' "$n"
}

_queue_cron_latest_marker() {
    local d="$(_queue_cron_state_dir)" latest=""
    [[ -d "$d" ]] || { printf 'none\n'; return 0; }
    latest="$(find "$d" -maxdepth 1 -type f -name '*.json' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)"
    [[ -n "$latest" ]] || { printf 'none\n'; return 0; }
    if command -v stat >/dev/null 2>&1; then
        printf '%s (%s)\n' "$(basename "$latest")" "$(stat -c '%y' "$latest" 2>/dev/null | cut -d'.' -f1)"
    else
        printf '%s\n' "$(basename "$latest")"
    fi
}

_queue_cron_status() {
    local d="$(_queue_cron_spool_dir)" d2="$(_queue_cron_system_dir)" state="$(_queue_cron_state_dir)" ticker f files=0 entries=0 n
    ticker="$(_queue_cron_ticker_path)"
    echo "=== bashqueues cron status ==="
    echo "ticker:        ${ticker:-not found}"
    echo "user spool:    $d"
    if [[ -d "$d" ]]; then
        echo "spool mode:    $(stat -c '%a %U:%G' "$d" 2>/dev/null || echo unknown)"
        for f in "$d"/*; do
            [[ -f "$f" ]] || continue
            files=$((files+1))
            n="$(_queue_cron_count_active_entries_file "$f")"
            entries=$((entries+n))
        done
    else
        echo "spool mode:    missing"
    fi
    echo "user files:    $files"
    echo "user entries:  $entries"

    files=0; entries=0
    echo "system dir:    $d2"
    if [[ -d "$d2" ]]; then
        for f in "$d2"/*; do
            [[ -f "$f" ]] || continue
            files=$((files+1))
            n="$(_queue_cron_count_active_entries_file "$f")"
            entries=$((entries+n))
        done
    fi
    echo "system files:  $files"
    echo "system entries: $entries"
    echo "state dir:     $state"
    echo "last marker:   $(_queue_cron_latest_marker)"
    echo "cron timer:    $(_queue_cron_systemd_unit_state bashqueues-cron.timer)"
    echo "cron service:  $(_queue_cron_systemd_unit_state bashqueues-cron.service)"
    echo "daemon service: $(_queue_cron_systemd_unit_state bashqueues-daemon.service)"
}

_queue_cron_test() {
    local ticker
    _queue_cron_status
    ticker="$(_queue_cron_ticker_path)"
    [[ -n "$ticker" ]] || { echo; echo "preview: ticker not found"; return 127; }
    echo
    echo "=== dry-run tick preview ==="
    "$ticker" --dryrun "$@"
}

_queue_cron_command() {
    local action="${1:-list}"
    case "$action" in
        root|roots)
            echo "spool:  $(_queue_cron_spool_dir)"
            echo "system: $(_queue_cron_system_dir)"
            echo "state:  $(_queue_cron_state_dir)"
            ;;
        list|ls|"")
            shift || true
            local d="$(_queue_cron_spool_dir)" d2="$(_queue_cron_system_dir)" f any=0 list_all=0 selected="${QUEUEBASH_SELECTED_USER:-}"
            [[ "${1:-}" == "--all" ]] && list_all=1
            echo "=== user bashqueues crontabs ==="
            if [[ -d "$d" ]]; then
                if [[ -n "$selected" && "$list_all" -ne 1 ]]; then
                    f="$d/$selected"
                    if [[ -f "$f" ]]; then
                        any=1
                        echo "$selected  $f"
                        grep -v '^[[:space:]]*#' "$f" 2>/dev/null | grep -v '^[[:space:]]*$' | sed 's/^/  /' || true
                    fi
                else
                    for f in "$d"/*; do
                        [[ -f "$f" ]] || continue
                        any=1
                        echo "$(basename "$f")  $f"
                        grep -v '^[[:space:]]*#' "$f" 2>/dev/null | grep -v '^[[:space:]]*$' | sed 's/^/  /' || true
                    done
                fi
            fi
            [[ "$any" -eq 1 ]] || echo "No user bashqueues crontabs."
            any=0
            echo
            echo "=== system bashqueues cron.d ==="
            if [[ -d "$d2" ]]; then
                for f in "$d2"/*; do
                    [[ -f "$f" ]] || continue
                    any=1
                    echo "$(basename "$f")  $f"
                    grep -v '^[[:space:]]*#' "$f" 2>/dev/null | grep -v '^[[:space:]]*$' | sed 's/^/  /' || true
                done
            fi
            [[ "$any" -eq 1 ]] || echo "No system bashqueues cron.d files."
            ;;
        status|stat)
            shift || true
            _queue_cron_status "$@"
            ;;
        test|doctor|check)
            shift || true
            _queue_cron_test "$@"
            ;;
        explain|why)
            shift || true
            local d="$(_queue_cron_spool_dir)" d2="$(_queue_cron_system_dir)" target="${1:-}" selected="${QUEUEBASH_SELECTED_USER:-}" current_user
            current_user="$(id -un 2>/dev/null || echo unknown)"
            if [[ -z "$target" ]]; then
                target="${selected:-$current_user}"
            fi
            if [[ "$target" == "--all" ]]; then
                local f any=0
                if [[ -d "$d" ]]; then
                    for f in "$d"/*; do
                        [[ -f "$f" ]] || continue
                        any=1
                        _queue_cron_explain_file "$(basename "$f")" "$f"
                    done
                fi
                if [[ -d "$d2" ]]; then
                    for f in "$d2"/*; do
                        [[ -f "$f" ]] || continue
                        any=1
                        _queue_cron_explain_file "system:$(basename "$f")" "$f"
                    done
                fi
                [[ "$any" -eq 1 ]] || echo "No bashqueues cron files."
            elif [[ "$target" == "system" ]]; then
                local f any=0
                if [[ -d "$d2" ]]; then
                    for f in "$d2"/*; do
                        [[ -f "$f" ]] || continue
                        any=1
                        _queue_cron_explain_file "system:$(basename "$f")" "$f"
                    done
                fi
                [[ "$any" -eq 1 ]] || echo "No system bashqueues cron.d files."
            else
                _queue_cron_explain_file "$target" "$d/$target"
            fi
            ;;
        show|cat)
            shift
            local target_user="${1:-$(id -un 2>/dev/null || echo unknown)}" f
            f="$(_queue_cron_spool_dir)/$target_user"
            [[ -f "$f" ]] || { echo "No bashqueues crontab for $target_user" >&2; return 1; }
            cat "$f"
            ;;
        preview)
            shift
            local ticker
            ticker="$(_queue_cron_ticker_path)"
            [[ -n "$ticker" ]] || { echo "queue cron preview: bashqueues-cron-ticker.py not found" >&2; return 127; }
            "$ticker" --dryrun "$@"
            ;;
        tick)
            shift
            local ticker
            ticker="$(_queue_cron_ticker_path)"
            [[ -n "$ticker" ]] || { echo "queue cron tick: bashqueues-cron-ticker.py not found" >&2; return 127; }
            "$ticker" "$@"
            ;;
        class|set-class)
            shift
            _queue_cron_set_class_command "$@"
            ;;
        edit)
            shift
            local current_user target_user d f tmp
            current_user="$(id -un 2>/dev/null || echo unknown)"
            target_user="${1:-$current_user}"
            if [[ "$current_user" != "root" && "$target_user" != "$current_user" ]]; then
                echo "queue cron edit: only root may edit another user's bashqueues crontab" >&2
                return 1
            fi
            if [[ ! "$target_user" =~ ^[A-Za-z0-9_.-]+$ ]]; then
                echo "queue cron edit: invalid user name: $target_user" >&2
                return 2
            fi
            d="$(_queue_cron_spool_dir)"
            if ! mkdir -p "$d" 2>/dev/null; then
                echo "queue cron edit: cannot create cron spool directory: $d" >&2
                echo "hint: run sudo ./install-system.sh --with-cron, or set QUEUEBASH_CRON_SPOOL_DIR to a writable spool" >&2
                return 1
            fi
            f="$d/$target_user"; tmp="$(mktemp)" || return 1
            [[ -f "$f" ]] && cp "$f" "$tmp" 2>/dev/null || true
            "${VISUAL:-${EDITOR:-vi}}" "$tmp"
            if ! cp "$tmp" "$f" 2>/dev/null; then
                rm -f "$tmp"
                echo "queue cron edit: cannot write bashqueues crontab: $f" >&2
                echo "hint: install/fix cron spool permissions with: sudo ./install-system.sh --with-cron" >&2
                echo "hint: expected user spool directory mode is 1777: $d" >&2
                return 1
            fi
            chmod 0600 "$f" 2>/dev/null || true
            rm -f "$tmp"
            echo "Updated bashqueues crontab: $f"
            ;;
        remove|rm|delete)
            shift
            local target_user="${1:-$(id -un 2>/dev/null || echo unknown)}" f
            f="$(_queue_cron_spool_dir)/$target_user"
            rm -f "$f"
            echo "Removed bashqueues crontab: $target_user"
            ;;
        *)
            echo "Usage: queue cron root|status|test|list [--all]|explain [user|--all|system]|class [USER] ENTRY CLASS|--clear|show [user]|preview [--now ISO]|tick [--dryrun]|edit [user]|remove [user]" >&2
            return 2
            ;;
    esac
}

_queue_help() {
    cat <<'EOF'
Usage:
  queue [--dryrun] <command...>
  queue submit <name> [--dryrun] [--priority N|-p N] [--on-success <cmd...>] [--on-retry-failure <cmd...>] [--on-failure <cmd...>] -- <command...>

  queue list [--state all|pending|running|paused|done|failed|pol_block|policy_blocked|interrupted|cancelled|deleted] [--name TEXT] [--filter TEXT]
  queue ls   [--state all|pending|running|paused|done|failed|pol_block|policy_blocked|interrupted|cancelled|deleted] [--name TEXT] [--filter TEXT]
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

  queue draft list
  queue draft show <draft-id>
  queue draft create <name> [options] [--after-success QID] [--on-success <cmd...>] -- <command...>
  queue draft create-from-job <qid>
  queue draft submit <draft-id>
  queue draft ready|abandon <draft-id>

  queue run [--workers N] [--detach] [--dryrun]
  queue sentinel [--once] [--interval SEC] [--detach]
  queue system-daemon [--once] [--interval SEC] [--detach] [--min-workers N]
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
  queue sentinel runs a cheap control-plane loop: policy gate, stale-worker cleanup, stale-running repair, and deadline escalation only.
  queue system-daemon is the root multi-user control loop; it delegates per-user queue daemons and never runs user jobs as root.
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
  queue reevaluate [--all|QID] [--dryrun]
  queue backup [create] [FILE.tar.gz] [--force]
  queue backup restore FILE.tar.gz --to DIRECTORY [--force]
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
    sentinel control-plane loop with: queue sentinel --detach --interval 30

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
    for state in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
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


# -------------------------------------------------------------------
# Module enable/disable helpers
# -------------------------------------------------------------------

_queue_module_valid_kind() {
    case "${1:-}" in class|classes|asset|assets|cap|caps) return 0 ;; *) return 1 ;; esac
}

_queue_module_normal_kind() {
    case "${1:-}" in
        class|classes) echo class ;;
        asset|assets) echo asset ;;
        cap|caps) echo cap ;;
        *) return 1 ;;
    esac
}

_queue_module_paths() {
    local kind="$1" name="$2" root="$(_queue_root)" active disabled
    case "$kind" in
        class) active="$root/classes/$name.env"; disabled="$root/classes/.disabled/$name.env" ;;
        asset) active="$root/assets.d/$name.sh"; disabled="$root/assets.d/.disabled/$name.sh" ;;
        cap) active="$root/caps.d/$name.sh"; disabled="$root/caps.d/.disabled/$name.sh" ;;
        *) return 1 ;;
    esac
    printf '%s	%s
' "$active" "$disabled"
}

_queue_module_status() {
    local kind="$1" name="$2" paths active disabled
    paths="$(_queue_module_paths "$kind" "$name")" || return 1
    active="${paths%%$'\t'*}"; disabled="${paths#*$'\t'}"
    if [[ -e "$active" ]]; then echo enabled; return 0; fi
    if [[ -e "$disabled" ]]; then echo disabled; return 0; fi
    echo missing; return 1
}

_queue_module_disable() {
    local kind="$(_queue_module_normal_kind "${1:-}")" name="${2:-}" force="${3:-}" paths active disabled ddir used
    [[ -n "$kind" && -n "$name" ]] || { echo "Usage: queue modules disable class|asset|cap NAME [--force]" >&2; return 2; }
    paths="$(_queue_module_paths "$kind" "$name")" || return 2
    active="${paths%%$'\t'*}"; disabled="${paths#*$'\t'}"; ddir="$(dirname "$disabled")"
    [[ -f "$active" ]] || { [[ -f "$disabled" ]] && { echo "$kind module already disabled: $name"; return 0; }; echo "queue modules disable: not found: $kind $name" >&2; return 1; }
    if [[ "$kind" == "asset" && "$force" != "--force" ]]; then
        used="$(_queue_asset_family_is_used_by_classes "$name" || true)"
        if [[ -n "$used" ]]; then
            echo "queue modules disable: refusing to disable asset used by classes; use --force to override" >&2
            echo "$used" >&2
            return 3
        fi
    fi
    mkdir -p "$ddir"
    mv "$active" "$disabled" || return 1
    echo "Disabled $kind module: $name"
    echo "Moved to: $disabled"
    _queue_log_event "module_disabled" "$name" "$name" "${kind}s" "path=$active disabled=$disabled" 2>/dev/null || true
}

_queue_module_enable() {
    local kind="$(_queue_module_normal_kind "${1:-}")" name="${2:-}" paths active disabled
    [[ -n "$kind" && -n "$name" ]] || { echo "Usage: queue modules enable class|asset|cap NAME" >&2; return 2; }
    paths="$(_queue_module_paths "$kind" "$name")" || return 2
    active="${paths%%$'\t'*}"; disabled="${paths#*$'\t'}"
    [[ ! -f "$active" ]] || { echo "$kind module already enabled: $name"; return 0; }
    [[ -f "$disabled" ]] || { echo "queue modules enable: disabled module not found: $kind $name" >&2; return 1; }
    case "$kind" in
        class) _queue_class_validate_file "$name" "$disabled" || return $? ;;
        asset) _queue_asset_replace_validate_source "$name" "$disabled" || return $? ;;
        cap) bash -n "$disabled" || return 3 ;;
    esac
    mv "$disabled" "$active" || return 1
    chmod +x "$active" 2>/dev/null || true
    echo "Enabled $kind module: $name"
    echo "Restored to: $active"
    _queue_log_event "module_enabled" "$name" "$name" "${kind}s" "path=$active" 2>/dev/null || true
}

_queue_modules_list() {
    local root="$(_queue_root)" f name
    _queue_prune_obsolete_asset_plugins >/dev/null 2>&1 || true
    mkdir -p "$root/classes/.disabled" "$root/assets.d/.disabled" "$root/caps.d/.disabled"
    for f in "$root/classes"/*.env; do [[ -f "$f" ]] && printf 'class\t%s\tenabled\t%s\n' "$(basename "$f" .env)" "$f"; done
    for f in "$root/classes/.disabled"/*.env; do [[ -f "$f" ]] && printf 'class\t%s\tdisabled\t%s\n' "$(basename "$f" .env)" "$f"; done
    for f in "$root/assets.d"/*.sh; do [[ -f "$f" ]] && printf 'asset\t%s\tenabled\t%s\n' "$(basename "$f" .sh)" "$f"; done
    for f in "$root/assets.d/.disabled"/*.sh; do [[ -f "$f" ]] && printf 'asset\t%s\tdisabled\t%s\n' "$(basename "$f" .sh)" "$f"; done
    for f in "$root/caps.d"/*.sh; do [[ -f "$f" ]] && printf 'cap\t%s\tenabled\t%s\n' "$(basename "$f" .sh)" "$f"; done
    for f in "$root/caps.d/.disabled"/*.sh; do [[ -f "$f" ]] && printf 'cap\t%s\tdisabled\t%s\n' "$(basename "$f" .sh)" "$f"; done
    return 0
}

_queue_modules_explain() {
    local spec="${1:-}" kind name paths active disabled status
    [[ "$spec" == *:* ]] || { echo "Usage: queue modules explain class:NAME|asset:NAME|cap:NAME" >&2; return 2; }
    kind="$(_queue_module_normal_kind "${spec%%:*}")" || { echo "queue modules explain: invalid kind: ${spec%%:*}" >&2; return 2; }
    name="${spec#*:}"
    paths="$(_queue_module_paths "$kind" "$name")" || return 2
    active="${paths%%$'\t'*}"; disabled="${paths#*$'\t'}"; status="$(_queue_module_status "$kind" "$name" 2>/dev/null || echo missing)"
    echo "MODULE EXPLAIN: $kind:$name"
    echo "kind:      $kind"
    echo "name:      $name"
    echo "status:    $status"
    echo "active:    $active"
    echo "disabled:  $disabled"
    echo
    case "$kind" in
        class) [[ -f "$active" ]] && _queue_class_explain "$name" || { [[ -f "$disabled" ]] && sed 's/^/  /' "$disabled" || true; } ;;
        asset) [[ -f "$active" ]] && _queue_asset_explain "$name" || { [[ -f "$disabled" ]] && sed 's/^/  /' "$disabled" || true; } ;;
        cap)
            local src=""
            if [[ -f "$active" ]]; then
                src="$active"
            elif [[ -f "$disabled" ]]; then
                src="$disabled"
            fi
            if [[ -n "$src" ]]; then
                echo "Contents:"
                sed 's/^/  /' "$src" || true
            fi
            ;;
    esac
}


_queue_pol_block_reevaluate() {
    local target="" local_dryrun=0 root f id state reason moved=0 checked=0
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --all) target=""; shift ;;
            --dryrun|-n) local_dryrun=1; shift ;;
            *) target="$1"; shift ;;
        esac
    done
    root="$(_queue_root)"
    local files=()
    if [[ -n "$target" ]]; then
        while IFS= read -r f; do
            state="$(basename "$(dirname "$f")")"
            [[ "$state" == "pol_block" || "$state" == "policy_blocked" ]] && files+=("$f")
        done < <(_queue_find_jobs "$target")
    else
        for f in "$root/pol_block"/*.job "$root/policy_blocked"/*.job; do
            [[ -e "$f" ]] && files+=("$f")
        done
    fi
    if [[ "${#files[@]}" -eq 0 ]]; then
        echo "queue reevaluate: no pol_block jobs matched${target:+: $target}" >&2
        return 1
    fi
    for f in "${files[@]}"; do
        id="$(basename "$f" .job)"
        checked=$((checked + 1))
        if _queue_job_policy_execution_check "$f" >/dev/null 2>&1; then
            if [[ "$local_dryrun" -eq 1 ]]; then
                echo "DRYRUN: would requeue $id from $(basename "$(dirname "$f")") -> pending"
            else
                {
                    echo "REEVALUATED_AT=$(printf '%q' "$(date -Is)")"
                    echo "REEVALUATED_FROM=$(printf '%q' "$(basename "$(dirname "$f")")")"
                    echo "STATE=$(printf '%q' pending)"
                } >> "$f"
                mv -f "$f" "$root/pending/$id.job"
                _queue_log_event "pol_block_reevaluated" "$id" "$(_queue_job_name "$root/pending/$id.job" 2>/dev/null || echo -)" "pending" "result=requeued"
                echo "Requeued $id -> pending"
            fi
            moved=$((moved + 1))
        else
            reason="$(_queue_job_policy_execution_check "$f" 2>&1 >/dev/null || true)"
            echo "Still pol_block: $id"
            [[ -n "$reason" ]] && printf '  %s
' "$reason" | head -3
        fi
    done
    echo "Reevaluated $checked pol_block job(s); requeued $moved."
}

_queue_backup_create() {
    local out="" force=0 root running_count ts
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --force|-f) force=1; shift ;;
            --output|-o) out="${2:-}"; shift 2 ;;
            --quiesce) shift ;;
            *) [[ -z "$out" ]] && out="$1" || { echo "queue backup: unexpected argument: $1" >&2; return 2; }; shift ;;
        esac
    done
    root="$(_queue_root)"
    ts="$(date +%Y%m%d_%H%M%S 2>/dev/null || date +%s)"
    [[ -n "$out" ]] || out="$PWD/bashqueues-backup-${ts}.tar.gz"
    running_count="$(find "$root/running" -maxdepth 1 -name '*.job' -type f 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$running_count" != "0" && "$force" -ne 1 ]]; then
        echo "queue backup: $running_count running job(s); stop workers or use --force for a best-effort snapshot" >&2
        return 1
    fi
    mkdir -p "$(dirname "$out")" || return 1
    tar -C "$(dirname "$root")" -czf "$out" "$(basename "$root")" || return 1
    echo "Backup written: $out"
    echo "Queue root:     $root"
    _queue_log_event "backup_created" "backup" "backup" "admin" "path=$out root=$root force=$force" 2>/dev/null || true
}

_queue_backup_restore() {
    local archive="${1:-}" to="" force=0
    shift || true
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --to) to="${2:-}"; shift 2 ;;
            --force|-f) force=1; shift ;;
            *) echo "queue backup restore: unexpected argument: $1" >&2; return 2 ;;
        esac
    done
    [[ -n "$archive" ]] || { echo "Usage: queue backup restore <archive.tar.gz> --to <directory> [--force]" >&2; return 2; }
    [[ -f "$archive" ]] || { echo "queue backup restore: archive not found: $archive" >&2; return 1; }
    [[ -n "$to" ]] || { echo "queue backup restore: --to is required to avoid overwriting the live queue root" >&2; return 2; }
    if [[ -e "$to" && "$force" -ne 1 ]]; then
        echo "queue backup restore: destination exists; use --force: $to" >&2
        return 1
    fi
    rm -rf "$to"
    mkdir -p "$to" || return 1
    tar -C "$to" --strip-components=1 -xzf "$archive" || return 1
    echo "Backup restored into: $to"
}

_queue_backup_command() {
    local sub="${1:-create}"
    shift || true
    case "$sub" in
        create|save) _queue_backup_create "$@" ;;
        restore) _queue_backup_restore "$@" ;;
        *) _queue_backup_create "$sub" "$@" ;;
    esac
}

queue() {
    local dryrun=0

    if [[ "${1:-}" == "--dryrun" || "${1:-}" == "-n" ]]; then
        dryrun=1
        shift
    fi

    # User queue selection is deliberately exact and must happen before
    # _queue_init/root capture. Otherwise `queue user hc3 list` can still
    # initialise and read the previous/root queue.
    case "${1:-}" in
        --queue-user|--user-queue)
            [[ "$#" -ge 2 ]] || { echo "Usage: queue ${1:---queue-user} USER [command] [args...]" >&2; return 2; }
            _queue_select_user_queue "$2" || return "$?"
            shift 2
            if [[ "$#" -eq 0 ]]; then
                _queue_init
                echo "selected user: $(_queue_selected_user_for_display)"
                echo "queue root:    $(_queue_root)"
                [[ -n "${QUEUEBASH_SELECTED_ROOT:-}" ]] && echo "selected root: ${QUEUEBASH_SELECTED_ROOT}"
                echo "root owner:    $(_queue_root_owner_user 2>/dev/null || echo unknown)"
                return 0
            fi
            ;;
        user)
            [[ "$#" -ge 2 ]] || { echo "Usage: queue user USER [command] [args...]" >&2; return 2; }
            _queue_select_user_queue "$2" || return "$?"
            shift 2
            if [[ "$#" -eq 0 ]]; then
                _queue_init
                echo "selected user: $(_queue_selected_user_for_display)"
                echo "queue root:    $(_queue_root)"
                [[ -n "${QUEUEBASH_SELECTED_ROOT:-}" ]] && echo "selected root: ${QUEUEBASH_SELECTED_ROOT}"
                echo "root owner:    $(_queue_root_owner_user 2>/dev/null || echo unknown)"
                return 0
            fi
            ;;
    esac

    _queue_init

    local root="$(_queue_root)"
    local cmd="${1:-}"
    shift || true

    _queue_guard_foreign_user_queue_eval "$cmd" "${1:-}" "$cmd" "$@" || return "$?"

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
        queue-user|queue-owner)
            echo "selected user: $(_queue_selected_user_for_display)"
            echo "queue root:    $(_queue_root)"
            [[ -n "${QUEUEBASH_SELECTED_ROOT:-}" ]] && echo "selected root: ${QUEUEBASH_SELECTED_ROOT}"
            echo "root owner:    $(_queue_root_owner_user 2>/dev/null || echo unknown)"
            ;;

        queue-users)
            if [[ "$(id -u 2>/dev/null || echo 99999)" != "0" ]]; then
                id -un
            else
                getent passwd | awk -F: '$3 >= 1000 && $6 ~ /^\/home\// {print $1 "\t" $6 "/.queuebash"}' | sort
            fi
            ;;

        reevaluate|re-evaluate|recheck|policy-reevaluate|pol-block-reevaluate)
            _queue_pol_block_reevaluate "$@"
            ;;

        backup)
            _queue_backup_command "$@"
            ;;

        keygen)
            _queue_authorisation_keygen "$@"
            ;;
        keys)
            case "${1:-list}" in
                list|ls|"") _queue_authorisation_keys_list ;;
                show) shift; _queue_authorisation_keys_show "${1:-}" ;;
                *) echo "Usage: queue keys list|show NAME" >&2; return 2 ;;
            esac
            ;;
        authorise|authorize)
            _queue_authorise_job "$@"
            ;;
        authorisation|authorization|auth)
            case "${1:-list}" in
                generate|gen|new) shift; _queue_authorisation_generate "$@" ;;
                job|stamp|authorise|authorize) shift; _queue_authorise_job "$@" ;;
                list|ls|"") _queue_authorisation_list ;;
                policy|trust|trusted) _queue_authorisation_policy_show ;;
                show)
                    shift
                    local acode="${1:-}" afile
                    [[ -n "$acode" ]] || { echo "Usage: queue authorisation show CODE" >&2; return 2; }
                    afile="$(_queue_authorisation_file "$acode")" || { echo "queue authorisation show: invalid code" >&2; return 2; }
                    [[ -f "$afile" ]] || { echo "queue authorisation show: not found: $acode" >&2; return 1; }
                    sed -n '1,120p' "$afile"
                    echo "AUTHORISATION_FILE_INTEGRITY=$(_queue_authorisation_file_status "$afile" 2>/dev/null || true)"
                    ;;
                *) echo "Usage: queue authorisation generate|job|list|show|policy" >&2; return 2 ;;
            esac
            ;;
        generate)
            case "${1:-}" in
                authorisation|authorization|auth) shift; _queue_authorisation_generate "$@" ;;
                key|keys) shift; _queue_authorisation_keygen "$@" ;;
                *) echo "Usage: queue generate authorisation --admin ADMIN --user USER -- <command> | queue generate key authorisation NAME" >&2; return 2 ;;
            esac
            ;;

        cron|crontab|cron-bridge)
            _queue_cron_command "$@"
            ;;
        global|globals)
            _queue_global_command "$@"
            ;;
        draft|drafts)
            _queue_draft_command "$@"
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
            local sandbox_level="${QUEUEBASH_SANDBOX_LEVEL:-off}"
            local seccomp_profile="${QUEUEBASH_SECCOMP_PROFILE:-}"
            local sandbox_explicit=0
            local seccomp_explicit=0
            [[ -n "${QUEUEBASH_SANDBOX_LEVEL+x}" ]] && sandbox_explicit=1
            [[ -n "${QUEUEBASH_SECCOMP_PROFILE+x}" ]] && seccomp_explicit=1
            local seccomp_allow="${QUEUEBASH_SECCOMP_ALLOW:-}"
            local exception_sandbox_override=""
            local exception_seccomp_allow=""
            local exception_drop_cap=""
            local exception_add_port=""
            local security_reason=""
            local authorisation_code=""
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
                    --sandbox)
                        [[ -z "$2" ]] && { echo "queue submit: --sandbox needs a value: off|network-none|restrict-egress|strict" >&2; return 2; }
                        case "$2" in
                            off|none) sandbox_level="off" ;;
                            network-none|restrict-egress|strict) sandbox_level="$2" ;;
                            *) echo "queue submit: invalid --sandbox: $2" >&2; return 2 ;;
                        esac
                        sandbox_explicit=1
                        shift 2
                        ;;
                    --seccomp|--seccomp-profile)
                        [[ -z "$2" ]] && { echo "queue submit: $1 needs a value: off|docker-default|strict" >&2; return 2; }
                        case "$2" in
                            off|none|docker-default|strict) seccomp_profile="$2" ;;
                            *) echo "queue submit: invalid $1: $2" >&2; return 2 ;;
                        esac
                        seccomp_explicit=1
                        shift 2
                        ;;
                    --sandbox-override)
                        [[ -z "$2" ]] && { echo "queue submit: --sandbox-override needs a value" >&2; return 2; }
                        case "$2" in
                            off|none) exception_sandbox_override="off" ;;
                            network-none|restrict-egress|strict) exception_sandbox_override="$2" ;;
                            *) echo "queue submit: invalid --sandbox-override: $2" >&2; return 2 ;;
                        esac
                        shift 2
                        ;;
                    --seccomp-allow)
                        [[ -z "$2" ]] && { echo "queue submit: --seccomp-allow needs a systemd syscall group such as @debug" >&2; return 2; }
                        exception_seccomp_allow="${exception_seccomp_allow:+$exception_seccomp_allow }$2"
                        shift 2
                        ;;
                    --drop-cap)
                        [[ -z "$2" ]] && { echo "queue submit: --drop-cap needs a runtime cap name" >&2; return 2; }
                        exception_drop_cap="${exception_drop_cap:+$exception_drop_cap,}$2"
                        shift 2
                        ;;
                    --add-port)
                        [[ -z "$2" ]] && { echo "queue submit: --add-port needs a port or range" >&2; return 2; }
                        exception_add_port="${exception_add_port:+$exception_add_port,}$2"
                        shift 2
                        ;;
                    --reason)
                        [[ -z "$2" ]] && { echo "queue submit: --reason needs text" >&2; return 2; }
                        security_reason="$2"
                        shift 2
                        ;;
                    --authorisation|--authorization)
                        [[ -z "$2" ]] && { echo "queue submit: $1 needs a code" >&2; return 2; }
                        authorisation_code="$2"
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

            if [[ -z "$security_reason" && -n "${QUEUEBASH_SUBMIT_REASON_DEFAULT:-}" ]]; then
                security_reason="$QUEUEBASH_SUBMIT_REASON_DEFAULT"
            fi

            local submit_user="${QUEUEBASH_SELECTED_USER:-$(id -un 2>/dev/null || echo unknown)}"
            QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_TYPE=""
            QUEUEBASH_SUBMIT_SECURITY_EXEMPTION_DETAIL=""
            QUEUEBASH_SUBMIT_AUTO_AUTHORISATION_CODE=""
            _queue_submit_policy_check "${job_class:-${QUEUEBASH_DEFAULT_CLASS:-DEFAULT}}" "$submit_user" "$security_reason" "$authorisation_code" "$sandbox_level" "$seccomp_profile" "$exception_sandbox_override" "$exception_seccomp_allow" "$exception_drop_cap" "$exception_add_port" "$sandbox_explicit" "$seccomp_explicit" "$@" || return $?
            if [[ -z "$authorisation_code" && -n "${QUEUEBASH_SUBMIT_AUTO_AUTHORISATION_CODE:-}" ]]; then
                authorisation_code="$QUEUEBASH_SUBMIT_AUTO_AUTHORISATION_CODE"
            fi

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
                echo "  sandbox:  ${sandbox_level:-}"
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
                printf 'SANDBOX_LEVEL=%q\n' "$sandbox_level"
                printf 'SECURITY_SANDBOX_EXPLICIT=%q\n' "$sandbox_explicit"
                [[ -n "$seccomp_profile" ]] && printf 'SECCOMP_PROFILE=%q\n' "$seccomp_profile"
                printf 'SECURITY_SECCOMP_EXPLICIT=%q\n' "$seccomp_explicit"
                [[ -n "$seccomp_allow" ]] && printf 'SECCOMP_ALLOW=%q\n' "$seccomp_allow"
                [[ -n "$exception_sandbox_override" ]] && printf 'EXCEPTION_SANDBOX_OVERRIDE=%q\n' "$exception_sandbox_override"
                [[ -n "$exception_seccomp_allow" ]] && printf 'EXCEPTION_SECCOMP_ALLOW=%q\n' "$exception_seccomp_allow"
                [[ -n "$exception_drop_cap" ]] && printf 'EXCEPTION_DROP_CAP=%q\n' "$exception_drop_cap"
                [[ -n "$exception_add_port" ]] && printf 'EXCEPTION_ADD_PORT=%q\n' "$exception_add_port"
                [[ -n "$security_reason" ]] && printf 'SECURITY_EXCEPTION_REASON=%q\n' "$security_reason"
                if [[ -n "$authorisation_code" ]]; then
                    _auth_norm="$(_queue_authorisation_normalise_code "$authorisation_code" 2>/dev/null || printf '%s' "$authorisation_code")"
                    printf 'SECURITY_AUTHORISATION_CODE=%q\n' "$_auth_norm"
                fi
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

            _queue_append_class_defaults_to_job_file "$job" "${job_class:-${QUEUEBASH_DEFAULT_CLASS:-DEFAULT}}" "$id" "$name"
            _queue_append_policy_snapshot_to_job_file "$job"

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
            for state in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
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


        duplicate-qids|dups)
            _queue_duplicate_qids_report
            ;;

        legacy-manager|legacy-queuemgr)
            echo "queue: legacy manager has been removed; use: queue mgr" >&2
            return 2
            ;;

        asset-hint)
            _queue_asset_hints_print "${1:-}"
            ;;
        asset-hints)
            _queue_asset_hints_print
            ;;

        panel|qpanel|manager-panel)
            _queue_manager_entry panel "$@"
            ;;

        mgr|manager|qm|queuemgr)
            if [[ "$#" -eq 0 || "${1:-}" == "panel" ]]; then
                _queue_manager_entry panel "${@:2}"
            else
                _queue_manager_entry "$@"
            fi
            ;;

        dispatch-trace|trace-dispatch)
            _queue_dispatch_trace_show "${1:-120}"
            ;;

        exception|exceptions)
            _queue_exception_command "$@"
            ;;

        history|hist)
            _queue_job_history "$@"
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



        asset-refresh)
            local src_dir="${1:-}"
            [[ -n "$src_dir" ]] || { echo "Usage: queue asset-refresh <directory>" >&2; return 2; }
            _queue_asset_refresh_from_dir "$src_dir"
            ;;

        class-refresh)
            local src_dir="${1:-}"
            [[ -n "$src_dir" ]] || { echo "Usage: queue class-refresh <directory>" >&2; return 2; }
            _queue_class_refresh_from_dir "$src_dir"
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
                        source "$helper" >/dev/null 2>&1 || { echo "asset_contract_error: source failed"; exit 1; }
                        if declare -F queue_asset_facilities >/dev/null 2>&1; then
                            echo
                            echo "Published facilities:"
                            queue_asset_facilities
                            echo
                            echo "Contract check:"
                            _queue_asset_contract_validate_loaded "$helper" strict
                        else
                            echo "No queue_asset_facilities publisher found."
                            exit 1
                        fi
                    )
                    ;;
                validate)
                    local root="$(_queue_root)"
                    local failed=0 plugin
                    shopt -s nullglob
                    for plugin in "$root/assets.d"/*.sh; do
                        [[ -f "$plugin" ]] || continue
                        echo "=== validating asset helper: $(basename "$plugin") ==="
                        if ! _queue_asset_contract_validate_helper "$plugin" strict; then
                            failed=1
                        fi
                    done
                    shopt -u nullglob
                    [[ "$failed" -eq 0 ]] || return 1
                    ;;
                duplicates|dupes)
                    echo "=== duplicate asset facility publishers ==="
                    _queue_asset_scan_duplicate_publishers
                    ;;
                replace)
                    local family="${2:-}"
                    local src="${3:-}"
                    local force=0
                    [[ "${4:-}" == "--force" ]] && force=1
                    [[ -n "$family" && -n "$src" ]] || { echo "Usage: queue assets replace <family> <plugin.sh> [--force]" >&2; return 2; }
                    _queue_asset_replace_plugin "$family" "$src" "$force"
                    ;;
                rollback)
                    local family="${2:-}"
                    local backup="${3:-}"
                    [[ -n "$family" ]] || { echo "Usage: queue assets rollback <family> [backup-file]" >&2; return 2; }
                    _queue_asset_rollback_plugin "$family" "$backup"
                    ;;
                backups)
                    _queue_asset_list_backups "${2:-}"
                    return 0
                    ;;
                refresh)
                    local src_dir="${2:-}"
                    [[ -n "$src_dir" ]] || { echo "Usage: queue assets refresh <directory>" >&2; return 2; }
                    _queue_asset_refresh_from_dir "$src_dir"; return "$?"
                    ;;
                delete|archive)
                    local family="${2:-}"
                    [[ -n "$family" ]] || { echo "Usage: queue assets delete <family>" >&2; return 2; }
                    _queue_asset_delete_plugin "$family"; return "$?"
                    ;;
                undelete|unarchive)
                    local family="${2:-}"; local archive="${3:-}"
                    [[ -n "$family" ]] || { echo "Usage: queue assets undelete <family> [archive-file]" >&2; return 2; }
                    _queue_asset_undelete_plugin "$family" "$archive"; return "$?"
                    ;;
                disable)
                    local family="${2:-}"; local force="${3:-}"
                    [[ -n "$family" ]] || { echo "Usage: queue assets disable <family> [--force]" >&2; return 2; }
                    _queue_module_disable asset "$family" "$force"; return "$?"
                    ;;
                enable)
                    local family="${2:-}"
                    [[ -n "$family" ]] || { echo "Usage: queue assets enable <family>" >&2; return 2; }
                    _queue_module_enable asset "$family"; return "$?"
                    ;;
                archives)
                    _queue_asset_list_archives "${2:-}"; return 0
                    ;;
                explain)
                    _queue_asset_explain "${2:-}"; return "$?"
                    ;;
                expand)
                    echo "asset subcommands:"
                    echo "  list show validate duplicates dupes replace rollback backups refresh delete archive undelete unarchive enable disable archives explain expand"
                    echo
                    echo "asset families:"
                    local root="${QUEUEBASH_ROOT:-$HOME/.queuebash}"
                    if [[ -d "$root/assets.d" ]]; then
                        find "$root/assets.d" -maxdepth 1 -type f -name '*.sh' -printf '  %f\n' 2>/dev/null | sed 's/\.sh$//' | sort
                    fi
                    return 0
                    ;;
                *)
                    echo "Usage: queue assets list|show <family>|validate|duplicates|replace <family> <plugin.sh> [--force]|rollback <family> [backup-file]|backups [family]|refresh <directory>|delete <family>|undelete <family> [archive-file]|enable <family>|disable <family> [--force]|archives [family]|explain <family|family:check>|expand" >&2
                    return 2
                    ;;
            esac
            ;;


        cap|caps)
            case "${1:-list}" in
                list|facilities) _queue_cap_plugins_list ;;
                show|explain)
                    local family="${2:-}"
                    [[ -n "$family" ]] || { echo "Usage: queue caps explain <family>" >&2; return 2; }
                    _queue_modules_explain "cap:$family"
                    ;;
                refresh) shift; _queue_cap_refresh "$@" ;;
                disable)
                    local family="${2:-}"
                    [[ -n "$family" ]] || { echo "Usage: queue caps disable <family>" >&2; return 2; }
                    _queue_module_disable cap "$family"; return "$?"
                    ;;
                enable)
                    local family="${2:-}"
                    [[ -n "$family" ]] || { echo "Usage: queue caps enable <family>" >&2; return 2; }
                    _queue_module_enable cap "$family"; return "$?"
                    ;;
                *) echo "Usage: queue caps list|explain <family>|refresh <directory>|enable <family>|disable <family>" >&2; return 2 ;;
            esac
            ;;

        module|modules)
            case "${1:-list}" in
                list|"") _queue_modules_list | sort ;;
                explain|show) shift; _queue_modules_explain "$@" ;;
                enable) shift; _queue_module_enable "$@" ;;
                disable) shift; _queue_module_disable "$@" ;;
                refresh)
                    local kind="${2:-}" dir="${3:-}"
                    case "$kind" in
                        class|classes) _queue_classes_refresh "$dir" ;;
                        asset|assets) _queue_asset_refresh_from_dir "$dir" ;;
                        cap|caps) _queue_cap_refresh "$dir" ;;
                        *) echo "Usage: queue modules refresh class|asset|cap <directory>" >&2; return 2 ;;
                    esac
                    ;;
                *) echo "Usage: queue modules list|explain <kind:name>|enable kind name|disable kind name [--force]|refresh kind <directory>" >&2; return 2 ;;
            esac
            ;;


        policy|policies)
            case "${1:-list}" in
                list|"")
                    local kind="${2:-}" name file origin
                    if [[ -n "$kind" ]]; then
                        _queue_policy_valid_kind "$kind" || { echo "Usage: queue policies list [sandbox|seccomp|class-statement]" >&2; return 2; }
                        echo "=== $kind policies ==="
                        while IFS= read -r name; do
                            [[ -n "$name" ]] || continue
                            file="$(_queue_policy_file "$kind" "$name" 2>/dev/null || true)"
                            origin="$(_queue_policy_origin "$file")"
                            printf '%-20s %-8s %s\n' "$name" "$origin" "$file"
                        done < <(_queue_policy_list "$kind")
                    else
                        queue policies list sandbox
                        echo
                        queue policies list seccomp
                        echo
                        queue policies list class-statement
                    fi
                    ;;
                show|explain)
                    local kind="${2:-}" name="${3:-}" file found_kind="" found_count=0 k
                    if [[ -z "$kind" ]]; then
                        _queue_policy_explain_effective_class_statement
                        return $?
                    elif [[ -z "$name" ]]; then
                        # Friendly shorthand: queue policy show policyblock-test
                        # or queue policy explain.  Prefer the active class-statement
                        # policy for a bare explain because class-statement is the
                        # governing site policy operators usually mean.
                        name="$kind"
                        kind=""
                        for k in class-statement sandbox seccomp; do
                            if _queue_policy_file "$k" "$name" >/dev/null 2>&1; then
                                found_kind="$k"
                                found_count=$((found_count + 1))
                            fi
                        done
                        if [[ "$found_count" -eq 1 ]]; then
                            kind="$found_kind"
                        else
                            echo "Usage: queue policies show sandbox|seccomp|class-statement NAME" >&2
                            echo "       queue policy explain [NAME]   # infers kind when unique; default is active class-statement" >&2
                            return 2
                        fi
                    fi
                    _queue_policy_valid_kind "$kind" || { echo "queue policies show: invalid kind: $kind" >&2; return 2; }
                    file="$(_queue_policy_file "$kind" "$name")" || { echo "queue policies show: not found: $kind $name" >&2; return 1; }
                    echo "=== $kind policy: $name ==="
                    echo "origin: $(_queue_policy_origin "$file")"
                    echo "sha256: $(_queue_policy_sha256 "$file" 2>/dev/null || echo unknown)"
                    echo "file: $file"
                    sed -n '1,200p' "$file"
                    ;;
                path)
                    local kind="${2:-}" name="${3:-}" scope="auto" file
                    [[ -n "$kind" && -n "$name" ]] || { echo "Usage: queue policies path sandbox|seccomp|class-statement NAME [--shared|--personal]" >&2; return 2; }
                    shift 3 || true
                    while [[ "$#" -gt 0 ]]; do
                        case "$1" in
                            --shared|--site|--admin|--etc) scope="shared"; shift ;;
                            --personal|--queue|--user) scope="personal"; shift ;;
                            *) echo "queue policies path: unknown option: $1" >&2; return 2 ;;
                        esac
                    done
                    file="$(_queue_policy_edit_target_file "$scope" "$kind" "$name")" || { echo "queue policies path: invalid target" >&2; return 2; }
                    echo "$file"
                    ;;

                edit|editor)
                    local kind="${2:-}" name="${3:-}" scope="auto" file src editor origin
                    [[ -n "$kind" && -n "$name" ]] || { echo "Usage: queue policies edit sandbox|seccomp|class-statement NAME [--shared|--personal]" >&2; return 2; }
                    shift 3 || true
                    while [[ "$#" -gt 0 ]]; do
                        case "$1" in
                            --shared|--site|--admin|--etc) scope="shared"; shift ;;
                            --personal|--queue|--user) scope="personal"; shift ;;
                            *) echo "queue policies edit: unknown option: $1" >&2; return 2 ;;
                        esac
                    done
                    _queue_policy_valid_kind "$kind" || { echo "queue policies edit: invalid kind: $kind" >&2; return 2; }
                    _queue_policy_valid_name "$name" || { echo "queue policies edit: invalid policy name: $name" >&2; return 2; }
                    file="$(_queue_policy_edit_target_file "$scope" "$kind" "$name")" || { echo "queue policies edit: invalid target" >&2; return 2; }
                    if [[ "$(_queue_policy_origin "$file")" == "shared" && "$(id -u 2>/dev/null || echo 1)" != "0" ]]; then
                        echo "queue policies edit: shared policy editing requires root: $file" >&2
                        return 1
                    fi
                    mkdir -p "$(dirname "$file")"
                    if [[ ! -f "$file" ]]; then
                        if src="$(_queue_policy_file "$kind" "$name" 2>/dev/null)" && [[ -f "$src" ]]; then
                            cp "$src" "$file"
                        else
                            _queue_policy_emit_template "$kind" "$name" > "$file"
                        fi
                    fi
                    origin="$(_queue_policy_origin "$file")"
                    echo "Editing $origin policy: $file" >&2
                    editor="${VISUAL:-${EDITOR:-vi}}"
                    "$editor" "$file"
                    ;;
                create|new)
                    local kind="${2:-}" name="${3:-}" from="" scope="auto" file src
                    [[ -n "$kind" && -n "$name" ]] || { echo "Usage: queue policies create sandbox|seccomp|class-statement NAME [--from EXISTING] [--shared|--personal]" >&2; return 2; }
                    shift 3 || true
                    while [[ "$#" -gt 0 ]]; do
                        case "$1" in
                            --from) from="${2:-}"; shift 2 ;;
                            --shared|--site|--admin|--etc) scope="shared"; shift ;;
                            --personal|--queue|--user) scope="personal"; shift ;;
                            *) echo "queue policies create: unknown option: $1" >&2; return 2 ;;
                        esac
                    done
                    _queue_policy_valid_kind "$kind" || { echo "queue policies create: invalid kind: $kind" >&2; return 2; }
                    _queue_policy_valid_name "$name" || { echo "queue policies create: invalid policy name: $name" >&2; return 2; }
                    file="$(_queue_policy_edit_target_file "$scope" "$kind" "$name")" || { echo "queue policies create: invalid target" >&2; return 2; }
                    if [[ "$(_queue_policy_origin "$file")" == "shared" && "$(id -u 2>/dev/null || echo 1)" != "0" ]]; then
                        echo "queue policies create: shared policy creation requires root: $file" >&2
                        return 1
                    fi
                    mkdir -p "$(dirname "$file")"
                    [[ ! -e "$file" ]] || { echo "queue policies create: already exists: $file" >&2; return 1; }
                    if [[ -n "$from" ]]; then
                        src="$(_queue_policy_file "$kind" "$from")" || { echo "queue policies create: source policy not found: $kind $from" >&2; return 1; }
                        cp "$src" "$file"
                        sed -i "s/^QUEUEBASH_POLICY_NAME=.*/QUEUEBASH_POLICY_NAME=$name/" "$file" 2>/dev/null || true
                    else
                        _queue_policy_emit_template "$kind" "$name" > "$file"
                    fi
                    echo "Created $(_queue_policy_origin "$file") policy: $file"
                    ;;
                *)
                    echo "Usage: queue policies list [sandbox|seccomp|class-statement]|show KIND NAME|path KIND NAME [--shared|--personal]|edit KIND NAME [--shared|--personal]|create KIND NAME [--from EXISTING] [--shared|--personal]" >&2
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
                    _queue_class_list_names
                    ;;
                show|cat)
                    local cname="${2:-}"
                    [[ -z "$cname" ]] && { echo "Usage: queue class show <class>" >&2; return 2; }
                    local cfile
                    cfile="$(_queue_class_file "$cname")"
                    [[ -f "$cfile" ]] || { echo "queue class: not found: $cname ($cfile)" >&2; return 1; }
                    echo "=== class: $cname ==="
                    echo "file: $cfile"
                    cat "$cfile"
                    ;;
                init|new)
                    local cname="${2:-}"
                    [[ -z "$cname" ]] && { echo "Usage: queue class init <class>" >&2; return 2; }
                    _queue_class_valid_name "$cname" || { echo "queue class: invalid class name: $cname" >&2; return 2; }
                    local cfile
                    cfile="$root/classes/$cname.env"
                    [[ -e "$cfile" ]] && { echo "queue class: already exists: $cfile" >&2; return 1; }
                    cat > "$cfile" <<'EOF'
# bashqueues class definition
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
EOF
                    echo "Created $cfile"
                    ;;
                edit)
                    local cname="${2:-}"
                    [[ -z "$cname" ]] && { echo "Usage: queue class edit <class>" >&2; return 2; }
                    local cfile
                    cfile="$(_queue_class_file "$cname")"
                    [[ -f "$cfile" ]] || { echo "queue class: not found: $cname ($cfile)" >&2; return 1; }
                    "${EDITOR:-vi}" "$cfile"
                    _queue_class_validate_file "$(basename "$cfile" .env)" "$cfile"
                    ;;
                validate)
                    local cname="${2:-}"
                    if [[ -n "$cname" ]]; then
                        local cfile
                        cfile="$(_queue_class_file "$cname")"
                        [[ -f "$cfile" ]] || { echo "queue class: not found: $cname ($cfile)" >&2; return 1; }
                        _queue_class_validate_file "$(basename "$cfile" .env)" "$cfile"
                    else
                        local failed=0 cf
                        shopt -s nullglob
                        for cf in "$root/classes"/*.env; do echo "=== validating class: $(basename "$cf" .env) ==="; _queue_class_validate_file "$(basename "$cf" .env)" "$cf" || failed=1; done
                        shopt -u nullglob
                        [[ "$failed" -eq 0 ]] || return 1
                    fi
                    ;;
                replace) local cname="${2:-}" src="${3:-}" force=0; [[ "${4:-}" == "--force" ]] && force=1; [[ -n "$cname" && -n "$src" ]] || { echo "Usage: queue class replace <class> <file.env> [--force]" >&2; return 2; }; _queue_class_replace "$cname" "$src" "$force" ;;
                refresh) local src_dir="${2:-}"; [[ -n "$src_dir" ]] || { echo "Usage: queue class refresh <directory>" >&2; return 2; }; _queue_class_refresh_from_dir "$src_dir" ;;
                rollback) local cname="${2:-}" backup="${3:-}"; [[ -n "$cname" ]] || { echo "Usage: queue class rollback <class> [backup-file]" >&2; return 2; }; _queue_class_rollback "$cname" "$backup" ;;
                backups) _queue_class_backups "${2:-}" ;;
                delete|archive) local cname="${2:-}"; [[ -n "$cname" ]] || { echo "Usage: queue class delete <class>" >&2; return 2; }; _queue_class_delete "$cname" ;;
                undelete|unarchive) local cname="${2:-}" archive="${3:-}"; [[ -n "$cname" ]] || { echo "Usage: queue class undelete <class> [archive-file]" >&2; return 2; }; _queue_class_undelete "$cname" "$archive" ;;
                disable) local cname="${2:-}"; [[ -n "$cname" ]] || { echo "Usage: queue classes disable <class>" >&2; return 2; }; _queue_module_disable class "$cname" ;;
                enable) local cname="${2:-}"; [[ -n "$cname" ]] || { echo "Usage: queue classes enable <class>" >&2; return 2; }; _queue_module_enable class "$cname" ;;
                archives) _queue_class_archives "${2:-}" ;;
                explain) _queue_class_explain "${2:-}" ;;
                expand) echo "class subcommands:"; echo "  list show init edit validate replace refresh rollback backups delete archive undelete unarchive enable disable archives explain expand"; echo; echo "classes:"; _queue_class_list_names | sed 's/^/  /' ;;
                *) echo "Usage: queue class list|show <class>|init <class>|edit <class>|validate [class]|replace <class> <file.env> [--force]|refresh <directory>|rollback <class> [backup-file]|backups [class]|delete <class>|undelete <class> [archive-file]|enable <class>|disable <class>|archives [class]|explain <class>|expand" >&2; return 2 ;;
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
            for state in pending running paused done failed pol_block policy_blocked interrupted cancelled deleted; do
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
                echo "Resubmit clones failed/interrupted/pol_block job(s) into pending with new QID(s), preserving the failed originals." >&2
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
                [[ "$state" == "failed" || "$state" == "interrupted" || "$state" == "pol_block" || "$state" == "policy_blocked" ]] && matches+=( "$f" )
            done < <(_queue_find_jobs "$target")

            if [[ "${#all_matches[@]}" -eq 0 ]]; then
                echo "queue resubmit: no matching QID or exact job name: $target" >&2
                return 1
            fi

            if [[ "${#matches[@]}" -eq 0 ]]; then
                echo "queue resubmit: matching job(s) found, but none are in failed, interrupted, or pol_block state:" >&2
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
                    echo "DRYRUN: would resubmit failed/interrupted/pol_block job:"
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
                echo "DRYRUN: would resubmit $count failed/interrupted/pol_block job(s)."
            else
                echo "Resubmitted $count failed/interrupted/pol_block job(s)."
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


        system-daemon|system-supervisor|system-sentinel|all-user-daemon|multi-user-daemon)
            _queue_system_daemon_command "$@"
            ;;

        daemon)
            _queue_sentinel_command --min-workers 1 "$@"
            ;;

        sentinel|supervisor|supervise|scheduler)
            _queue_sentinel_command "$@"
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
                echo "Detached workers started. Use: queue workers
  queue mgr|manager|qm"
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
                done|failed|pol_block|policy_blocked|paused|interrupted|cancelled|deleted)
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
                        find "$root"/{pending,running,paused,done,failed,pol_block,policy_blocked,deleted,logs} -maxdepth 1 -type f -printf '  %p\n' 2>/dev/null
                    else
                        rm -f "$root"/{pending,running,paused,done,failed,pol_block,policy_blocked,cancelled,deleted}/*.job
                        rm -f "$root/logs"/*.log
                        echo "Cleared all jobs and logs"
                    fi
                    ;;
                *) echo "Usage: queue clear done|failed|pol_block|policy_blocked|paused|interrupted|cancelled|deleted|all [--dryrun]" >&2; return 2 ;;
            esac
            ;;

        *)
            echo "Unknown queue command: $cmd" >&2
            _queue_help
            return 2
            ;;
    esac
}



_queue_system_daemon_candidate_users() {
    local include_root="${1:-0}" user home
    if [[ "$include_root" == "1" && -d /root/.queuebash ]]; then
        printf '%s\t%s\n' root /root/.queuebash
    fi
    getent passwd 2>/dev/null | awk -F: '$3 >= 1000 && $6 ~ /^\/home\// {print $1 "\t" $6 "/.queuebash"}' | while IFS=$'\t' read -r user home; do
        [[ -n "$user" && -d "$home" ]] || continue
        printf '%s\t%s\n' "$user" "$home"
    done | sort -u
}

_queue_system_daemon_tick_user() {
    local user="$1" qroot="$2" min_workers="$3" dry="$4" source_file
    [[ -n "$user" && -n "$qroot" ]] || return 0
    [[ -d "$qroot" ]] || return 0
    source_file="${BASH_SOURCE[0]}"
    if [[ "$dry" == "1" ]]; then
        echo "system-daemon: would check user=$user root=$qroot min_workers=$min_workers"
        return 0
    fi
    echo "system-daemon: checking user=$user root=$qroot"
    if [[ "$user" == "$(id -un 2>/dev/null || echo root)" ]]; then
        QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_ROOT="$qroot" queue daemon --once --min-workers "$min_workers"
        return "$?"
    fi
    if command -v runuser >/dev/null 2>&1; then
        runuser -u "$user" -- bash -lc "$(printf 'export QUEUEBASH_ALLOW_NONINTERACTIVE=1; export QUEUEBASH_ROOT=%q; source %q >/dev/null 2>&1; queue daemon --once --min-workers %q' "$qroot" "$source_file" "$min_workers")"
        return "$?"
    fi
    if command -v sudo >/dev/null 2>&1; then
        sudo -u "$user" bash -lc "$(printf 'export QUEUEBASH_ALLOW_NONINTERACTIVE=1; export QUEUEBASH_ROOT=%q; source %q >/dev/null 2>&1; queue daemon --once --min-workers %q' "$qroot" "$source_file" "$min_workers")"
        return "$?"
    fi
    echo "system-daemon: cannot switch to user=$user; runuser/sudo not found" >&2
    return 126
}

_queue_system_daemon_tick() {
    local min_workers="${1:-1}" include_root="${2:-0}" dry="${3:-0}" line user qroot any=0 rc=0
    while IFS=$'\t' read -r user qroot; do
        [[ -n "$user" ]] || continue
        any=1
        if ! _queue_system_daemon_tick_user "$user" "$qroot" "$min_workers" "$dry"; then
            rc=1
        fi
    done < <(_queue_system_daemon_candidate_users "$include_root")
    if [[ "$any" -eq 0 ]]; then
        echo "system-daemon: no user queue roots found"
    fi
    return "$rc"
}

_queue_system_daemon_command() {
    local interval=30 once=0 detach=0 dry=0 min_workers=1 include_root=0 pid pidfile state_dir=/var/lib/bashqueues/daemon
    while [[ "$#" -gt 0 ]]; do
        case "${1:-}" in
            --interval|-i) interval="${2:-30}"; shift 2 ;;
            --once) once=1; shift ;;
            --detach|-d|--background) detach=1; shift ;;
            --min-workers|--min-worker) min_workers="${2:-1}"; shift 2 ;;
            --include-root) include_root=1; shift ;;
            --dryrun|-n) dry=1; shift ;;
            --help|-h)
                cat <<'EOF'
Usage: queue system-daemon [--once] [--interval SEC] [--detach] [--min-workers N] [--include-root]
       queue system-supervisor [same options]

Root-only multi-user control loop.  It quickly scans known user queue roots and,
for each queue, delegates to that queue owner to run:
  queue daemon --once --min-workers N

This does not run user jobs as root.  Each per-user sentinel performs cheap
control-plane checks and starts at least N detached user workers only when that
user has due/dependency-ready pending work.
EOF
                return 0 ;;
            *) echo "queue system-daemon: unexpected argument: $1" >&2; return 2 ;;
        esac
    done
    [[ "$(id -u 2>/dev/null || echo 99999)" == "0" ]] || { echo "queue system-daemon: must be run as root" >&2; return 126; }
    [[ "$interval" =~ ^[0-9]+$ && "$interval" -ge 1 ]] || { echo "queue system-daemon: interval must be a positive integer" >&2; return 2; }
    [[ "$min_workers" =~ ^[0-9]+$ ]] || { echo "queue system-daemon: min-workers must be a non-negative integer" >&2; return 2; }
    if [[ "$dry" -eq 1 ]]; then
        echo "DRYRUN: would run system-daemon interval=${interval}s once=$once detach=$detach min_workers=$min_workers include_root=$include_root"
        _queue_system_daemon_tick "$min_workers" "$include_root" 1
        return 0
    fi
    if [[ "$detach" -eq 1 ]]; then
        mkdir -p "$state_dir" 2>/dev/null || true
        (
            export QUEUEBASH_SYSTEM_DAEMON=1
            while true; do
                _queue_system_daemon_tick "$min_workers" "$include_root" 0 || true
                [[ "$once" -eq 1 ]] && break
                sleep "$interval"
            done
        ) &
        pid="$!"
        pidfile="$state_dir/system_daemon_${pid}.pid"
        printf '%s\n' "$pid" > "$pidfile" 2>/dev/null || true
        echo "Started bashqueues system-daemon pid=$pid interval=${interval}s min_workers=$min_workers"
        return 0
    fi
    if [[ "$once" -eq 1 ]]; then
        _queue_system_daemon_tick "$min_workers" "$include_root" 0
        return "$?"
    fi
    echo "Running bashqueues system-daemon interval=${interval}s min_workers=$min_workers. Ctrl+C to stop."
    while true; do
        _queue_system_daemon_tick "$min_workers" "$include_root" 0 || true
        sleep "$interval"
    done
}

_queue_sentinel_running_jobs_fix_stale() {
    local root="$(_queue_root)" f id
    shopt -s nullglob
    for f in "$root"/running/*.job; do
        [[ -f "$f" ]] || continue
        if _queue_health_running_is_stale2 "$f"; then
            id="$(basename "$f" .job)"
            _queue_health_mark_interrupted "$f"
            _queue_log_event "sentinel_interrupted_stale" "$id" "$(_queue_job_name "$root/interrupted/$id.job" 2>/dev/null || echo -)" "interrupted" "reason=stale-running-detected-by-sentinel"
            echo "sentinel: moved stale running job to interrupted: $id"
        fi
    done
    shopt -u nullglob
}

_queue_sentinel_move_pending_to_pol_block() {
    local jobf="$1" reason="$2" root id dest log name now
    root="$(_queue_root)"
    [[ -f "$jobf" ]] || return 0
    id="$(basename "$jobf" .job)"
    name="$(_queue_job_name "$jobf" 2>/dev/null || echo -)"
    dest="$root/pol_block/$id.job"
    log="$root/logs/$id.log"
    now="$(date -Is 2>/dev/null || date)"
    mkdir -p "$root/pol_block" "$root/logs" 2>/dev/null || true

    {
        echo "=== queue job $id : $name ==="
        echo "pol_block: $now"
        echo "state: pol_block"
        echo "sentinel: $$"
        echo
        echo "POLICY_BLOCKED"
        echo "$reason"
        echo
        echo "No class claims, asset preflight checks, dynamic preflight checks, global claims, or payload launch were attempted."
        echo "Blocked by cheap sentinel policy gate before worker dispatch."
    } > "$log" 2>&1

    {
        printf '\n# Policy blocked by sentinel at %q\n' "$now"
        printf 'POLICY_BLOCKED=1\n'
        printf 'POLICY_BLOCKED_AT=%q\n' "$now"
        printf 'POLICY_BLOCKED_BY=%q\n' "sentinel"
        printf 'POLICY_BLOCKED_REASON=%q\n' "$reason"
    } >> "$jobf"
    _queue_append_summary_to_job "$jobf" 78 "$log"

    if mv "$jobf" "$dest" 2>/dev/null; then
        _queue_job_stream_temp_cleanup "$id"
        _queue_log_event "pol_block" "$id" "$name" "pol_block" "sentinel=1"
        echo "sentinel: pol_block $id"
    fi
}

_queue_sentinel_check_pending_policy() {
    local root="$(_queue_root)" f id reason
    shopt -s nullglob
    for f in "$root"/pending/*.job; do
        [[ -f "$f" ]] || continue
        id="$(basename "$f" .job)"
        reason=""
        if ! reason="$(_queue_job_policy_execution_check "$f" 2>&1)"; then
            _queue_sentinel_move_pending_to_pol_block "$f" "$reason"
        fi
    done
    shopt -u nullglob
}

_queue_sentinel_asset_is_deadline_spec() {
    local spec="$1" family check target
    eval "set -- $spec"
    (($# >= 3)) || return 1
    family="$1"; check="$2"; target="$3"
    [[ "$family" == "deadline" && ( "$check" == "monitor" || "$check" == "panic" ) ]]
}

_queue_sentinel_eval_deadline_for_job() {
    local jobf="$1" root id spec rc line helper
    [[ -f "$jobf" ]] || return 0
    root="$(_queue_root)"
    id="$(basename "$jobf" .job)"
    (
        # Source the job before class context so JOB_* variables are available
        # to deadline.sh helpers, but do not run class claims or normal assets.
        JOB_ID=""; JOB_NAME=""; JOB_CLASS=""; PRIORITY=""; COMMAND=()
        source "$jobf" >/dev/null 2>&1 || exit 0
        _queue_class_load_for_job "$jobf" >/dev/null 2>&1 || exit 0
        helper="$(_queue_asset_helper_path deadline)"
        [[ -f "$helper" ]] || exit 0
        for spec in "${QUEUE_CLASS_EXCLUSIVE_ASSET_SPECS[@]}" "${QUEUE_CLASS_SHARED_ASSET_SPECS[@]}"; do
            [[ -n "$spec" ]] || continue
            _queue_sentinel_asset_is_deadline_spec "$spec" || continue
            # Deadline assets are deliberately cheap/control-plane capable.
            # Their output may include priority escalation, fallback exception,
            # or bounded extra-worker audit messages.
            _queue_asset_implied_preflight_spec "$spec"
        done
        exit 0
    ) 2>&1 | while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        _queue_dispatch_trace_log "sentinel" "deadline $id: $line" 2>/dev/null || true
    done
}

_queue_sentinel_eval_deadlines() {
    local root="$(_queue_root)" f
    shopt -s nullglob
    for f in "$root"/pending/*.job; do
        [[ -f "$f" ]] || continue
        # The sentinel should be cheap and should not evaluate deadlines for jobs
        # that are not yet schedule/dependency eligible.
        _queue_job_retry_due "$f" || continue
        _queue_job_schedule_due "$f" || continue
        _queue_job_dependencies_satisfied "$f" || continue
        _queue_sentinel_eval_deadline_for_job "$f"
    done
    shopt -u nullglob
}

_queue_sentinel_live_worker_count() {
    local root="$(_queue_root)" pf pid count=0
    shopt -s nullglob
    for pf in "$root"/workers/worker_*.pid; do
        [[ -f "$pf" ]] || continue
        pid="$(cat "$pf" 2>/dev/null || true)"
        if [[ -n "$pid" && -d "/proc/$pid" ]]; then
            count=$((count + 1))
        else
            rm -f "$pf" 2>/dev/null || true
        fi
    done
    shopt -u nullglob
    printf '%s
' "$count"
}

_queue_sentinel_ready_pending_count() {
    local root="$(_queue_root)" f count=0
    shopt -s nullglob
    for f in "$root"/pending/*.job; do
        [[ -f "$f" ]] || continue
        _queue_job_retry_due "$f" || continue
        _queue_job_schedule_due "$f" || continue
        _queue_job_dependencies_satisfied "$f" || continue
        _queue_job_policy_execution_check "$f" >/dev/null 2>&1 || continue
        count=$((count + 1))
    done
    shopt -u nullglob
    printf '%s
' "$count"
}

_queue_sentinel_ensure_min_workers() {
    local min_workers="${1:-0}" root live ready need i wp
    [[ "$min_workers" =~ ^[0-9]+$ ]] || min_workers=0
    [[ "$min_workers" -gt 0 ]] || return 0
    root="$(_queue_root)"
    ready="$(_queue_sentinel_ready_pending_count 2>/dev/null || echo 0)"
    [[ "$ready" -gt 0 ]] || return 0
    live="$(_queue_sentinel_live_worker_count 2>/dev/null || echo 0)"
    [[ "$live" -lt "$min_workers" ]] || return 0
    need=$((min_workers - live))
    mkdir -p "$root/workers" 2>/dev/null || true
    for ((i=1; i<=need; i++)); do
        (_queue_worker "sentinel-$i") &
        wp="$!"
        echo "$wp" > "$root/workers/worker_${wp}.pid" 2>/dev/null || true
        _queue_log_event "sentinel_worker_started" "" "" "workers" "pid=$wp min_workers=$min_workers ready=$ready"
        echo "sentinel: started worker pid=$wp ready=$ready min_workers=$min_workers"
    done
}

_queue_sentinel_tick() {
    local min_workers="${1:-0}"
    _queue_init
    _queue_health_clean_dead_workers >/dev/null 2>&1 || true
    _queue_sentinel_running_jobs_fix_stale || true
    _queue_sentinel_check_pending_policy || true
    _queue_sentinel_eval_deadlines || true
    _queue_sentinel_ensure_min_workers "$min_workers" || true
}

_queue_sentinel_command() {
    local interval=30 once=0 detach=0 dry=0 min_workers=0 root pidfile pid
    while [[ "$#" -gt 0 ]]; do
        case "${1:-}" in
            --interval|-i) interval="${2:-30}"; shift 2 ;;
            --once) once=1; shift ;;
            --detach|-d|--background) detach=1; shift ;;
            --min-workers|--min-worker) min_workers="${2:-1}"; shift 2 ;;
            --dryrun|-n) dry=1; shift ;;
            --help|-h)
                cat <<'EOF'
Usage: queue sentinel [--once] [--interval SEC] [--detach] [--min-workers N]
       queue daemon [--interval SEC] [--detach]

Runs the cheap control-plane queue sentinel. It does not run normal asset
preflight. With --min-workers N, it also keeps at least N detached payload
worker available whenever a due/dependency-ready pending job exists.
It only performs inexpensive checks:
  - remove dead detached-worker PID files
  - mark definitely stale running jobs as interrupted
  - apply the shared/admin policy gate to pending jobs
  - evaluate deadline:monitor/deadline:panic assets for due, dependency-ready jobs

Use queue start/run for manual payload workers. queue daemon is shorthand for
queue sentinel --min-workers 1.
EOF
                return 0 ;;
            *) echo "queue sentinel: unexpected argument: $1" >&2; return 2 ;;
        esac
    done
    [[ "$interval" =~ ^[0-9]+$ && "$interval" -ge 1 ]] || { echo "queue sentinel: interval must be a positive integer" >&2; return 2; }
    [[ "$min_workers" =~ ^[0-9]+$ ]] || { echo "queue sentinel: min-workers must be a non-negative integer" >&2; return 2; }
    if [[ "$dry" -eq 1 ]]; then
        echo "DRYRUN: would run queue sentinel interval=${interval}s once=$once detach=$detach min_workers=$min_workers"
        return 0
    fi
    root="$(_queue_root)"
    mkdir -p "$root/workers" 2>/dev/null || true
    if [[ "$detach" -eq 1 ]]; then
        (
            export QUEUEBASH_SENTINEL=1
            while true; do
                _queue_sentinel_tick "$min_workers"
                [[ "$once" -eq 1 ]] && break
                sleep "$interval"
            done
        ) &
        pid="$!"
        pidfile="$root/workers/sentinel_${pid}.pid"
        printf '%s\n' "$pid" > "$pidfile" 2>/dev/null || true
        echo "Started queue sentinel pid=$pid interval=${interval}s min_workers=$min_workers"
        _queue_log_event "sentinel_started" "" "" "workers" "pid=$pid interval=$interval detached=1 min_workers=$min_workers"
        return 0
    fi
    export QUEUEBASH_SENTINEL=1
    if [[ "$once" -eq 1 ]]; then
        _queue_sentinel_tick "$min_workers"
        return 0
    fi
    echo "Running queue sentinel interval=${interval}s min_workers=$min_workers. Ctrl+C to stop."
    while true; do
        _queue_sentinel_tick "$min_workers"
        sleep "$interval"
    done
}

_queue_worker_external_move_state() {
    local id="$1"
    local root="$(_queue_root)"
    local state
    for state in cancelled deleted interrupted paused done failed pol_block policy_blocked pending; do
        if [[ -f "$root/$state/$id.job" ]]; then
            printf '%s\n' "$state"
            return 0
        fi
    done
    printf '%s\n' "missing"
}

_queue_worker() {
    export QUEUEBASH_WORKER_ID="${worker_id:-${1:-?}}"
    _queue_dispatch_trace_log "${worker_id:-${1:-?}}" "entered worker loop"
    _queue_init

    local worker_id="$1"
    local root="$(_queue_root)"


    while true; do
        local job
        job="$(_queue_next_job)"
        [[ -n "$job" ]] || break

        local id
        id="$(basename "$job" .job)"

        local running="$root/running/$id.job"
        local done="$root/done/$id.job"
        local failed="$root/failed/$id.job"
        local policy_blocked="$root/pol_block/$id.job"
        local log="$root/logs/$id.log"

        if ! _queue_move_pending_to_running "$job" "$running" "$id" "${worker_id:-${1:-?}}"; then
            # Avoid burning CPU forever on a filesystem/path collision.
            sleep "${QUEUEBASH_MOVE_FAIL_SLEEP:-1}"
            continue
        fi

        local policy_reason=""
        if ! policy_reason="$(_queue_job_policy_execution_check "$running" 2>&1)"; then
            _queue_dispatch_trace_log "${worker_id:-${1:-?}}" "policy blocked $id: $policy_reason"
            {
                echo "=== queue job $id : $(_queue_job_name "$running" 2>/dev/null || echo -) ==="
                echo "pol_block: $(date -Is)"
                echo "state: pol_block"
                echo "worker: $worker_id"
                echo
                echo "POLICY_BLOCKED"
                echo "$policy_reason"
                echo
                echo "No class claims, asset preflight checks, dynamic preflight checks, global claims, or payload launch were attempted."
            } > "$log" 2>&1
            {
                printf '
# Policy blocked by worker at %q
' "$(date -Is 2>/dev/null || date)"
                printf 'POLICY_BLOCKED=1
'
                printf 'POLICY_BLOCKED_AT=%q
' "$(date -Is 2>/dev/null || date)"
                printf 'POLICY_BLOCKED_REASON=%q
' "$policy_reason"
            } >> "$running"
            _queue_append_summary_to_job "$running" 78 "$log"
            mkdir -p "$root/pol_block"
            mv "$running" "$policy_blocked"
            _queue_job_stream_temp_cleanup "$id"
            _queue_log_event "pol_block" "$id" "$(_queue_job_name "$policy_blocked" 2>/dev/null || echo -)" "pol_block" "worker=$worker_id"
            echo "[worker $worker_id] pol_block $id"
            continue
        fi

        _queue_dispatch_trace_log "${worker_id:-${1:-?}}" "claim acquire start $id"
        if ! _queue_class_claim_job "$running" "$id"; then
            _queue_dispatch_trace_log "${worker_id:-${1:-?}}" "claim acquire failed $id"
            mv "$running" "$root/pending/$id.job" 2>/dev/null || true
            _queue_log_event "class_blocked" "$id" "$(_queue_job_name "$root/pending/$id.job" 2>/dev/null || echo "-")" "pending" "worker=$worker_id"
            continue
        fi
        _queue_dispatch_trace_log "${worker_id:-${1:-?}}" "claim acquire ok $id"

        _queue_dispatch_trace_log "${worker_id:-${1:-?}}" "about to run $id"
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
                runner_planned="$(_queue_runner_for_job "$runner_requested" "${CPU_LIMIT:-}" "${MEM_LIMIT:-}" "${RUN_USER:-}" || true)"
                _queue_apply_security_exception_overlays_for_current_job
                {
                    printf 'SANDBOX_LEVEL=%q\n' "${SANDBOX_LEVEL:-off}"
                    [[ -n "${RUNTIME_CAPS:-}" ]] && printf 'RUNTIME_CAPS=%q\n' "${RUNTIME_CAPS:-}"
                    [[ -n "${RUNTIME_CAP_PORTS:-}" ]] && printf 'RUNTIME_CAP_PORTS=%q\n' "${RUNTIME_CAP_PORTS:-}"
                    [[ -n "${SECCOMP_PROFILE:-}" ]] && printf 'SECCOMP_PROFILE=%q\n' "${SECCOMP_PROFILE:-}"
                    [[ -n "${SECCOMP_ALLOW:-}" ]] && printf 'SECCOMP_ALLOW=%q\n' "${SECCOMP_ALLOW:-}"
                } >> "$running"
                limit_status="$(_queue_limit_status_text "${CPU_LIMIT:-}" "${MEM_LIMIT:-}")"
                [[ "$runner_planned" == "systemd" ]] && limit_status="systemd-run-user-service-pipe"
                if [[ -n "${CPU_LIMIT:-}" || -n "${MEM_LIMIT:-}" ]]; then
                    echo "resource_limit_request: cpu=${CPU_LIMIT:-} mem=${MEM_LIMIT:-} runner=${runner_requested:-auto} planned=${runner_planned:-} status=$limit_status"
                    if [[ "$limit_status" != "systemd-run-user-service-pipe" ]]; then
                        echo "WARNING: resource limits were requested but are NOT enforced in this shell/session."
                    fi
                fi
                if [[ -n "${SANDBOX_LEVEL:-}" ]]; then
                    echo "sandbox_request: level=${SANDBOX_LEVEL:-} runner=${runner_planned:-}"
                fi
                if [[ -n "${TIMEOUT:-}" ]]; then
                    echo "timeout_request: timeout=${TIMEOUT:-} effective_timeout=${effective_timeout:-none} kill_after=${KILL_AFTER:-} billing_unit=${BILLING_UNIT_SECONDS:-} billing_cycles=${BILLING_CYCLES:-} billing_grace=${BILLING_GRACE_SECONDS:-} wrapper=coreutils-timeout"
                    if ! command -v timeout >/dev/null 2>&1; then
                        echo "WARNING: TIMEOUT requested but command 'timeout' is not available; payload launch will fail."
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
                effective_timeout="$(_queue_caps_effective_timeout_for_current_job 2>/dev/null || true)"
                mapfile -d '' payload_cmd < <(_queue_build_payload_command "${CPU_LIMIT:-}" "${MEM_LIMIT:-}" "${PWD_AT_SUBMIT:-$PWD}" "$runner_used" "${effective_timeout:-}" "${KILL_AFTER:-}" "${SANDBOX_LEVEL:-}" "${RUN_USER:-}" "${COMMAND[@]}")
                echo "systemd_user_bus: $(_queue_systemd_user_service_status_text)"
                if _queue_root_running_foreign_payload_user "${RUN_USER:-}"; then echo "foreign_run_user_runner_policy: root-foreign-user-auto-direct run_user=${RUN_USER:-}"; fi
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

                runtime_caps_watchdog_pid=""
                if [[ -n "${RUNTIME_CAPS:-}" ]]; then
                    _queue_log_worker_record "$use_stream_logger" "$log" "runtime_caps: ${RUNTIME_CAPS:-} interval=${RUNTIME_CAP_INTERVAL:-1} monitor=lsof/proc"
                    _queue_runtime_caps_watchdog "$running" "$log" "$cmd_pid" "$cmd_pgid" &
                    runtime_caps_watchdog_pid="$!"
                fi

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
                if [[ -n "${runtime_caps_watchdog_pid:-}" ]]; then
                    kill "$runtime_caps_watchdog_pid" >/dev/null 2>&1 || true
                    wait "$runtime_caps_watchdog_pid" >/dev/null 2>&1 || true
                fi
                if grep -q '^RUNTIME_CAP_VIOLATED=1$' "$running" 2>/dev/null; then
                    rc=96
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

# Legacy text QueueManager REPL removed in 0.16.14.

# -------------------------------------------------------------------
# Completion
# -------------------------------------------------------------------

_queue_complete() {
    COMPREPLY=()
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local commands="--dryrun -n submit submit-at submit-in list ls find show explain deps dependencies waiting blocked scheduled schedule tail stream follow class classes assets facilities claims resources pids pid ps metrics metric unit hooks hook onsuccess on-success onok on-ok onfailure on-failure onfail on-fail priority prio dynamic-prio pause hold unpause resume release cancel kill delete del rm remove undelete undel restore resubmit retry health stats events watch run start scheduled schedule compress-logs gzip-logs clean-logs cleanlogs log-clean logs-clean clear version --version -V backup reevaluate re-evaluate recheck policy-reevaluate help --help -h"

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
                COMPREPLY=( $(compgen -W "all pending running paused done failed pol_block policy_blocked interrupted cancelled deleted" -- "$cur") )
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




_queue_asset_hint_from_helper() {
    local facility="$1"
    local family helper
    family="${facility%%:*}"
    [[ -n "$family" && "$family" != "$facility" ]] || return 1

    helper="$(_queue_asset_helper_path "$family")"
    [[ -f "$helper" ]] || return 1

    (
        source "$helper" >/dev/null 2>&1 || exit 1

        local fac target params example notes desc

        # Preferred contract: helper publishes exact editor hints.
        if declare -F queue_asset_hints >/dev/null 2>&1; then
            while IFS=$'\t' read -r fac target params example notes; do
                [[ "$fac" == "$facility" ]] || continue
                echo "Facility: $fac"
                [[ -n "$target" ]] && echo "Target:   ${target#target=}"
                [[ -n "$params" ]] && echo "Params:   ${params#params=}"
                [[ -n "$example" ]] && { echo "Example:"; echo "  ${example#example=}"; }
                [[ -n "$notes" ]] && { echo "Notes:"; echo "  ${notes#notes=}"; }
                exit 0
            done < <(queue_asset_hints)
        fi

        # Compatibility fallback for existing installed helpers that have not
        # been refreshed since queue_asset_hints was introduced.
        if declare -F queue_asset_facilities >/dev/null 2>&1; then
            while IFS= read -r line; do
                fac="${line%%[[:space:]]*}"
                [[ "$fac" == "$facility" ]] || continue
                desc="${line#"$fac"}"
                desc="${desc#"${desc%%[![:space:]]*}"}"

                echo "Facility: $fac"
                echo "Target:   see helper/plugin documentation"
                echo "Params:   key=value parameters depend on this helper"
                echo "Example:"
                echo "  queue_class_shared_asset ${fac%%:*} ${fac#*:} \"TARGET\" key=value"
                [[ -n "$desc" ]] && { echo "Notes:"; echo "  $desc"; }
                exit 0
            done < <(queue_asset_facilities)
        fi

        exit 3
    )
}

_queue_asset_hints_from_helpers() {
    local root="$(_queue_root)"
    local helper
    shopt -s nullglob
    for helper in "$root/assets.d"/*.sh; do
        [[ -f "$helper" ]] || continue
        (
            source "$helper" >/dev/null 2>&1 || exit 0

            if declare -F queue_asset_hints >/dev/null 2>&1; then
                queue_asset_hints
                exit 0
            fi

            # Compatibility fallback: synthesize minimal hint records from
            # published facilities. This keeps QueueManager useful even when
            # local helper files pre-date the hint contract.
            if declare -F queue_asset_facilities >/dev/null 2>&1; then
                local line fac desc family check
                while IFS= read -r line; do
                    fac="${line%%[[:space:]]*}"
                    [[ "$fac" == *:* ]] || continue
                    desc="${line#"$fac"}"
                    desc="${desc#"${desc%%[![:space:]]*}"}"
                    family="${fac%%:*}"
                    check="${fac#*:}"
                    printf '%s\ttarget=%s\tparams=%s\texample=%s\tnotes=%s\n' \
                        "$fac" \
                        "see helper/plugin documentation" \
                        "key=value parameters depend on this helper" \
                        "queue_class_shared_asset $family $check \"TARGET\" key=value" \
                        "$desc"
                done < <(queue_asset_facilities)
            fi
        )
    done
    shopt -u nullglob
}

_queue_asset_hints_print() {
    local facility="${1:-}"
    if [[ -n "$facility" ]]; then
        if _queue_asset_hint_from_helper "$facility"; then
            return 0
        fi
        echo "No published helper hint for: $facility"
        return 1
    fi

    _queue_asset_hints_from_helpers | awk -F '\t' '
        NF > 0 && $1 != "" {
            printf "%-28s", $1
            for (i=2; i<=NF; i++) {
                if ($i ~ /^target=/) {
                    v=$i; sub(/^target=/, "", v); printf " target=%s", v
                }
            }
            printf "\n"
        }
    ' | sort -u
}



_queue_assets_completion_words() {
    printf '%s\n' "list show validate duplicates dupes replace rollback backups refresh delete archive undelete unarchive enable disable archives explain expand"
}

# Shell-side class wizard helper functions.
#
# The Python QueueManager Class Creator is the primary interactive class editor,
# but these helpers remain as a stable, source-able shell contract for tests,
# fallback tooling, and non-curses environments.  They deliberately only publish
# data and render record-format class text; they do not run the old legacy
# QueueManager menu.
_queue_mgr_list_facilities_compact() {
    local root helper src_dir
    local -a dirs=()

    # Test harnesses can point QUEUEBASH_PLUGIN_SOURCE_DIR at a fixture tree.
    if [[ -n "${QUEUEBASH_PLUGIN_SOURCE_DIR:-}" ]]; then
        dirs+=("$QUEUEBASH_PLUGIN_SOURCE_DIR/assets.d")
        dirs+=("$QUEUEBASH_PLUGIN_SOURCE_DIR")
    fi

    root="$(_queue_root 2>/dev/null || printf '%s' "${QUEUEBASH_ROOT:-$HOME/.queuebash}")"
    dirs+=("$root/assets.d")
    dirs+=("${BASH_SOURCE[0]%/*}/assets.d")

    (
        shopt -s nullglob
        local seen_dir=""
        for src_dir in "${dirs[@]}"; do
            [[ -d "$src_dir" ]] || continue
            case ":$seen_dir:" in *:"$src_dir":*) continue ;; esac
            seen_dir="$seen_dir:$src_dir"

            for helper in "$src_dir"/*.sh; do
                [[ -f "$helper" ]] || continue
                (
                    source "$helper" >/dev/null 2>&1 || exit 0
                    if declare -F queue_asset_facilities >/dev/null 2>&1; then
                        queue_asset_facilities | awk '{print $1}'
                    fi
                )
            done
        done
    ) | awk 'NF && $1 ~ /^[A-Za-z_][A-Za-z0-9_]*:[A-Za-z_][A-Za-z0-9_]*$/ { print $1 }' | sort -u
}

_queue_mgr_facility_family() {
    local facility="${1:-}"
    [[ "$facility" == *:* ]] || return 1
    printf '%s\n' "${facility%%:*}"
}

_queue_mgr_facility_check() {
    local facility="${1:-}"
    [[ "$facility" == *:* ]] || return 1
    printf '%s\n' "${facility#*:}"
}

_queue_mgr_wizard_render_preview() {
    local class_name="${1:-}"
    local allow_parallel="${2:-1}"
    local max_concurrent="${3:-0}"
    local defaults_file="${4:-}"
    shift 4 2>/dev/null || true

    [[ -n "$class_name" ]] || { echo "class wizard: class name required" >&2; return 2; }
    _queue_class_valid_name "$class_name" || { echo "class wizard: invalid class name: $class_name" >&2; return 2; }
    [[ "$allow_parallel" =~ ^[01]$ ]] || { echo "class wizard: CLASS_ALLOW_PARALLEL must be 0 or 1" >&2; return 2; }
    [[ "$max_concurrent" =~ ^[0-9]+$ ]] || { echo "class wizard: CLASS_MAX_CONCURRENT must be numeric" >&2; return 2; }

    printf '# bashqueues class: %s\n' "$class_name"
    printf '#\n'
    printf '# Generated by queue mgr class wizard helpers.\n'
    printf '#\n'
    printf 'CLASS_ALLOW_PARALLEL=%s\n' "$allow_parallel"
    printf 'CLASS_MAX_CONCURRENT=%s\n' "$max_concurrent"

    if [[ -n "$defaults_file" && -f "$defaults_file" ]]; then
        local line
        while IFS= read -r line || [[ -n "$line" ]]; do
            case "$line" in
                ''|'#'*) continue ;;
                CLASS_DEFAULT_*=*) printf '%s\n' "$line" ;;
            esac
        done < "$defaults_file"
    fi

    if [[ "$#" -gt 0 ]]; then
        printf '\n'
        local record
        for record in "$@"; do
            [[ -n "$record" ]] || continue
            printf '%s\n' "$record"
        done
    fi
}


complete -F _queue_complete queue


# Compatibility wrapper: bare `queuemgr` now routes through the panel-only QueueManager entry.
queuemgr() {
    queue mgr "$@"
}

_queuemgr_complete() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        --state|-s)
            COMPREPLY=( $(compgen -W "all pending running paused done failed pol_block policy_blocked interrupted cancelled deleted" -- "$cur") )
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
