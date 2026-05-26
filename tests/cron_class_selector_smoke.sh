#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

backup_json="$(python3 bin/bashqueues-cron-class-selector.py --command '/opt/scripts/nightly-backup.sh' --user "$(id -un)" --json)"
python3 - "$backup_json" <<'PY' || fail "backup selector JSON wrong"
import json, sys
d=json.loads(sys.argv[1])
assert d["class"] == "BACKUP_JOB", d
assert d["confidence"] >= 70, d
PY

deploy_json="$(python3 bin/bashqueues-cron-class-selector.py --command 'deploy release --target prod' --user "$(id -un)" --json)"
python3 - "$deploy_json" <<'PY' || fail "deploy selector JSON wrong"
import json, sys
d=json.loads(sys.argv[1])
assert d["class"] == "DEPLOY_RELEASE", d
PY

none_json="$(python3 bin/bashqueues-cron-class-selector.py --command 'echo hello world' --user "$(id -un)" --json)"
python3 - "$none_json" <<'PY' || fail "no-match selector JSON wrong"
import json, sys
d=json.loads(sys.argv[1])
assert d["class"] == "", d
PY

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
printf '* * * * * /opt/scripts/nightly-backup.sh\n' > "$tmp/$(id -un)"
out="$(QUEUEBASH_CRON_CLASS_SELECTOR_MIN_CONFIDENCE=70 python3 bin/bashqueues-cron-ticker.py --spool-dir "$tmp" --system-dir "$tmp/no-system" --state-dir "$tmp/state" --now '2026-05-26T00:00:00+01:00' --dryrun)"
printf '%s\n' "$out" | grep -q 'class=cron_' || fail "default cron policy should fall back to generated strict class when selected class is below minimum"

echo "[PASS] cron class selector classifies commands and ticker falls back safely under strict cron floor"
