#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d /tmp/queuebash-dev-symbols.XXXXXX)"
tmpdir="$(mktemp -d /tmp/queuebash-dev-symbols-script.XXXXXX)"
trap 'rm -rf "$QUEUEBASH_ROOT" "$tmpdir"' EXIT
source ./queuebash.sh >/dev/null

cat > "$tmpdir/sample.sh" <<'SAMPLE'
#!/usr/bin/env bash
GLOBAL_CONST="abc"
mutable_global=1
sample_symbols() {
    local local_var="hello"
    mutable_global="$local_var"
    echo "constant string" "$GLOBAL_CONST" "$mutable_global"
}
SAMPLE

queue dev symbols --file "$tmpdir/sample.sh" --json > "$tmpdir/file_symbols.json"
python3 - "$tmpdir/file_symbols.json" <<'PY'
import json, sys
o=json.load(open(sys.argv[1]))
assert o['status'] == 'ok'
assert 'GLOBAL_CONST' in o['constants']
assert 'mutable_global' in o['variables']
assert 'sample_symbols' in {f['name'] for f in o['functions']}
assert any(s['value'] == 'constant string' for s in o['strings'])
PY

queue dev symbols --file "$tmpdir/sample.sh" --function sample_symbols --json > "$tmpdir/fn_symbols.json"
python3 - "$tmpdir/fn_symbols.json" <<'PY'
import json, sys
o=json.load(open(sys.argv[1]))
assert o['function'] == 'sample_symbols'
assert o['source_kind'] == 'file_function'
assert 'local_var' in o['variables']
assert o['variables']['local_var']['scope'] in ('local', 'mixed')
PY

queue dev symbols --function _queue_dev_symbols --json > "$tmpdir/loaded_symbols.json"
python3 - "$tmpdir/loaded_symbols.json" <<'PY'
import json, sys
o=json.load(open(sys.argv[1]))
assert o['function'] == '_queue_dev_symbols'
assert '_queue_dev_symbols' in {f['name'] for f in o['functions']}
assert 'file' in o['variables']
PY

python3 queuemgr_panel.py --dev symbols main > "$tmpdir/py_symbols.json"
python3 - "$tmpdir/py_symbols.json" <<'PY'
import json, sys
o=json.load(open(sys.argv[1]))
assert o['status'] == 'ok'
assert any(f['name'] == 'main' for f in o['functions'])
assert 'main' in o['target']
PY

echo '[PASS] queue dev symbols smoke path reports Bash and Python symbols'
