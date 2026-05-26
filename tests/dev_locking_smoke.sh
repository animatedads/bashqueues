#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
script="$tmpdir/sample.sh"
newfn="$tmpdir/new_sample.sh"
cat > "$script" <<'SCRIPT'
#!/usr/bin/env bash
sample_fn() {
    echo old
}
SCRIPT

patch_with() {
    local text="$1"
    cat > "$newfn" <<SCRIPT
sample_fn() {
    echo $text
}
SCRIPT
    QUEUEBASH_DEV_MAX_BACKUPS=2 bash -c 'QUEUEBASH_ALLOW_NONINTERACTIVE=1 source ./queuebash.sh; queue dev patch "$@"' _ --file "$script" --function sample_fn --source "$newfn" --json
}

patch_with one > "$tmpdir/patch1.json"
grep -q '"locked":true' "$tmpdir/patch1.json"
grep -q '"atomic":true' "$tmpdir/patch1.json"
grep -q 'echo one' "$script"

patch_with two > "$tmpdir/patch2.json"
patch_with three > "$tmpdir/patch3.json"
backup_count="$(find "$tmpdir" -maxdepth 1 -name 'sample.sh.bak.*' -type f | wc -l | tr -d ' ')"
[[ "$backup_count" -le 2 ]] || { echo "expected pruned backups <=2, got $backup_count" >&2; exit 1; }

# Hold the exact dev lock and ensure a competing mutation times out cleanly.
exec 8>"${script}.dev.lock"
flock 8
cat > "$newfn" <<'SCRIPT'
sample_fn() {
    echo blocked
}
SCRIPT
set +e
QUEUEBASH_DEV_LOCK_TIMEOUT=1 bash -c 'QUEUEBASH_ALLOW_NONINTERACTIVE=1 source ./queuebash.sh; queue dev patch "$@"' _ --file "$script" --function sample_fn --source "$newfn" --json > "$tmpdir/locked.out" 2> "$tmpdir/locked.err"
rc=$?
set -e
flock -u 8
exec 8>&-
[[ "$rc" -ne 0 ]] || { echo "expected locked patch to fail" >&2; exit 1; }
grep -q 'timeout acquiring lock' "$tmpdir/locked.err"
grep -q 'echo three' "$script"

# Python dev patch should also be atomic/locked and syntax-valid, using a disposable copy.
panel="$tmpdir/queuemgr_panel.py"
cp queuemgr_panel.py "$panel"
cat > "$tmpdir/new_dev_json_error.py" <<'PY'
def _dev_json_error(message: str, code: int = 1) -> None:
    import json
    print(json.dumps({"status": "error", "error": message, "hardened_smoke": True}))
    raise SystemExit(code)
PY
python3 "$panel" --dev patch _dev_json_error "$tmpdir/new_dev_json_error.py" > "$tmpdir/pypatch.json"
grep -q '"locked": true' "$tmpdir/pypatch.json"
grep -q '"atomic": true' "$tmpdir/pypatch.json"
python3 -m py_compile "$panel"

echo '[PASS] queue dev locking/atomic/pruning smoke path works on disposable files'
