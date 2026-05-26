#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d /tmp/queuebash-dev-smoke.XXXXXX)"
trap 'rm -rf "$QUEUEBASH_ROOT" "$tmpdir"' EXIT

tmpdir="$(mktemp -d /tmp/queuebash-dev-patch.XXXXXX)"
source ./queuebash.sh >/dev/null

loc_json="$(queue dev locate _queue_dev_patch --json)"
printf '%s' "$loc_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["function"] == "_queue_dev_patch"; assert o["line_start"] > 0; assert o["file"]' 

extract_json="$(queue dev extract _queue_dev_patch --json)"
printf '%s' "$extract_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["function"] == "_queue_dev_patch"; assert "queue dev patch" in o["body"]' 

funcs_json="$(queue dev functions --json _queue_dev_ )"
printf '%s' "$funcs_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); funcs={x["function"] for x in o["functions"]}; assert "_queue_dev_locate" in funcs; assert "_queue_dev_extract" in funcs; assert "_queue_dev_patch" in funcs' 

cat > "$tmpdir/sample.sh" <<'SAMPLE'
#!/usr/bin/env bash
alpha() {
    echo old
}

beta() {
    echo keep
}
SAMPLE
cat > "$tmpdir/new_alpha.sh" <<'NEWALPHA'
alpha() {
    echo new
}
NEWALPHA

patch_json="$(queue dev patch --file "$tmpdir/sample.sh" --function alpha --source "$tmpdir/new_alpha.sh" --json)"
printf '%s' "$patch_json" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["status"] == "patched"; assert o["function"] == "alpha"; assert o["syntax_checked"] is True; assert o["backup"]' 
bash -n "$tmpdir/sample.sh"
grep -q 'echo new' "$tmpdir/sample.sh"
grep -q 'echo keep' "$tmpdir/sample.sh"

cat > "$tmpdir/bad_alpha.sh" <<'BADALPHA'
alpha() {
    if true; then
        echo broken
}
BADALPHA
if queue dev patch --file "$tmpdir/sample.sh" --function alpha --source "$tmpdir/bad_alpha.sh" --json >/tmp/qb_dev_bad.json 2>/dev/null; then
    echo "expected bad patch to fail" >&2
    exit 1
fi
grep -q 'echo new' "$tmpdir/sample.sh"

echo "[PASS] queue dev locate/extract/functions/patch smoke test passed"
