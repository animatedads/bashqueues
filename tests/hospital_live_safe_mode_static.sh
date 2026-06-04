#!/usr/bin/env bash
set -euo pipefail

ro="policies.d/enterprise/hospital-live-readonly-default.env.example"
maint="policies.d/enterprise/hospital-live-approved-maintenance-default.env.example"
doc="docs/HOSPITAL_LIVE_SAFE_MODE.md"
evidence="docs/RUPERT_ENTERPRISE_PILOT_EVIDENCE.md"

for f in "$ro" "$maint" "$doc" "$evidence"; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done

grep -q 'not accepted for general live execution' "$doc"
grep -q 'policy-root consistency' "$doc"
grep -q '/etc/bashqueues' "$doc"
grep -q '/etc/queuebash' "$doc"
grep -q 'break-glass is refused by default' "$doc"
grep -q 'not as production clearance' "$evidence"

grep -q 'QUEUEBASH_ENTERPRISE_PROFILE="hospital-live-readonly-default"' "$ro"
grep -q 'QUEUEBASH_LIVE_CLEARANCE="readonly-only"' "$ro"
grep -q 'QUEUEBASH_BLOCKED_ACTIONS=.*submit' "$ro"
grep -q 'QUEUEBASH_BLOCKED_ACTIONS=.*run' "$ro"
grep -q 'QUEUEBASH_SECRET_DELIVERY_ALLOWED="0"' "$ro"
grep -q 'QUEUEBASH_SECRET_BREAK_GLASS_ALLOWED="0"' "$ro"
grep -q 'QUEUEBASH_AI_EXTERNAL_PROVIDER_ALLOWED="0"' "$ro"
grep -q 'QUEUEBASH_SECRET_VALUE_IN_JSON_ALLOWED="0"' "$ro"

grep -q 'QUEUEBASH_ENTERPRISE_PROFILE="hospital-live-approved-maintenance-default"' "$maint"
grep -q 'QUEUEBASH_LIVE_CLEARANCE="approved-maintenance-only"' "$maint"
grep -q 'QUEUEBASH_APPROVAL_REQUIRED_ACTIONS=.*maintenance-execute' "$maint"
grep -q 'QUEUEBASH_REQUIRE_DUAL_CONTROL="1"' "$maint"
grep -q 'QUEUEBASH_REQUIRE_SIGNED_APPROVAL="1"' "$maint"
grep -q 'QUEUEBASH_SECRET_BREAK_GLASS_ALLOWED="authorised-only"' "$maint"
grep -q 'QUEUEBASH_SECRET_BREAK_GLASS_TTL_SECONDS_MAX="900"' "$maint"
grep -q 'QUEUEBASH_AI_MODEL_OUTPUT_EXECUTION_ALLOWED="0"' "$maint"

if grep -R "SECRET=.*changeme\|PASSWORD=.*\|TOKEN=.*" policies.d/enterprise docs/HOSPITAL_LIVE_SAFE_MODE.md >/dev/null 2>&1; then
  echo "hospital profile must not include credential-looking defaults" >&2
  exit 1
fi

echo "PASS hospital_live_safe_mode_static"
