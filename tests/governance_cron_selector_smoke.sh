#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

gdpr_json="$(python3 bin/bashqueues-cron-class-selector.py --command 'python3 process.py' --user "$(id -un)" --jurisdiction GDPR --classification Sensitive --tags gdpr,compute --json)"
python3 - "$gdpr_json" <<'PY' || fail "GDPR selector JSON wrong"
import json, sys
d=json.loads(sys.argv[1])
assert d["class"] in {"CLOUD_COMPUTE_GDPR","CLOUD_GCP_GDPR","CLOUD_AZURE_GDPR"}, d
assert d["confidence"] >= 90, d
assert d["governance"]["jurisdiction"] == "GDPR", d
PY

blocked_json="$(python3 bin/bashqueues-cron-class-selector.py --command 'python3 process.py' --user "$(id -un)" --jurisdiction DOES_NOT_EXIST --classification Secret --fail-closed --json)"
python3 - "$blocked_json" <<'PY' || fail "fail-closed selector JSON wrong"
import json, sys
d=json.loads(sys.argv[1])
assert d["class"] == "CRON_POLICY_BLOCKED", d
assert d["confidence"] == 100, d
assert d["governance"].get("fail_closed") is True, d
PY

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/$(id -un)" <<'CRON'
#jurisdiction GDPR
#classification Sensitive
#tags gdpr,compute
* * * * * python3 process.py
CRON
out="$(QUEUEBASH_CRON_CLASS_SELECTOR_MIN_CONFIDENCE=70 python3 bin/bashqueues-cron-ticker.py --spool-dir "$tmp" --system-dir "$tmp/no-system" --state-dir "$tmp/state" --now '2026-05-26T00:00:00+01:00' --dryrun)"
printf '%s\n' "$out" | grep -Eq 'class=CLOUD_(COMPUTE|GCP|AZURE)_GDPR' || fail "ticker did not use governance-selected class: $out"

echo '[PASS] governance cron selector routes metadata and fails closed'
