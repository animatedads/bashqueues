#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

require_file() {
  local path="$1"
  [[ -f "$repo_root/$path" ]] || { echo "missing required file: $path" >&2; exit 1; }
}

require_grep() {
  local pattern="$1" path="$2"
  grep -Fq -- "$pattern" "$repo_root/$path" || { echo "missing pattern in $path: $pattern" >&2; exit 1; }
}

require_file docs/OPERATOR_RUNBOOK.md
require_file docs/ENTERPRISE_DEPLOYMENT_RECIPE.md
require_file docs/REGULATED_SERVICE_RUNBOOK.md
require_file docs/HOSPITAL_LIVE_SAFE_MODE.md
require_file examples/enterprise/validate-enterprise-profiles.sh
require_file examples/enterprise/verify-maintenance-request.sh
require_file examples/enterprise/maintenance-request.example.json

require_grep 'active_policy_root=/etc/queuebash/policies.d' docs/OPERATOR_RUNBOOK.md
require_grep 'legacy_policy_root=/etc/bashqueues/policies.d' docs/OPERATOR_RUNBOOK.md
require_grep 'queue policy paths --json' docs/OPERATOR_RUNBOOK.md
require_grep 'queue policy status --json' docs/OPERATOR_RUNBOOK.md
require_grep 'queue enterprise list-profiles --json' docs/OPERATOR_RUNBOOK.md
require_grep 'queue enterprise validate-profile hospital-live-readonly-default --json' docs/OPERATOR_RUNBOOK.md
require_grep 'queue enterprise verify-maintenance --request examples/enterprise/maintenance-request.example.json --json' docs/OPERATOR_RUNBOOK.md
require_grep 'Before system installation, `queue` is a shell function' docs/OPERATOR_RUNBOOK.md
require_grep '/usr/local/bin/queue' docs/OPERATOR_RUNBOOK.md

require_grep '.env.example' docs/ENTERPRISE_DEPLOYMENT_RECIPE.md
require_grep 'must not be loaded automatically' docs/ENTERPRISE_DEPLOYMENT_RECIPE.md
require_grep 'does not provide `queue enterprise enable-profile`' docs/ENTERPRISE_DEPLOYMENT_RECIPE.md
require_grep 'live_clearance_granted=false' docs/ENTERPRISE_DEPLOYMENT_RECIPE.md
require_grep 'system_modified=false' docs/ENTERPRISE_DEPLOYMENT_RECIPE.md

require_grep 'queue enterprise validate-profile' examples/enterprise/validate-enterprise-profiles.sh
require_grep 'queue enterprise verify-maintenance --request' examples/enterprise/verify-maintenance-request.sh
require_grep '"schema": "queuebash.enterprise.maintenance_request.v1"' examples/enterprise/maintenance-request.example.json
require_grep '"live_clearance_requested": false' examples/enterprise/maintenance-request.example.json

if grep -R "enable-profile\|activate-profile" "$repo_root/examples/enterprise" "$repo_root/docs/OPERATOR_RUNBOOK.md" "$repo_root/docs/ENTERPRISE_DEPLOYMENT_RECIPE.md" | grep -v 'does not provide `queue enterprise enable-profile`' >/dev/null; then
  echo "unsafe enterprise activation wording found" >&2
  exit 1
fi

echo "PASS operator_runbook_enterprise_docs_static"
