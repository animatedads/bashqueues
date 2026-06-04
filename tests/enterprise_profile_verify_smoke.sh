#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for profile in hospital-live-readonly-default hospital-live-approved-maintenance-default; do
  out="$(providers.d/enterprise/enterprise_profile_verify.sh --profile "$profile" --json)"
  python3 - "$profile" "$out" <<'PY'
import json, sys
profile=sys.argv[1]
data=json.loads(sys.argv[2])
assert data["schema"] == "queuebash.enterprise_profile_verify.v1"
assert data["ok"] is True
assert data["status"] == "ok"
assert data["profile"] == profile
assert data["mode"] == "fixture-only"
assert data["live_clearance_granted"] is False
assert data["system_modified"] is False
assert data["failures"] == []
PY
done
printf 'PASS enterprise_profile_verify_smoke\n'
