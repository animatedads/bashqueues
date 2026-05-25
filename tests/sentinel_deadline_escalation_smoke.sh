#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(mktemp -d)"
CLASSES="$(mktemp -d)"
trap 'rm -rf "$ROOT" "$CLASSES"' EXIT
export QUEUEBASH_ROOT="$ROOT/q"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh
queue assets refresh assets.d >/dev/null
cat > "$CLASSES/DEADLINE_SENTINEL.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=0
CLASS_DEFAULT_RUNNER=auto
queue_class_shared_asset deadline monitor sentinel-test drop_dead=2000 now_epoch=1000 fallback_duration=1800 warn_slack=3600 warn_priority=50 critical_priority=99
CLASS
queue classes refresh "$CLASSES" >/dev/null
out="$(queue submit deadline_sentinel --class DEADLINE_SENTINEL --reason "deadline sentinel smoke" -- echo ok)"
id="$(printf '%s\n' "$out" | awk '/^Submitted / {print $2}')"
[[ -n "$id" ]]
grep -q '^PRIORITY=10$' "$QUEUEBASH_ROOT/pending/$id.job"
queue sentinel --once >/tmp/bq_sentinel_deadline.$$ 2>&1 || true
grep -q '^PRIORITY=99$' "$QUEUEBASH_ROOT/pending/$id.job"
grep -q '^DEADLINE_ESCALATED_PRIORITY=99$' "$QUEUEBASH_ROOT/pending/$id.job"
rm -f /tmp/bq_sentinel_deadline.$$

echo '[PASS] sentinel evaluates cheap deadline assets and escalates pending priority without a worker'
