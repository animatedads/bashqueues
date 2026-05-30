#!/usr/bin/env bash
# bashqueues asset plugin: aws
# AWS preflight gates. Read-only by default; no provisioning or mutation.

_AWS_TIMEOUT="${AWS_TIMEOUT:-10}"

queue_asset_facilities() {
    cat <<'FACILITIES'
aws:auth_active	Validates that AWS CLI can resolve caller identity without printing credentials
aws:region_allowed	Checks that the configured AWS region is in an allow-list
aws:ec2_instance_state	Validates an EC2 instance state through describe-instances
aws:s3_bucket_access	Validates read/list access to an S3 bucket
aws:finops_budget_ok	Checks a local AWS FinOps policy file for budget guardrails
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
aws:auth_active	target=account id or _	params=profile=PROFILE timeout=10	example=queue_class_shared_asset aws auth_active _ profile=prod-readonly	notes=Runs aws sts get-caller-identity. Does not print credentials or tokens.
aws:region_allowed	target=comma-separated AWS regions	params=region=REGION	example=queue_class_shared_asset aws region_allowed "eu-west-2,us-east-1" region=eu-west-2	notes=Uses region=, AWS_REGION, AWS_DEFAULT_REGION, or QUEUEBASH_CLOUD_REGION.
aws:ec2_instance_state	target=instance-id	params=expected=running region=REGION profile=PROFILE timeout=10	example=queue_class_shared_asset aws ec2_instance_state i-012345 expected=running region=eu-west-2	notes=Read-only describe-instances check.
aws:s3_bucket_access	target=bucket-name	params=prefix=PREFIX region=REGION profile=PROFILE timeout=10	example=queue_class_shared_asset aws s3_bucket_access my-bucket prefix=healthcheck/	notes=Read-only list-objects-v2 check.
aws:finops_budget_ok	target=policy name or _	params=policy_file=/path/aws-cost-policy.json max_hourly_usd=N expected_hourly_usd=N	example=queue_class_shared_asset aws finops_budget_ok gdpr-db policy_file=policies.d/aws/cost-policy.example.json expected_hourly_usd=0.08	notes=Local policy check; does not call AWS Billing APIs.
EOF_HINTS
}

queue_asset_param() {
    local key="$1" p
    shift || true
    for p in "$@"; do
        case "$p" in "$key="*) printf '%s\n' "${p#*=}"; return 0 ;; esac
    done
    return 1
}

_queue_asset_aws_region() {
    local region
    region="$(queue_asset_param region "$@" || true)"
    region="${region:-${AWS_REGION:-${AWS_DEFAULT_REGION:-${QUEUEBASH_CLOUD_REGION:-}}}}"
    printf '%s\n' "$region"
}

_queue_asset_aws_csv_has() {
    local list="${1:-}" needle="${2:-}" item
    list="${list//[[:space:]]/}"
    IFS=',' read -r -a _qb_aws_items <<< "$list"
    for item in "${_qb_aws_items[@]}"; do
        [[ "$item" == "$needle" || "$item" == "*" ]] && return 0
    done
    return 1
}

_queue_asset_aws_profile_array() {
    local profile
    profile="$(queue_asset_param profile "$@" || true)"
    [[ -n "$profile" ]] && printf '%s\n%s\n' --profile "$profile"
}

queue_asset_check_aws_auth_active() {
    local token="$1" expect_account="$2"; shift 2 || true
    local timeout account profile_args=() x
    timeout="$(queue_asset_param timeout "$@" || echo "$_AWS_TIMEOUT")"
    command -v aws >/dev/null 2>&1 || { echo "asset_check_blocked: aws:auth_active tool_missing=aws"; return 1; }
    while IFS= read -r x; do [[ -n "$x" ]] && profile_args+=("$x"); done < <(_queue_asset_aws_profile_array "$@" || true)
    account="$(timeout "$timeout" aws "${profile_args[@]}" sts get-caller-identity --query Account --output text 2>/dev/null || true)"
    [[ -n "$account" && "$account" != "None" ]] || { echo "asset_check_blocked: aws:auth_active no_valid_identity"; return 1; }
    if [[ -n "$expect_account" && "$expect_account" != "_" && "$account" != "$expect_account" ]]; then
        echo "asset_check_blocked: aws:auth_active account_mismatch expected=$expect_account got=$account"
        return 1
    fi
    echo "asset_check_ok: $token"
    return 0
}

queue_asset_check_aws_region_allowed() {
    local token="$1" allowed="$2"; shift 2 || true
    local region
    region="$(_queue_asset_aws_region "$@")"
    [[ -n "$allowed" ]] || { echo "asset_check_blocked: aws:region_allowed allow_list_required"; return 1; }
    [[ -n "$region" ]] || { echo "asset_check_blocked: aws:region_allowed cloud_region_unknown"; return 1; }
    if _queue_asset_aws_csv_has "$allowed" "$region"; then echo "asset_check_ok: $token"; return 0; fi
    echo "asset_check_blocked: aws:region_allowed region=$region allowed=$allowed"
    return 1
}

queue_asset_check_aws_ec2_instance_state() {
    local token="$1" instance_id="$2"; shift 2 || true
    local timeout region expected state profile_args=() x
    timeout="$(queue_asset_param timeout "$@" || echo "$_AWS_TIMEOUT")"
    region="$(_queue_asset_aws_region "$@")"
    expected="$(queue_asset_param expected "$@" || echo running)"
    [[ -n "$instance_id" && "$instance_id" != "_" ]] || { echo "asset_check_blocked: aws:ec2_instance_state instance_id_required"; return 1; }
    [[ -n "$region" ]] || { echo "asset_check_blocked: aws:ec2_instance_state region_required"; return 1; }
    command -v aws >/dev/null 2>&1 || { echo "asset_check_blocked: aws:ec2_instance_state tool_missing=aws"; return 1; }
    while IFS= read -r x; do [[ -n "$x" ]] && profile_args+=("$x"); done < <(_queue_asset_aws_profile_array "$@" || true)
    state="$(timeout "$timeout" aws "${profile_args[@]}" ec2 describe-instances --region "$region" --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || true)"
    if [[ "$state" == "$expected" ]]; then echo "asset_check_ok: $token"; return 0; fi
    echo "asset_check_blocked: aws:ec2_instance_state expected=$expected got=${state:-unknown} region=$region"
    return 1
}

queue_asset_check_aws_s3_bucket_access() {
    local token="$1" bucket="$2"; shift 2 || true
    local timeout region prefix profile_args=() x cmd=()
    timeout="$(queue_asset_param timeout "$@" || echo "$_AWS_TIMEOUT")"
    region="$(_queue_asset_aws_region "$@")"
    prefix="$(queue_asset_param prefix "$@" || true)"
    [[ -n "$bucket" && "$bucket" != "_" ]] || { echo "asset_check_blocked: aws:s3_bucket_access bucket_required"; return 1; }
    command -v aws >/dev/null 2>&1 || { echo "asset_check_blocked: aws:s3_bucket_access tool_missing=aws"; return 1; }
    while IFS= read -r x; do [[ -n "$x" ]] && profile_args+=("$x"); done < <(_queue_asset_aws_profile_array "$@" || true)
    cmd=(aws "${profile_args[@]}" s3api list-objects-v2 --bucket "$bucket" --prefix "$prefix" --max-items 1)
    [[ -n "$region" ]] && cmd+=(--region "$region")
    if timeout "$timeout" "${cmd[@]}" >/dev/null 2>&1; then echo "asset_check_ok: $token"; return 0; fi
    echo "asset_check_blocked: aws:s3_bucket_access failed bucket=$bucket region=${region:-default}"
    return 1
}

queue_asset_check_aws_finops_budget_ok() {
    local token="$1" policy_name="$2"; shift 2 || true
    local policy_file max expected status
    policy_file="$(queue_asset_param policy_file "$@" || echo "policies.d/aws/cost-policy.example.json")"
    max="$(queue_asset_param max_hourly_usd "$@" || true)"
    expected="$(queue_asset_param expected_hourly_usd "$@" || true)"
    [[ -r "$policy_file" ]] || { echo "asset_check_blocked: aws:finops_budget_ok policy_missing=$policy_file"; return 1; }
    status="$(python3 - "$policy_file" "${policy_name:-_}" "${max:-}" "${expected:-}" <<'PYFINOPS' 2>/dev/null
import json, sys
p=json.load(open(sys.argv[1], encoding='utf-8'))
def f(x, default=0.0):
    try: return float(x)
    except Exception: return default
limit=f(sys.argv[3], f(p.get('max_hourly_usd'), 0.0))
expected=f(sys.argv[4], f(p.get('expected_hourly_usd'), 0.0))
allowed=p.get('allow_over_budget', False)
print('ok' if (limit <= 0 or expected <= limit or allowed) else 'over_budget')
PYFINOPS
)"
    if [[ "$status" == ok ]]; then echo "asset_check_ok: $token policy=${policy_name:-_}"; return 0; fi
    echo "asset_check_blocked: aws:finops_budget_ok $status policy=${policy_name:-_}"
    return 1
}
