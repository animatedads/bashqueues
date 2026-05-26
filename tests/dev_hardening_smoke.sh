#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cat > "$work/sample.sh" <<'SRC'
alpha() {
    local msg="old"
    echo "$msg"
}

beta() {
    alpha
}
SRC
cat > "$work/new_alpha.sh" <<'SRC'
alpha() {
    local msg="new"
    echo "$msg"
}
SRC

patch_json="$(bash -lc 'source ./queuebash.sh; queue dev patch --file "$0" --function alpha --source "$1" --json' "$work/sample.sh" "$work/new_alpha.sh")"
printf '%s' "$patch_json" | grep -q '"status":"patched"'
printf '%s' "$patch_json" | grep -q '"locked":true'
printf '%s' "$patch_json" | grep -q '"atomic":true'
[[ -f "$work/sample.sh.dev.lock" ]]
[[ "$(ls "$work"/sample.sh.bak.* 2>/dev/null | wc -l | tr -d ' ')" -ge 1 ]]

comment_json="$(bash -lc 'source ./queuebash.sh; queue dev comment --file "$0" --function alpha --message "hardening smoke" --json' "$work/sample.sh")"
printf '%s' "$comment_json" | grep -q '"status":"commented"'
# Same comment should not be duplicated in the adjacent AI-PATCH block.
bash -lc 'source ./queuebash.sh; queue dev comment --file "$0" --function alpha --message "hardening smoke" --json >/dev/null' "$work/sample.sh"
[[ "$(grep -c 'hardening smoke' "$work/sample.sh")" -eq 1 ]]

sym_json="$(bash -lc 'source ./queuebash.sh; queue dev symbols --file "$0" --function alpha --json' "$work/sample.sh")"
printf '%s' "$sym_json" | grep -q '"source_kind":"file_function"'
printf '%s' "$sym_json" | grep -q '"line_offset":1'
printf '%s' "$sym_json" | grep -q '"line_start":2'

strip_json="$(bash -lc 'source ./queuebash.sh; queue dev strip --file "$0" --function alpha --json' "$work/sample.sh")"
printf '%s' "$strip_json" | grep -q '"status":"stripped"'
grep -q 'local msg="old"' "$work/sample.sh"
! grep -q 'AI-PATCH' "$work/sample.sh"

# Backup pruning should keep the count bounded without requiring a long patch loop.
export QUEUEBASH_DEV_MAX_BACKUPS=2
for i in 1 2 3 4; do
  cp -p "$work/sample.sh" "$work/sample.sh.bak.2099010100000$i.$$"
  sleep 0.02
done
bash -lc 'source ./queuebash.sh; _queue_dev_prune_backups "$0"' "$work/sample.sh"
count="$(ls "$work"/sample.sh.bak.* 2>/dev/null | wc -l | tr -d ' ')"
[[ "$count" -le 2 ]]

echo '[PASS] queue dev hardening smoke checks passed'
