#!/usr/bin/env bash
# bashqueues asset plugin: version-control system checks
#
# Purpose:
#   Neutral VCS tenant checks for Git, Subversion, CVS, Mercurial, and
#   Perforce workspaces. Existing git:* checks remain first-class and are not
#   replaced; this plugin gives legacy/enterprise systems the same class-asset
#   shape for queue admission.

queue_asset_facilities() {
    cat <<'FACILITIES'
vcs:branch	Check the current branch/tag/stream/client marker for a VCS workspace
vcs:identity	Check the normalised VCS identity reported by queue-vcs-probe
vcs:revision	Check the current revision/changelist/hash reported by the VCS client
vcs:clean_tree	Check that a VCS workspace has no pending local changes
vcs:repo_exists	Check that a directory is a recognised VCS workspace
vcs:tool_available	Check that the command-line client for a VCS type is installed
FACILITIES
}

queue_asset_hints() {
    cat <<'HINTS'
vcs:repo_exists	target=working-copy directory	params=type=auto|git|svn|cvs|hg|p4 timeout=10	example=queue_class_shared_asset vcs repo_exists "/srv/legacy/src" type=svn	notes=Passes when the target is a recognised working copy. type=auto detects .git/.svn/CVS/.hg/P4CONFIG metadata.
vcs:clean_tree	target=working-copy directory	params=type=auto|git|svn|cvs|hg|p4 timeout=10	example=queue_class_shared_asset vcs clean_tree "/srv/legacy/src" type=cvs timeout=20	notes=Blocks when the VCS client reports pending edits, adds, deletes, conflicts, or unknown files.
vcs:branch	target=working-copy directory	params=type=auto require_branch=main require_tag=RELEASE require_url_contains=/trunk require_stream=//depot/main require_client=build-client timeout=10	example=queue_class_shared_asset vcs branch "/srv/legacy/src" type=svn require_url_contains=/branches/release	notes=Maps branch-like identity across systems: Git/Hg branch, SVN URL fragment, CVS sticky tag, and Perforce stream/client.
vcs:identity	target=working-copy directory	params=type=auto require_identity=main timeout=10	example=queue_class_shared_asset vcs identity "/srv/legacy/src" type=auto require_identity=HEAD	notes=Uses queue-vcs-probe to normalise branch/tag/stream/client identity without mutating the checkout.
vcs:revision	target=working-copy directory	params=type=auto require_revision=abc123 timeout=10	example=queue_class_shared_asset vcs revision "/srv/legacy/src" type=svn require_revision=18422	notes=Checks the currently observed hash, revision, root marker, or changelist for reproducible release and audit gates.
vcs:tool_available	target=vcs type or command	params=type=git|svn|cvs|hg|p4	example=queue_class_shared_asset vcs tool_available svn type=svn	notes=Passes when the needed VCS client binary is available.
HINTS
}

queue_asset_param() {
    local key="$1"
    shift || true
    local p
    for p in "$@"; do
        case "$p" in
            "$key="*) printf '%s\n' "${p#*=}"; return 0 ;;
        esac
    done
    return 1
}

_vcs_type_command() {
    case "$1" in
        git) printf '%s\n' git ;;
        svn|subversion) printf '%s\n' svn ;;
        cvs) printf '%s\n' cvs ;;
        hg|mercurial) printf '%s\n' hg ;;
        p4|perforce) printf '%s\n' p4 ;;
        *) return 1 ;;
    esac
}

_vcs_normal_type() {
    case "$1" in
        '') printf '%s\n' auto ;;
        subversion) printf '%s\n' svn ;;
        mercurial) printf '%s\n' hg ;;
        perforce) printf '%s\n' p4 ;;
        git|svn|cvs|hg|p4|auto) printf '%s\n' "$1" ;;
        *) return 1 ;;
    esac
}

_vcs_tool_missing() {
    echo "asset_check_blocked: vcs:$1 tool_missing=$2"
    return 1
}

_vcs_need_tool() {
    local facility="$1" type="$2" cmd
    cmd="$(_vcs_type_command "$type" || true)"
    [[ -n "$cmd" ]] || { echo "asset_check_blocked: vcs:$facility unknown_type=$type"; return 1; }
    command -v "$cmd" >/dev/null 2>&1 || _vcs_tool_missing "$facility" "$cmd"
}

_vcs_find_up() {
    local dir="$1" marker="$2"
    while [[ -n "$dir" && "$dir" != / ]]; do
        [[ -e "$dir/$marker" ]] && { printf '%s\n' "$dir/$marker"; return 0; }
        dir="${dir%/*}"
        [[ -z "$dir" ]] && dir=/
    done
    return 1
}

_vcs_detect_type() {
    local dir="$1"
    [[ -d "$dir" ]] || return 1
    if _vcs_find_up "$dir" .git >/dev/null 2>&1; then echo git; return 0; fi
    if _vcs_find_up "$dir" .svn >/dev/null 2>&1; then echo svn; return 0; fi
    if _vcs_find_up "$dir" CVS >/dev/null 2>&1; then echo cvs; return 0; fi
    if _vcs_find_up "$dir" .hg >/dev/null 2>&1; then echo hg; return 0; fi
    if _vcs_find_up "$dir" .p4config >/dev/null 2>&1 || [[ -n "${P4CONFIG:-}" && -e "$dir/${P4CONFIG}" ]]; then echo p4; return 0; fi
    return 1
}

_vcs_type_for_target() {
    local target="$1"
    shift || true
    local type
    type="$(_vcs_normal_type "$(queue_asset_param type "$@" || echo auto)" || true)"
    [[ -n "$type" ]] || { echo "asset_check_blocked: vcs unknown_type=$(queue_asset_param type "$@" || true)"; return 1; }
    if [[ "$type" == auto ]]; then
        type="$(_vcs_detect_type "$target" || true)"
        [[ -n "$type" ]] || { echo "asset_check_blocked: vcs:repo_exists unable_to_detect_vcs target=$target"; return 1; }
    fi
    printf '%s\n' "$type"
}

_vcs_timeout() { queue_asset_param timeout "$@" || echo 10; }

queue_asset_check_vcs_tool_available() {
    local token="$1" target="${2:-}"
    shift 2 || true
    local type cmd
    type="$(_vcs_normal_type "$(queue_asset_param type "$@" || echo "$target")" || true)"
    [[ -n "$type" && "$type" != auto ]] || { echo "asset_check_blocked: vcs:tool_available requires type=git|svn|cvs|hg|p4"; return 1; }
    cmd="$(_vcs_type_command "$type" || true)"
    [[ -n "$cmd" ]] || { echo "asset_check_blocked: vcs:tool_available unknown_type=$type"; return 1; }
    command -v "$cmd" >/dev/null 2>&1 || _vcs_tool_missing tool_available "$cmd"
    echo "asset_check_ok: $token"
}

queue_asset_check_vcs_repo_exists() {
    local token="$1" target="$2"
    shift 2 || true
    [[ -d "$target" ]] || { echo "asset_check_blocked: vcs:repo_exists target is not a directory: $target"; return 1; }
    local type
    type="$(_vcs_type_for_target "$target" "$@")" || return 1
    case "$type" in
        git)
            _vcs_need_tool repo_exists git || return 1
            git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "asset_check_blocked: vcs:repo_exists not a git repository: $target"; return 1; }
            ;;
        svn)
            if command -v svn >/dev/null 2>&1; then
                timeout "$(_vcs_timeout "$@")" svn info "$target" >/dev/null 2>&1 || { echo "asset_check_blocked: vcs:repo_exists not a svn working copy: $target"; return 1; }
            else
                _vcs_find_up "$target" .svn >/dev/null 2>&1 || _vcs_tool_missing repo_exists svn || return 1
            fi
            ;;
        cvs)
            _vcs_find_up "$target" CVS >/dev/null 2>&1 || { echo "asset_check_blocked: vcs:repo_exists not a cvs working copy: $target"; return 1; }
            ;;
        hg)
            _vcs_need_tool repo_exists hg || return 1
            hg --cwd "$target" root >/dev/null 2>&1 || { echo "asset_check_blocked: vcs:repo_exists not a hg repository: $target"; return 1; }
            ;;
        p4)
            _vcs_need_tool repo_exists p4 || return 1
            (cd "$target" 2>/dev/null && timeout "$(_vcs_timeout "$@")" p4 client -o >/dev/null 2>&1) || { echo "asset_check_blocked: vcs:repo_exists not a p4 client workspace: $target"; return 1; }
            ;;
    esac
    echo "asset_check_ok: $token"
}

queue_asset_check_vcs_clean_tree() {
    local token="$1" target="$2"
    shift 2 || true
    [[ -d "$target" ]] || { echo "asset_check_blocked: vcs:clean_tree target is not a directory: $target"; return 1; }
    local type out
    type="$(_vcs_type_for_target "$target" "$@")" || return 1
    case "$type" in
        git)
            _vcs_need_tool clean_tree git || return 1
            git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "asset_check_blocked: vcs:clean_tree not a git repository: $target"; return 1; }
            out="$(git -C "$target" status --porcelain 2>/dev/null)"
            ;;
        svn)
            _vcs_need_tool clean_tree svn || return 1
            out="$(timeout "$(_vcs_timeout "$@")" svn status "$target" 2>/dev/null || true)"
            ;;
        cvs)
            _vcs_need_tool clean_tree cvs || return 1
            out="$(cd "$target" 2>/dev/null && timeout "$(_vcs_timeout "$@")" cvs -n update -dP 2>/dev/null || true)"
            out="$(printf '%s\n' "$out" | grep -E '^[?MARCDUP] ' || true)"
            ;;
        hg)
            _vcs_need_tool clean_tree hg || return 1
            out="$(hg --cwd "$target" status 2>/dev/null || true)"
            ;;
        p4)
            _vcs_need_tool clean_tree p4 || return 1
            out="$(cd "$target" 2>/dev/null && timeout "$(_vcs_timeout "$@")" p4 opened 2>/dev/null || true)"
            ;;
    esac
    if [[ -z "$out" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: vcs:clean_tree type=$type pending_changes target=$target"
    return 1
}

_vcs_cvs_sticky_tag() {
    local tagfile
    tagfile="$(_vcs_find_up "$1" CVS/Tag 2>/dev/null || true)"
    [[ -n "$tagfile" && -r "$tagfile" ]] || return 1
    sed -n '1s/^T//p' "$tagfile"
}

queue_asset_check_vcs_branch() {
    local token="$1" target="$2"
    shift 2 || true
    [[ -d "$target" ]] || { echo "asset_check_blocked: vcs:branch target is not a directory: $target"; return 1; }
    local type required current url
    type="$(_vcs_type_for_target "$target" "$@")" || return 1
    case "$type" in
        git)
            required="$(queue_asset_param require_branch "$@" || true)"
            [[ -n "$required" ]] || { echo "asset_check_blocked: vcs:branch git requires require_branch="; return 1; }
            _vcs_need_tool branch git || return 1
            current="$(git -C "$target" rev-parse --abbrev-ref HEAD 2>/dev/null)"
            ;;
        svn)
            required="$(queue_asset_param require_url_contains "$@" || queue_asset_param require_branch "$@" || true)"
            [[ -n "$required" ]] || { echo "asset_check_blocked: vcs:branch svn requires require_url_contains= or require_branch="; return 1; }
            _vcs_need_tool branch svn || return 1
            url="$(timeout "$(_vcs_timeout "$@")" svn info --show-item url "$target" 2>/dev/null || svn info "$target" 2>/dev/null | awk -F': ' '/^URL:/{print $2; exit}')"
            [[ "$url" == *"$required"* ]] && { echo "asset_check_ok: $token"; return 0; }
            echo "asset_check_blocked: vcs:branch type=svn current_url=${url:-unknown} requires_fragment=$required"
            return 1
            ;;
        cvs)
            required="$(queue_asset_param require_tag "$@" || queue_asset_param require_branch "$@" || true)"
            [[ -n "$required" ]] || { echo "asset_check_blocked: vcs:branch cvs requires require_tag= or require_branch="; return 1; }
            current="$(_vcs_cvs_sticky_tag "$target" || true)"
            ;;
        hg)
            required="$(queue_asset_param require_branch "$@" || true)"
            [[ -n "$required" ]] || { echo "asset_check_blocked: vcs:branch hg requires require_branch="; return 1; }
            _vcs_need_tool branch hg || return 1
            current="$(hg --cwd "$target" branch 2>/dev/null)"
            ;;
        p4)
            required="$(queue_asset_param require_stream "$@" || queue_asset_param require_client "$@" || true)"
            [[ -n "$required" ]] || { echo "asset_check_blocked: vcs:branch p4 requires require_stream= or require_client="; return 1; }
            _vcs_need_tool branch p4 || return 1
            current="$(cd "$target" 2>/dev/null && timeout "$(_vcs_timeout "$@")" p4 client -o 2>/dev/null | awk -v want="$required" 'BEGIN{c=""} /^Stream:[[:space:]]*/{c=$2} /^Client:[[:space:]]*/{if(c=="") c=$2} END{print c}')"
            ;;
    esac
    if [[ "$current" == "$required" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: vcs:branch type=$type current=${current:-unknown} requires=$required"
    return 1
}

_vcs_probe_helper_path() {
    local here candidate
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P || true)"
    for candidate in         "${here}/../bin/queue-vcs-probe"         "${QUEUEBASH_ROOT:-}/bin/queue-vcs-probe"         "${QUEUEBASH_HOME:-}/bin/queue-vcs-probe"         "./bin/queue-vcs-probe"; do
        [[ -n "$candidate" && -x "$candidate" ]] && { printf '%s
' "$candidate"; return 0; }
        [[ -n "$candidate" && -f "$candidate" ]] && { printf '%s
' "$candidate"; return 0; }
    done
    command -v queue-vcs-probe 2>/dev/null || return 1
}

_vcs_probe_field() {
    local field="$1" target="$2" type="$3" timeout_s="$4" raw helper
    helper="$(_vcs_probe_helper_path || true)"
    [[ -n "$helper" ]] || { echo "asset_check_blocked: vcs:$field helper_missing=queue-vcs-probe"; return 1; }
    raw="$(bash "$helper" --json --type "$type" --timeout "$timeout_s" "$target" 2>/dev/null)" || return 1
    python3 -c 'import json, sys; data=json.loads(sys.argv[2]); value=data.get(sys.argv[1], ""); print("true" if value is True else "false" if value is False else value)' "$field" "$raw"
}
queue_asset_check_vcs_identity() {
    local token="$1" target="$2"
    shift 2 || true
    [[ -d "$target" ]] || { echo "asset_check_blocked: vcs:identity target is not a directory: $target"; return 1; }
    local type required current timeout_s
    type="$(_vcs_type_for_target "$target" "$@")" || return 1
    required="$(queue_asset_param require_identity "$@" || queue_asset_param require_branch "$@" || queue_asset_param require_tag "$@" || queue_asset_param require_stream "$@" || queue_asset_param require_client "$@" || true)"
    [[ -n "$required" ]] || { echo "asset_check_blocked: vcs:identity requires require_identity= or branch/tag/stream/client equivalent"; return 1; }
    timeout_s="$(_vcs_timeout "$@")"
    current="$(_vcs_probe_field identity "$target" "$type" "$timeout_s" || true)"
    if [[ "$current" == "$required" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: vcs:identity type=$type current=${current:-unknown} requires=$required"
    return 1
}

queue_asset_check_vcs_revision() {
    local token="$1" target="$2"
    shift 2 || true
    [[ -d "$target" ]] || { echo "asset_check_blocked: vcs:revision target is not a directory: $target"; return 1; }
    local type required current timeout_s
    type="$(_vcs_type_for_target "$target" "$@")" || return 1
    required="$(queue_asset_param require_revision "$@" || queue_asset_param require_changelist "$@" || true)"
    [[ -n "$required" ]] || { echo "asset_check_blocked: vcs:revision requires require_revision= or require_changelist="; return 1; }
    timeout_s="$(_vcs_timeout "$@")"
    current="$(_vcs_probe_field revision "$target" "$type" "$timeout_s" || true)"
    if [[ "$current" == "$required" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: vcs:revision type=$type current=${current:-unknown} requires=$required"
    return 1
}
