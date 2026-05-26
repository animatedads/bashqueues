#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source "$ROOT/queuebash.sh"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

mkdir -p "$QUEUEBASH_ROOT/failed" "$QUEUEBASH_ROOT/done"
cat > "$QUEUEBASH_ROOT/failed/fake_failed.job" <<'JOB'
JOB_NAME=fake_failed
PRIORITY=10
JOB_CLASS=DEFAULT
COMMAND=(false)
SUBMITTED_AT=2026-05-26T16:00:00+01:00
EXIT_CODE=1
JOB

queue clear failed >/tmp/clear_failed.out
[[ -f "$QUEUEBASH_ROOT/clearance/failed/fake_failed.job" ]] || fail "failed job was not archived"
out="$(queue audit cleared)"
printf '%s\n' "$out" | grep -q 'fake_failed' || fail "archive-only failed record absent from queue audit cleared"
printf '%s\n' "$out" | grep -q 'fake_failed[.]job\|failed' || fail "archived failed state not shown"
printf '%s\n' "$out" | grep -q 'cleared=1' || fail "cleared count should include archive-only record"

cat > "$tmp/sample.sh" <<'SH'
#!/usr/bin/env bash
sample_function() {
    echo sample
}
SH
chmod +x "$tmp/sample.sh"
(
    cd "$tmp"
    printf '## Test changelog\n' > CHANGELOG.md
    queue dev comment --file sample.sh --function sample_function --message 'document sample function' >/tmp/dev_comment.out
    grep -q 'AI-PATCH sample_function' CHANGELOG.md || exit 11
)

echo '[PASS] clearance archive reader/dev changelog smoke checks pass'
