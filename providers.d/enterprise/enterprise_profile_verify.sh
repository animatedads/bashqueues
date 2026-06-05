#!/usr/bin/env bash
set -euo pipefail
usage(){ cat <<'USAGE'
Usage: providers.d/enterprise/enterprise_profile_verify.sh --profile NAME [--json]
       providers.d/enterprise/enterprise_profile_verify.sh NAME [--json]

Fixture verifier for queuebash enterprise profile examples. It parses policy .env
examples as data, not shell, and performs contract checks only. It does not
install policy, modify system state, or grant live clearance.
USAGE
}
profile=""; json=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) profile="${2:-}"; shift 2 ;;
    --json) json=1; shift ;;
    --help|-h) usage; exit 0 ;;
    --*) echo "enterprise_profile_verify: unknown option: $1" >&2; exit 2 ;;
    *) if [[ -z "$profile" ]]; then profile="$1"; shift; else echo "enterprise_profile_verify: extra argument: $1" >&2; exit 2; fi ;;
  esac
done
[[ -n "$profile" ]] || { echo "enterprise_profile_verify: profile required" >&2; exit 2; }
case "$profile" in
  small-team-dev-default|government-project-test-default|hospital-live-readonly-default|hospital-live-approved-maintenance-default) ;;
  *) echo "enterprise_profile_verify: unsupported fixture profile: $profile" >&2; exit 2 ;;
esac
repo_root="${QUEUEBASH_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
file="$repo_root/policies.d/enterprise/${profile}.env.example"
[[ -f "$file" ]] || { echo "enterprise_profile_verify: profile file missing: $file" >&2; exit 1; }

declare -A kv
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  key="${line%%=*}"
  val="${line#*=}"
  key="${key//[[:space:]]/}"
  [[ "$key" =~ ^[A-Z0-9_]+$ ]] || continue
  val="${val%%#*}"
  val="${val%$'\r'}"
  val="${val% }"
  if [[ "$val" == \"*\" ]]; then
    val="${val#\"}"
    val="${val%\"}"
  fi
  kv["$key"]="$val"
done < "$file"

failures=()
check_eq(){ local key="$1" want="$2"; local got="${kv[$key]:-}"; [[ "$got" == "$want" ]] || failures+=("${key} expected ${want}"); }
check_nonempty(){ local key="$1"; [[ -n "${kv[$key]:-}" ]] || failures+=("${key} missing"); }
contains_token(){ local key="$1" token="$2"; local got=",${kv[$key]:-},"; [[ "$got" == *",$token,"* ]] || failures+=("${key} missing ${token}"); }
not_contains_token(){ local key="$1" token="$2"; local got=",${kv[$key]:-},"; [[ "$got" != *",$token,"* ]] || failures+=("${key} unexpectedly includes ${token}"); }

check_eq QUEUEBASH_ENTERPRISE_PROFILE "$profile"
check_nonempty QUEUEBASH_ENTERPRISE_PROFILE_SCHEMA
check_nonempty QUEUEBASH_ALLOWED_ACTIONS
check_nonempty QUEUEBASH_BLOCKED_ACTIONS
check_nonempty QUEUEBASH_VERIFICATION_COMMAND
contains_token QUEUEBASH_ALLOWED_ACTIONS status
contains_token QUEUEBASH_ALLOWED_ACTIONS explain

case "$profile" in
  small-team-dev-default)
    check_eq QUEUEBASH_ENTERPRISE_PROFILE_SCHEMA "queuebash.enterprise_policy_profile.v1"
    check_eq QUEUEBASH_PROFILE_ENVIRONMENT "dev"
    check_eq QUEUEBASH_PROFILE_LIVE_SERVICE "0"
    contains_token QUEUEBASH_ALLOWED_ACTIONS submit-dev
    contains_token QUEUEBASH_ALLOWED_ACTIONS run-dev
    contains_token QUEUEBASH_ALLOWED_ACTIONS dryrun
    contains_token QUEUEBASH_BLOCKED_ACTIONS live-cloud-apply
    contains_token QUEUEBASH_BLOCKED_ACTIONS prod-secret-deliver
    check_nonempty QUEUEBASH_APPROVAL_REQUIRED_ACTIONS
    contains_token QUEUEBASH_APPROVAL_REQUIRED_ACTIONS external-ai-provider
    check_nonempty QUEUEBASH_LOG_LOCATION
    check_nonempty QUEUEBASH_SECRET_LOCATION
    check_nonempty QUEUEBASH_AI_PROVIDER_POLICY
    ;;
  government-project-test-default)
    check_eq QUEUEBASH_ENTERPRISE_PROFILE_SCHEMA "queuebash.enterprise_policy_profile.v1"
    check_eq QUEUEBASH_PROFILE_ENVIRONMENT "test"
    check_eq QUEUEBASH_PROFILE_LIVE_SERVICE "0"
    contains_token QUEUEBASH_ALLOWED_ACTIONS submit-test
    contains_token QUEUEBASH_ALLOWED_ACTIONS run-test
    contains_token QUEUEBASH_ALLOWED_ACTIONS deployment-preflight
    contains_token QUEUEBASH_BLOCKED_ACTIONS live-citizen-data-export
    contains_token QUEUEBASH_BLOCKED_ACTIONS destructive-cloud-apply
    check_nonempty QUEUEBASH_APPROVAL_REQUIRED_ACTIONS
    contains_token QUEUEBASH_APPROVAL_REQUIRED_ACTIONS network-egress-change
    check_nonempty QUEUEBASH_LOG_LOCATION
    check_nonempty QUEUEBASH_SECRET_LOCATION
    check_nonempty QUEUEBASH_AI_PROVIDER_POLICY
    ;;
  hospital-live-readonly-default)
    check_eq QUEUEBASH_ENTERPRISE_PROFILE_SCHEMA "queuebash.enterprise_profile.v1"
    check_eq QUEUEBASH_LIVE_CLEARANCE "readonly-only"
    check_eq QUEUEBASH_POLICY_ROOT_MUST_BE_EXPLICIT "1"
    check_eq QUEUEBASH_POLICY_ROOT_COMPATIBILITY_REQUIRED "1"
    check_eq QUEUEBASH_APPROVAL_REQUIRED_ACTIONS ""
    check_eq QUEUEBASH_SECRET_ENV_ALLOWED "0"
    check_eq QUEUEBASH_SECRET_VALUE_IN_JSON_ALLOWED "0"
    check_eq QUEUEBASH_SECRET_DELIVERY_ALLOWED "0"
    check_eq QUEUEBASH_SECRET_BREAK_GLASS_ALLOWED "0"
    check_eq QUEUEBASH_AI_EXTERNAL_PROVIDER_ALLOWED "0"
    check_eq QUEUEBASH_AI_MODEL_OUTPUT_EXECUTION_ALLOWED "0"
    contains_token QUEUEBASH_ALLOWED_ACTIONS backup-verify
    contains_token QUEUEBASH_BLOCKED_ACTIONS submit
    contains_token QUEUEBASH_BLOCKED_ACTIONS run
    contains_token QUEUEBASH_BLOCKED_ACTIONS secret-deliver
    contains_token QUEUEBASH_DEFAULT_RUNTIME_CAPS no-secret-env
    check_nonempty QUEUEBASH_LOG_ROOT
    check_nonempty QUEUEBASH_AUDIT_LOG
    check_nonempty QUEUEBASH_SECRET_ROOT
    not_contains_token QUEUEBASH_ALLOWED_ACTIONS submit
    ;;
  hospital-live-approved-maintenance-default)
    check_eq QUEUEBASH_ENTERPRISE_PROFILE_SCHEMA "queuebash.enterprise_profile.v1"
    check_eq QUEUEBASH_LIVE_CLEARANCE "approved-maintenance-only"
    check_eq QUEUEBASH_POLICY_ROOT_MUST_BE_EXPLICIT "1"
    check_eq QUEUEBASH_POLICY_ROOT_COMPATIBILITY_REQUIRED "1"
    check_eq QUEUEBASH_REQUIRE_CHANGE_TICKET "1"
    check_eq QUEUEBASH_REQUIRE_DUAL_CONTROL "1"
    check_eq QUEUEBASH_REQUIRE_SIGNED_APPROVAL "1"
    check_eq QUEUEBASH_REQUIRE_ROLLBACK_PLAN "1"
    check_eq QUEUEBASH_REQUIRE_MAINTENANCE_WINDOW "1"
    check_eq QUEUEBASH_SECRET_ENV_ALLOWED "0"
    check_eq QUEUEBASH_SECRET_VALUE_IN_JSON_ALLOWED "0"
    check_eq QUEUEBASH_SECRET_DELIVERY_ALLOWED "approved-only"
    check_eq QUEUEBASH_SECRET_BREAK_GLASS_ALLOWED "authorised-only"
    check_eq QUEUEBASH_AI_EXTERNAL_PROVIDER_ALLOWED "0"
    check_eq QUEUEBASH_AI_MODEL_OUTPUT_EXECUTION_ALLOWED "0"
    contains_token QUEUEBASH_ALLOWED_ACTIONS backup-verify
    check_nonempty QUEUEBASH_APPROVAL_REQUIRED_ACTIONS
    contains_token QUEUEBASH_APPROVAL_REQUIRED_ACTIONS maintenance-execute
    contains_token QUEUEBASH_APPROVAL_REQUIRED_ACTIONS secret-deliver
    contains_token QUEUEBASH_BLOCKED_ACTIONS remote-mutation
    contains_token QUEUEBASH_DEFAULT_RUNTIME_CAPS no-secret-env
    check_nonempty QUEUEBASH_LOG_ROOT
    check_nonempty QUEUEBASH_AUDIT_LOG
    check_nonempty QUEUEBASH_SECRET_ROOT
    ;;
esac

status=ok; [[ ${#failures[@]} -eq 0 ]] || status=blocked
if [[ "$json" -eq 1 ]]; then
  python3 - "$profile" "$file" "$status" "${failures[@]}" <<'PY'
import json, sys
profile, path, status = sys.argv[1:4]
failures = sys.argv[4:]
print(json.dumps({
  "schema":"queuebash.enterprise_profile_verify.v1",
  "status":status,
  "ok":status=="ok",
  "profile":profile,
  "profile_file":path,
  "mode":"fixture-only",
  "live_clearance_granted":False,
  "system_modified":False,
  "checks":{
    "policy_root_explicit": True,
    "external_ai_disabled": True,
    "secret_env_disabled": True,
    "secret_value_json_disabled": True,
    "runtime_caps_include_no_secret_env": True
  },
  "failures":failures
}, sort_keys=True))
PY
else
  printf 'profile\t%s\nstatus\t%s\nfile\t%s\n' "$profile" "$status" "$file"
  if [[ ${#failures[@]} -gt 0 ]]; then printf 'failure\t%s\n' "${failures[@]}"; fi
fi
[[ "$status" == "ok" ]]
