#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
mkdir -p "$QUEUEBASH_ROOT/envs.d"
cat > "$QUEUEBASH_ROOT/envs.d/live.env" <<'ENV'
EXEC_ENV_NAME=live
EXEC_ENV_LABEL=Live
ENV

# shellcheck disable=SC1091
source ./queuebash.sh >/dev/null 2>&1
_queue_init() { :; }

assert_json_text() {
  local name="$1" data="$2"
  printf '%s\n' "$data" | python3 -m json.tool >/dev/null || { echo "invalid JSON: $name" >&2; printf '%s\n' "$data" >&2; return 1; }
}

assert_json_text 'env list' "$(_queue_env_list --json)"
assert_json_text 'acl help' "$(_queue_acl_command help --json)"
assert_json_text 'acl operations' "$(_queue_acl_command operations --json)"
assert_json_text 'draft list' "$(_queue_draft_command list --json)"

echo "queue command JSON smoke checks passed"
