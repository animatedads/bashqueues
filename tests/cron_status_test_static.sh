#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
for needle in \
  '_queue_cron_status()' \
  '_queue_cron_test()' \
  'status|stat)' \
  'test|doctor|check)' \
  'bashqueues cron status' \
  'bashqueues-cron.timer' \
  'bashqueues-daemon.service' \
  'dry-run tick preview'; do
  grep -q "$needle" queuebash.sh || fail "missing cron status/test wiring: $needle"
done

grep -q 'queue cron root|status|test|list' queuebash.sh || fail "cron usage does not mention status/test"

echo "[PASS] cron status/test commands are wired"
