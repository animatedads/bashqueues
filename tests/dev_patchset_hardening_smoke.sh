#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/root"
cp queuebash.sh "$tmp/root/queuebash.sh"
cd "$tmp/root"
export QUEUEBASH_ROOT="$tmp/qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1

cat > new_helper.sh <<'SH'
new_helper_fn() {
    echo new-helper
}
SH

source ./queuebash.sh
queue dev files add --file new_helper.sh --purpose "new helper" --json > "$tmp/add.json"
queue dev files scan --json > "$tmp/scan.json"
python3 - "$tmp/scan.json" <<'PY'
import json,sys
data=json.load(open(sys.argv[1]))
assert data['missing_baseline_md5'] >= 1
records=[r for r in data['scan_records'] if r['relpath']=='new_helper.sh']
assert records and records[0]['missing_baseline_md5'] is True and records[0]['changed'] is True
PY

queue dev patchset create --output "$tmp/patch.zip" --json > "$tmp/create.json"
python3 - "$tmp/patch.zip" <<'PY'
import json,sys,zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    manifest=json.loads(z.read('manifest.json'))
    assert manifest['summary']['new_or_unbaselined_files'] >= 1
    entries=[e for e in manifest['entries'] if e['relpath']=='new_helper.sh']
    assert entries
    assert entries[0]['file_old_md5'] is None
    assert entries[0]['change_type']=='new_or_unbaselined_file'
    assert 'files/new_helper.sh' in z.namelist()
PY

queue dev patchset inspect --patchset "$tmp/patch.zip" --json > "$tmp/inspect.json"
python3 - "$tmp/inspect.json" <<'PY'
import json,sys
data=json.load(open(sys.argv[1]))
assert data['schema']=='queuebash.dev_patchset.inspect.v1'
assert data['summary']['new_or_unbaselined_files'] >= 1
PY

mkdir -p "$tmp/target_absent"
cp queuebash.sh "$tmp/target_absent/queuebash.sh"
queue dev patchset inspect --patchset "$tmp/patch.zip" --target "$tmp/target_absent" --json > "$tmp/pre.json"
python3 - "$tmp/pre.json" <<'PY'
import json,sys
data=json.load(open(sys.argv[1]))
assert data['preconditions']['status']=='ok'
statuses={r['status'] for r in data['preconditions']['results']}
assert 'ready_new_file_absent' in statuses
PY

mkdir -p "$tmp/target_conflict"
cp queuebash.sh "$tmp/target_conflict/queuebash.sh"
echo conflict > "$tmp/target_conflict/new_helper.sh"
if queue dev patchset inspect --patchset "$tmp/patch.zip" --target "$tmp/target_conflict" --json > "$tmp/conflict.json"; then
    echo "expected conflict from pre-existing new file" >&2
    exit 1
fi
python3 - "$tmp/conflict.json" <<'PY'
import json,sys
data=json.load(open(sys.argv[1]))
assert data['status']=='precondition_failed'
statuses={r['status'] for r in data['preconditions']['results']}
assert 'conflict_existing_new_file' in statuses
PY
