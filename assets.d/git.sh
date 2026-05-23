#!/usr/bin/env bash
# bashqueues standard git asset checks
#
# Installed helper path:
#   ~/.queuebash/assets.d/git.sh
#
# Facilities published:
#   git:repo_exists
#   git:clean_tree
#   git:branch

queue_asset_facilities() {
    cat <<'FACILITIES'
git:repo_exists	Checks that a directory is a valid Git repository
git:clean_tree	Checks that the Git working directory has no uncommitted changes
git:branch	Checks that the Git repository is currently on the specified branch
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

queue_asset_check_git_repo_exists() {
    local token="$1"
    local target_dir="$2"
    shift 2 || true

    if [[ ! -d "$target_dir" ]]; then
        echo "asset_check_blocked: git:repo_exists target is not a directory: $target_dir"
        return 1
    fi

    # Check if the directory is inside a valid git work tree
    if git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: git:repo_exists not a valid git repository: $target_dir"
    return 1
}

queue_asset_check_git_clean_tree() {
    local token="$1"
    local target_dir="$2"
    shift 2 || true

    if ! git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "asset_check_blocked: git:clean_tree not a valid git repository: $target_dir"
        return 1
    fi

    # Check for any modifications, staged changes, or untracked files
    if [[ -z "$(git -C "$target_dir" status --porcelain 2>/dev/null)" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: git:clean_tree repository has uncommitted or untracked changes: $target_dir"
    return 1
}

queue_asset_check_git_branch() {
    local token="$1"
    local target_dir="$2"
    shift 2 || true

    local require_branch current_branch

    require_branch="$(queue_asset_param require_branch "$@" || true)"

    if [[ -z "$require_branch" ]]; then
        echo "asset_check_blocked: git:branch requires require_branch= parameter"
        return 1
    fi

    if ! git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "asset_check_blocked: git:branch not a valid git repository: $target_dir"
        return 1
    fi

    current_branch="$(git -C "$target_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"

    if [[ "$current_branch" == "$require_branch" ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi

    echo "asset_check_blocked: git:branch current branch is '$current_branch', but requires '$require_branch'"
    return 1
}

queue_asset_hints() {
    cat <<'EOF'
git:repo_exists	target=repository directory	params=	example=queue_class_shared_asset git repo_exists "/home/hc3/bashqueues"	notes=Checks that target is a valid Git repository.
git:branch	target=repository directory	params=require_branch=main	example=queue_class_shared_asset git branch "/home/hc3/bashqueues" require_branch=main	notes=Checks current branch.
git:clean_tree	target=repository directory	params=allow_untracked=0	example=queue_class_shared_asset git clean_tree "/home/hc3/bashqueues" allow_untracked=0	notes=Checks whether working tree is clean.
EOF
}
