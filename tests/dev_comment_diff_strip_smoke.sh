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
cat > "$newfn" <<'SCRIPT'
sample_fn() {
    echo new
}
SCRIPT

bash -c 'QUEUEBASH_ALLOW_NONINTERACTIVE=1 source ./queuebash.sh; queue dev patch "$@"' _ --file "$script" --function sample_fn --source "$newfn" --json > "$tmpdir/patch.json"
grep -q '"status":"patched"' "$tmpdir/patch.json"
grep -q 'echo new' "$script"

bash -c 'QUEUEBASH_ALLOW_NONINTERACTIVE=1 source ./queuebash.sh; queue dev comment "$@"' _ --file "$script" --function sample_fn --message "smoke test comment" --json > "$tmpdir/comment.json"
grep -q '"status":"commented"' "$tmpdir/comment.json"
grep -q '\[AI-PATCH' "$script"

bash -c 'QUEUEBASH_ALLOW_NONINTERACTIVE=1 source ./queuebash.sh; queue dev diff "$@"' _ --file "$script" --function sample_fn --json > "$tmpdir/diff.json"
grep -q '"status":"modified"' "$tmpdir/diff.json"
grep -q 'lines_added' "$tmpdir/diff.json"

bash -c 'QUEUEBASH_ALLOW_NONINTERACTIVE=1 source ./queuebash.sh; queue dev strip "$@"' _ --file "$script" --function sample_fn --json > "$tmpdir/strip.json"
grep -q '"status":"stripped"' "$tmpdir/strip.json"
grep -q 'echo old' "$script"
! grep -q '\[AI-PATCH' "$script"

# Python dev interface should locate/extract without entering curses.
python3 queuemgr_panel.py --dev locate main > "$tmpdir/pylocate.json"
grep -q '"target": "main"' "$tmpdir/pylocate.json"
python3 queuemgr_panel.py --dev extract main > "$tmpdir/pyextract.json"
grep -q '"body"' "$tmpdir/pyextract.json"

echo '[PASS] queue dev comment/diff/strip smoke path works on disposable files'
