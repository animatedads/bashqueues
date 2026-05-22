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
    mkdir -p "$root"/{pending,running,paused,done,failed,cancelled,deleted,logs}
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
    for state in pending running paused done failed cancelled deleted; do
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

    for state in pending running paused done failed cancelled deleted; do
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

_queue_next_job() {
    local root="$(_queue_root)"
    local best=""
    local best_pri="-999999"
    local best_id=""
    local f id pri

    for f in "$root/pending"/*.job; do
        [[ -e "$f" ]] || continue

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
    local root="$(_queue_root)"
    local log="$root/logs/$id.log"

    if [[ ! -f "$log" ]]; then
        echo "queue tail: no log yet for $id ($f)" >&2
        return 1
    fi

    echo "=== tailing: $log ==="
    tail -f "$log"
}

_queue_help() {
    cat <<'EOF'
Usage:
  queue [--dryrun] <command...>
  queue submit <name> [--dryrun] [--priority N|-p N] [--on-success <cmd...>] [--on-failure <cmd...>] -- <command...>

  queue list [--state all|pending|running|paused|done|failed|cancelled|deleted] [--name TEXT] [--filter TEXT]
  queue ls   [--state all|pending|running|paused|done|failed|cancelled|deleted] [--name TEXT] [--filter TEXT]
  queue find <text>
  queue show <qid|exact-job-name>
  queue tail <qid|exact-job-name>
  queue pids <qid|exact-job-name>
  queue hooks <qid|exact-job-name>

  queue onsuccess <qid|exact-job-name> -- <command...>
  queue on-success <qid|exact-job-name> -- <command...>
  queue onok <qid|exact-job-name> -- <command...>
  queue onfailure <qid|exact-job-name> -- <command...>
  queue on-failure <qid|exact-job-name> -- <command...>
  queue onfail <qid|exact-job-name> -- <command...>

  queue priority <qid|exact-job-name> <priority> [--force] [--dryrun]
  queue prio     <qid|exact-job-name> <priority> [--force]

  queue pause   <qid|exact-job-name> [--force] [--dryrun]
  queue unpause <qid|exact-job-name> [--dryrun]
  queue resume  <qid|exact-job-name> [--dryrun]
  queue release <qid|exact-job-name> [--dryrun]

  queue delete   <qid|exact-job-name> [--force] [--dryrun]
  queue rm       <qid|exact-job-name> [--force] [--dryrun]
  queue undelete <qid|exact-job-name> [pending|done|failed] [--force] [--dryrun]

  queue stats [--name exact-job-name] [--today]
  queue events [--tail N]

  queue run [--workers N] [--dryrun]

  queue clear done [--dryrun]
  queue clear failed [--dryrun]
  queue clear paused [--dryrun]
  queue clear deleted [--dryrun]
  queue clear all [--dryrun]

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

Structured audit:
  State transitions and operator actions append JSONL records to ~/.queuebash/events.jsonl.
  queue stats summarizes queue states; queue events shows recent audit records.

States:
  pending   waiting to run
  running   currently claimed by a worker
  paused    held; workers will not run it
  done      completed successfully
  failed    completed with non-zero exit
  cancelled operator cancelled or killed
  deleted   marked deleted; can be undeleted

Priority:
  Higher number runs first.
  Suggested: 100 urgent, 50 high, 10 normal/default, 0 low.
  Exact job name updates all jobs with that exact name.

Dry run:
  queue --dryrun <command...> previews a mutating action without changing files.
  Most mutating commands also accept --dryrun after the command or at the end.

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
    r     run one worker
    rd    dryrun one worker
    r4    run four workers
    rd4   dryrun four workers

Notes:
  Jobs are stored in ~/.queuebash by default.
  Set QUEUEBASH_ROOT=/some/path to use another queue root.

  For shell syntax in hooks, use bash -c:
    queue onsuccess myjob -- bash -c 'echo complete && date'
EOF
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
        help|--help|-h|"")
            _queue_help
            ;;

        submit)
            local priority=10
            local local_dryrun="$dryrun"
            local name="$1"
            shift || true

            if [[ -z "$name" ]]; then
                echo "Usage: queue submit <name> [--priority N|-p N] [--on-success <cmd...>] [--on-failure <cmd...>] -- <command...>" >&2
                return 2
            fi

            local on_success=()
            local on_failure=()

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
                    --on-success)
                        shift
                        on_success=()
                        while [[ "$#" -gt 0 && "$1" != "--on-failure" && "$1" != "--priority" && "$1" != "-p" && "$1" != "--" ]]; do
                            on_success+=( "$1" )
                            shift
                        done
                        ;;
                    --on-failure)
                        shift
                        on_failure=()
                        while [[ "$#" -gt 0 && "$1" != "--on-success" && "$1" != "--priority" && "$1" != "-p" && "$1" != "--" ]]; do
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
                        echo "Usage: queue submit <name> [--priority N|-p N] [--on-success <cmd...>] [--on-failure <cmd...>] -- <command...>" >&2
                        return 2
                        ;;
                esac
            done

            [[ "$#" -eq 0 ]] && { echo "queue submit: missing main command" >&2; return 2; }
            [[ "$priority" =~ ^-?[0-9]+$ ]] || priority=10

            local id="$(_queue_id)"
            local job="$root/pending/$id.job"

            if [[ "$local_dryrun" -eq 1 ]]; then
                echo "DRYRUN: would submit job:"
                echo "  id:       $id"
                echo "  name:     $name"
                echo "  priority: $priority"
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
                return 0
            fi

            {
                printf 'JOB_ID=%q\n' "$id"
                printf 'JOB_NAME=%q\n' "$name"
                printf 'PRIORITY=%q\n' "$priority"
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
            } > "$job"

            echo "Submitted $id : $name priority=$priority"
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
            ;;

        list|ls)
            local filter_state="all"
            local filter_name=""
            local filter_text=""

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

            printf "%-24s %-10s %-8s %-20s %-4s %-4s %s\n" "JOB_ID" "STATE" "PRI" "NAME" "OK" "FAIL" "COMMAND"

            local state f id name pri line ok fail
            for state in pending running paused done failed cancelled deleted; do
                [[ "$filter_state" != "all" && "$filter_state" != "$state" ]] && continue

                for f in "$root/$state"/*.job; do
                    [[ -e "$f" ]] || continue

                    id="$(basename "$f" .job)"
                    name="$(_queue_job_name "$f")"
                    pri="$(_queue_job_pri "$f")"
                    line="$(grep '^COMMAND=' "$f" | sed 's/^COMMAND=( //; s/ )$//')"

                    [[ -n "$filter_name" && "$name" != *"$filter_name"* ]] && continue
                    [[ -n "$filter_text" && "$id $state $pri $name $line" != *"$filter_text"* ]] && continue

                    ok="-"
                    fail="-"
                    if _queue_job_has_array "$f" ON_SUCCESS; then ok="Y"; fi
                    if _queue_job_has_array "$f" ON_FAILURE; then fail="Y"; fi

                    printf "%-24s %-10s %-8s %-20s %-4s %-4s %s\n" "$id" "$state" "$pri" "$name" "$ok" "$fail" "$line"
                done
            done
            ;;

        find)
            local text="$1"
            [[ -z "$text" ]] && { echo "Usage: queue find <text>" >&2; return 2; }
            queue list --filter "$text"
            ;;

        show)
            local target="$1"
            [[ -z "$target" ]] && { echo "Usage: queue show <qid-or-exact-job-name>" >&2; return 2; }

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
                echo "matches:" >&2
                _queue_print_matches "${matches[@]}"
                echo "Use a fuller QID or an exact job name." >&2
                return 2
            fi

            local shown=0
            local id state
            for f in "${matches[@]}"; do
                id="$(basename "$f" .job)"
                state="$(basename "$(dirname "$f")")"
                echo "=============================================================================="
                echo "JOB: $id   STATE: $state"
                echo "=============================================================================="
                echo "=== $f ==="
                cat "$f"
                echo

                if [[ -f "$root/logs/$id.log" ]]; then
                    echo "=== log: $root/logs/$id.log ==="
                    tail -200 "$root/logs/$id.log"
                else
                    echo "=== log ==="
                    echo "(no log found)"
                fi
                echo
                shown=$((shown + 1))
            done

            echo "Shown $shown job(s)."
            ;;



        tail|follow)
            local target="$1"
            [[ -z "$target" ]] && { echo "Usage: queue tail <qid-or-exact-job-name>" >&2; return 2; }

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
            _queue_tail_log_for_job "$chosen" "$id"
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
            for state in pending running paused done failed cancelled deleted; do
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
            for f in "${matches[@]}"; do
                echo "=============================================================================="
                _queue_pid_report_for_job "$f"
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

        priority|prio)
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
                local id state dest run_pid run_pgid name self_pgid signal_target
                id="$(basename "$f" .job)"
                state="$(_queue_job_file_state "$f")"
                name="$(_queue_job_name "$f")"
                dest="$root/cancelled/$id.job"
                run_pid="$(grep '^RUN_PID=' "$f" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
                run_pgid="$(grep '^RUN_PGID=' "$f" 2>/dev/null | tail -1 | cut -d= -f2- | xargs printf '%s' 2>/dev/null)"
                self_pgid="$(ps -o pgid= -p $$ 2>/dev/null | tr -d '[:space:]')"

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
                        echo "DRYRUN: would signal $sig to job $id ($name), target=${signal_target:-none}, RUN_PID=$run_pid RUN_PGID=$run_pgid, then move running -> cancelled"
                    else
                        echo "DRYRUN: would move $id ($name) from $state -> cancelled without signalling"
                    fi
                    moved=$((moved + 1))
                    continue
                fi

                if [[ "$state" == "running" ]]; then
                    if [[ -n "$signal_target" ]]; then
                        echo "Sending -$sig to $signal_target for $id ($name)"
                        kill "-$sig" "$signal_target" 2>/dev/null || true
                    else
                        echo "queue $cmd: running job $id has no safe RUN_PID/RUN_PGID target; moving record only" >&2
                    fi
                fi

                {
                    echo "CANCELLED_AT=$(printf '%q' "$(date -Is)")"
                    echo "CANCELLED_FROM=$(printf '%q' "$state")"
                    echo "CANCEL_SIGNAL=$(printf '%q' "$sig")"
                } >> "$f"

                mv -f "$f" "$dest"
                _queue_log_event "cancelled" "$id" "$name" "cancelled" "from=$state signal=$sig pid=$run_pid pgid=$run_pgid"
                echo "Moved $id from $state -> cancelled"
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

            [[ "${#matches[@]}" -eq 0 ]] && { echo "queue undelete: no matching deleted job: $target" >&2; return 1; }

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
                [[ "$state" == "failed" ]] && matches+=( "$f" )
            done < <(_queue_find_jobs "$target")

            if [[ "${#all_matches[@]}" -eq 0 ]]; then
                echo "queue resubmit: no matching QID or exact job name: $target" >&2
                return 1
            fi

            if [[ "${#matches[@]}" -eq 0 ]]; then
                echo "queue resubmit: matching job(s) found, but none are in failed state:" >&2
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
                    echo "DRYRUN: would resubmit failed job:"
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
                echo "DRYRUN: would resubmit $count failed job(s)."
            else
                echo "Resubmitted $count failed job(s)."
            fi
            ;;


        run)
            local local_dryrun="$dryrun"
            local workers=1
            if [[ "${1:-}" == "--workers" ]]; then
                workers="$2"
                shift 2
            fi
            [[ "${1:-}" == "--dryrun" || "${1:-}" == "-n" ]] && local_dryrun=1

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

            echo "Running queue with $workers worker(s)"
            local i
            for ((i=1; i<=workers; i++)); do
                (_queue_worker "$i") &
            done
            wait
            ;;

        clear)
            local what="${1:-}"
            local local_dryrun="$dryrun"
            [[ "${2:-}" == "--dryrun" || "${2:-}" == "-n" ]] && local_dryrun=1
            case "$what" in
                done|failed|paused|cancelled|deleted)
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
                *) echo "Usage: queue clear done|failed|paused|cancelled|deleted|all [--dryrun]" >&2; return 2 ;;
            esac
            ;;

        *)
            echo "Unknown queue command: $cmd" >&2
            _queue_help
            return 2
            ;;
    esac
}

_queue_worker() {
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
        local log="$root/logs/$id.log"

        if ! mv "$job" "$running" 2>/dev/null; then
            continue
        fi

        echo "[worker $worker_id] running $id"
        _queue_log_event "started" "$id" "$(_queue_job_name "$running")" "running" "worker=$worker_id"

        (
            source "$running"
            cd "$PWD_AT_SUBMIT" || exit 98

            {
                echo "=== queue job $JOB_ID : $JOB_NAME ==="
                echo "started: $(date -Is)"
                echo "pwd: $PWD"
                printf "command:"
                printf " %q" "${COMMAND[@]}"
                echo
                echo

                if command -v setsid >/dev/null 2>&1; then
                    setsid -- "${COMMAND[@]}" &
                else
                    "${COMMAND[@]}" &
                fi
                cmd_pid="$!"

                cmd_pgid="$(ps -o pgid= -p "$cmd_pid" 2>/dev/null | tr -d '[:space:]')"
                {
                    printf 'RUN_PID=%q\n' "$cmd_pid"
                    printf 'RUN_PGID=%q\n' "$cmd_pgid"
                    printf 'RUN_STARTED_AT=%q\n' "$(date -Is)"
                } >> "$running"

                echo "run_pid: $cmd_pid"
                echo "run_pgid: $cmd_pgid"
                _queue_log_event "pid_recorded" "$JOB_ID" "$JOB_NAME" "running" "pid=$cmd_pid pgid=$cmd_pgid"

                wait "$cmd_pid"
                rc="$?"

                echo
                echo "finished: $(date -Is)"
                echo "exit_code: $rc"

                exit "$rc"
            } > "$log" 2>&1
        )

        local rc="$?"

        if [[ "$rc" -eq 0 ]]; then
            if [[ -f "$running" ]]; then
                mv "$running" "$done"
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
            else
                echo "[worker $worker_id] done $id but queue record was moved externally"
            fi
        else
            if [[ -f "$running" ]]; then
                mv "$running" "$failed"
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
            else
                echo "[worker $worker_id] failed $id rc=$rc but queue record was moved externally"
            fi
        fi
    done
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
        echo "Commands:"
        echo "  r             run one worker"
        echo "  rd            dryrun one worker"
        echo "  r4            run four workers"
        echo "  rd4           dryrun four workers"
        echo "  s <id|name>   show job/log; exact name shows all matching jobs"
        echo "  t <id|name>   tail job log"
        echo "  pid <id|name> show recorded PID/process tree"
        echo "  p <id|name> <priority>  set priority; exact name updates all matching jobs"
        echo "  pause <id|name>  pause pending job"
        echo "  pd <id|name>     dryrun pause"
        echo "  unp <id|name>    unpause job to pending"
        echo "  unpd <id|name>   dryrun unpause"
        echo "  os <id|name>     show success/failure hooks"
        echo "  ok <id|name> -- <cmd>    set on-success hook"
        echo "  fail <id|name> -- <cmd>  set on-failure hook"
        echo "  c <id|name>      cancel job into cancelled state"
        echo "  kd <id|name>     kill job/process group into cancelled state"
        echo "  d <id|name>      mark job as deleted"
        echo "  dd <id|name>     dryrun delete"
        echo "  df <id|name>     force delete ambiguous/running jobs"
        echo "  u <id|name>      undelete matching deleted job to pending"
        echo "  ud <id|name>     dryrun undelete"
        echo "  rs <id|name>     resubmit failed job(s)"
        echo "  rsd <id|name>    dryrun resubmit failed job(s)"
        echo "  uf <id|name>     force undelete ambiguous QID-prefix matches"
        echo "  cdel             clear deleted jobs"
        echo "  stat             queue statistics"
        echo "  ev               recent JSONL events"
        echo "  f <text>         set text filter"
        echo "  n <text>         set job-name filter"
        echo "  st <state>       set state filter: all|pending|running|paused|done|failed|cancelled|deleted"
        echo "  a                clear filters"
        echo "  cd               clear done"
        echo "  cf               clear failed"
        echo "  q                quit"
        echo

        local cmd arg extra rest
        read -r -p "queuemgr> " cmd arg extra rest

        case "$cmd" in
            q|quit|exit) break ;;
            r) queue run; read -r -p "press enter..." ;;
            rd) queue --dryrun run; read -r -p "press enter..." ;;
            rd[0-9]*) queue --dryrun run --workers "${cmd#rd}"; read -r -p "press enter..." ;;
            r[0-9]*) queue run --workers "${cmd#r}"; read -r -p "press enter..." ;;
            s|show) queue show "$arg"; read -r -p "press enter..." ;;
            t|tail|follow) queue tail "$arg"; read -r -p "press enter..." ;;
            pid|pids|ps) queue pids "$arg"; read -r -p "press enter..." ;;
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
            cdel|clear-deleted) queue clear deleted; read -r -p "press enter..." ;;
            stat|stats) queue stats; read -r -p "press enter..." ;;
            ev|events) queue events --tail "${arg:-20}"; read -r -p "press enter..." ;;
            f|filter) filter_text="$arg" ;;
            n|name) filter_name="$arg" ;;
            st|state) filter_state="${arg:-all}" ;;
            a|all) filter_text=""; filter_name=""; filter_state="all" ;;
            cd) queue clear done; read -r -p "press enter..." ;;
            cf) queue clear failed; read -r -p "press enter..." ;;
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

    local commands="--dryrun -n submit list ls find show tail follow pids pid ps hooks hook onsuccess on-success onok on-ok onfailure on-failure onfail on-fail priority prio pause hold unpause resume release cancel kill delete del rm remove undelete undel restore resubmit retry stats events run clear help --help -h"

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
            COMPREPLY=( $(compgen -W "--dryrun -n --priority -p --on-success --on-failure --" -- "$cur") )
            COMPREPLY+=( $(compgen -c -- "$cur") )
            COMPREPLY+=( $(compgen -f -- "$cur") )
            return 0
            ;;

        list|ls)
            if [[ "$prev" == "--state" || "$prev" == "-s" ]]; then
                COMPREPLY=( $(compgen -W "all pending running paused done failed cancelled deleted" -- "$cur") )
                return 0
            fi
            COMPREPLY=( $(compgen -W "--state -s --name -n --filter -f" -- "$cur") )
            COMPREPLY+=( $(compgen -W "$(_queue_job_id_and_names_for_completion)" -- "$cur") )
            return 0
            ;;

        show|tail|follow|pids|pid|ps|hooks|hook|pause|hold|unpause|resume|release|cancel|kill|delete|del|rm|remove|undelete|undel|restore|resubmit|retry)
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

        priority|prio)
            if [[ "$COMP_CWORD" -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "$(_queue_job_id_and_names_for_completion)" -- "$cur") )
                return 0
            fi
            if [[ "$COMP_CWORD" -eq 3 ]]; then
                COMPREPLY=( $(compgen -W "0 1 5 10 25 50 75 100 200" -- "$cur") )
                return 0
            fi
            ;;

        run)
            if [[ "$COMP_CWORD" -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "--workers --dryrun -n" -- "$cur") )
                return 0
            fi
            if [[ "$prev" == "--workers" ]]; then
                COMPREPLY=( $(compgen -W "1 2 3 4 5 6 7 8 12 16" -- "$cur") )
                return 0
            fi
            ;;

        clear)
            COMPREPLY=( $(compgen -W "done failed paused cancelled deleted all --dryrun -n" -- "$cur") )
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
            COMPREPLY=( $(compgen -W "all pending running paused done failed cancelled deleted" -- "$cur") )
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
