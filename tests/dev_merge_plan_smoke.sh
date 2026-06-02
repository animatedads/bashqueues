#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/queue-dev-merge-plan.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
base="$tmp/base"
mkdir -p "$base" "$tmp/p1/files" "$tmp/p1/baseline" "$tmp/p1/diffs" "$tmp/nested/root/files" "$tmp/nested/root/baseline" "$tmp/nested/root/diffs"

cat > "$base/queuebash.sh" <<'EOF_BASE'
QUEUEBASH_VERSION="0.18.80"
_func_a() {
  echo old-a
}
_func_b() {
  _func_a
}
EOF_BASE
cp "$base/queuebash.sh" "$tmp/p1/baseline/queuebash.sh"
cp "$base/queuebash.sh" "$tmp/nested/root/baseline/queuebash.sh"
cat > "$tmp/p1/files/queuebash.sh" <<'EOF_A'
QUEUEBASH_VERSION="0.18.40"
_func_a() {
  echo new-a
}
_func_b() {
  _func_a
}
EOF_A
cat > "$tmp/nested/root/files/queuebash.sh" <<'EOF_B'
QUEUEBASH_VERSION="0.18.40"
_func_a() {
  echo other-a
}
_func_b() {
  _func_a
}
EOF_B
cat > "$tmp/p1/files/README.md" <<'EOF_R'
## 0.18.40 Patch A
EOF_R
cat > "$tmp/p1/manifest.json" <<'EOF_MAN'
{
  "schema":"queuebash.dev_patchset.v1",
  "created_at":"2026-01-01T00:00:00Z",
  "entries":[
    {"entry_id":"a1","relpath":"queuebash.sh","file":"files/queuebash.sh","diff":"diffs/queuebash.sh.diff","change_type":"modified_file","baseline_present":true},
    {"entry_id":"a2","relpath":"README.md","file":"files/README.md","diff":"diffs/README.md.diff","change_type":"modified_file","baseline_present":false}
  ]
}
EOF_MAN
cat > "$tmp/nested/root/manifest.json" <<'EOF_MAN'
{
  "schema":"queuebash.dev_patchset.v1",
  "created_at":"2026-01-02T00:00:00Z",
  "entries":[
    {"entry_id":"b1","relpath":"queuebash.sh","file":"files/queuebash.sh","diff":"diffs/queuebash.sh.diff","change_type":"modified_file","baseline_present":true}
  ]
}
EOF_MAN
( cd "$tmp/p1" && zip -qr "$tmp/a.zip" . )
( cd "$tmp/nested" && zip -qr "$tmp/b.zip" root )

# Alternate manifest dialect using files[] + change_type=add.
mkdir -p "$tmp/alt1/files" "$tmp/alt1/baseline" "$tmp/alt2/files" "$tmp/alt2/baseline" "$tmp/container"
cat > "$tmp/alt1/files/merge_test.py" <<'PY1'
def bob11_epoch_source():
    return 1

def main_test_function():
    return bob11_epoch_source()
PY1
cat > "$tmp/alt1/files/merge_test.sh" <<'SH1'
bob11_epoch_source() { echo 1; }
main_test_function() { bob11_epoch_source; }
SH1
cat > "$tmp/alt1/manifest.json" <<'EOF_ALT1'
{
  "schema":"queuebash.dev.patchset.v1",
  "name":"bob11_merge_planning_0.0.1_baseline_patchset",
  "version":"0.0.1",
  "files":[
    {"path":"merge_test.py","change_type":"add"},
    {"path":"merge_test.sh","change_type":"add"},
    {"path":"docs/tests_merge_planning.md","change_type":"add"}
  ]
}
EOF_ALT1
mkdir -p "$tmp/alt1/files/docs"
printf '## merge planning fixture 0.0.1\n' > "$tmp/alt1/files/docs/tests_merge_planning.md"
( cd "$tmp/alt1" && zip -qr "$tmp/container/bob11_0.0.1.zip" . )

# Alternate manifest dialect using files[] + action=update, inside a container zip.
cat > "$tmp/alt2/files/merge_test.py" <<'PY2'
def bob10_epoch_gatekeeper():
    return 2

def main_test_function():
    return bob10_epoch_gatekeeper()
PY2
cat > "$tmp/alt2/files/merge_test.sh" <<'SH2'
bob10_epoch_gatekeeper() { echo 2; }
main_test_function() { bob10_epoch_gatekeeper; }
SH2
cat > "$tmp/alt2/manifest.json" <<'EOF_ALT2'
{
  "name":"bob10_merge_test_0.0.2_from_bob10_0.0.1",
  "version":"0.0.2",
  "files":[
    {"path":"merge_test.py","action":"update"},
    {"path":"merge_test.sh","action":"update"},
    {"path":"docs/tests_merge_planning.md","action":"update"}
  ]
}
EOF_ALT2
mkdir -p "$tmp/alt2/files/docs"
printf '## merge planning fixture 0.0.2\n' > "$tmp/alt2/files/docs/tests_merge_planning.md"
( cd "$tmp/alt2" && zip -qr "$tmp/container/bob10_0.0.2.zip" . )
( cd "$tmp/container" && zip -qr "$tmp/container.zip" . )

bin/queue-dev-merge-plan.py --base "$base" --patchset "$tmp/a.zip" --patchset "$tmp/b.zip" --patchset "$tmp/container.zip" --target-version 0.18.81 --json > "$tmp/plan.json"
bin/queue-dev-merge-plan.py summary "$tmp/plan.json" --json > "$tmp/summary.json"
bin/queue-dev-merge-plan.py explain "$tmp/plan.json" > "$tmp/explain.txt"

python3 - "$tmp/plan.json" "$tmp/summary.json" <<'PY'
import json, sys
plan=json.load(open(sys.argv[1]))
summary=json.load(open(sys.argv[2]))
assert plan['schema']=='queuebash.dev_merge_plan.v1'
assert plan['status']=='ok'
assert plan['mode']=='read_only_plan'
assert plan['summary']['patchsets']==4, plan['summary']
assert any(p['patchset_root']=='root/' for p in plan['patchsets']), 'nested patchset root not discovered'
assert any(p.get('container_member') for p in plan['patchsets']), 'container inner patchsets not expanded'
assert all(p['space_safety']=='bounded' for p in plan['patchsets'])
assert any(c.get('function')=='_func_a' for c in plan['collisions']), plan['collisions']
assert any(c.get('path')=='merge_test.py' for c in plan['collisions']), plan['collisions']
assert any(c.get('function')=='main_test_function' and c.get('path')=='merge_test.py' for c in plan['collisions']), plan['collisions']
assert any(c.get('function')=='main_test_function' and c.get('path')=='merge_test.sh' for c in plan['collisions']), plan['collisions']
versions=set(plan['release_reconciliation']['versions_seen'])
assert {'0.0.1','0.0.2'}.issubset(versions), versions
assert plan['release_reconciliation']['release_identity_overlap'] is True
assert plan['release_reconciliation']['version_overlap_policy']=='ledger_overlap_not_runtime_conflict'
assert plan['release_reconciliation']['recommended_version']=='0.18.81'
assert any('queue dev test qbtest --file queuebash.sh --function _func_a --json' in x for x in plan['validation_plan'])
assert any('python3 -m py_compile merge_test.py' in x for x in plan['validation_plan'])
assert summary['schema']=='queuebash.dev_merge_plan_summary.v1'
print('PASS merge plan json smoke')
PY

grep -q 'Merge plan:' "$tmp/explain.txt" || fail 'human explain missing header'
grep -q '_func_a' "$tmp/explain.txt" || fail 'human explain missing function conflict'
grep -q 'main_test_function' "$tmp/explain.txt" || fail 'human explain missing generic function conflict'

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh >/dev/null
queue dev merge-plan --base "$base" --patchset "$tmp/a.zip" --patchset "$tmp/b.zip" --patchset "$tmp/container.zip" --target-version 0.18.81 --json > "$tmp/queue-plan.json"
python3 - "$tmp/queue-plan.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj['schema']=='queuebash.dev_merge_plan.v1'
assert obj['summary']['high_risk_collisions'] >= 2, obj['summary']
assert obj['summary']['patchsets'] == 4
print('PASS queue dev merge-plan dispatch smoke')
PY

echo 'PASS dev_merge_plan_smoke'
