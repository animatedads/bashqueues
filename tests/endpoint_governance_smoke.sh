#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

source assets.d/endpoint.sh

policy="$(mktemp)"
cat > "$policy" <<'POL'
LEGAL_FRAMEWORK_UK_DPA_REGIONS="eu-west-2,europe-west2,uksouth,ukwest"
LEGAL_FRAMEWORK_HIPAA_REGIONS="us-east-1,us-west-2,eastus,westus2"
QUEUEBASH_ENDPOINT_REGION_SUBMIT_UK_EXAMPLE_COM="uksouth"
QUEUEBASH_ENDPOINT_REGION_SUBMIT_US_EXAMPLE_COM="us-east-1"
QUEUEBASH_ENDPOINT_SUFFIX_REGION_SAFE_UK_EXAMPLE_COM="uksouth"
QUEUEBASH_ENDPOINT_CIDR_REGION_1="203.0.113.0/24=eu-west-2"
POL

queue_asset_check_endpoint_jurisdiction_allowed T1 "https://submit.uk.example.com/api" framework=UK_DPA endpoint_policy_file="$policy" >/tmp/endpoint_ok.$$ || {
    cat /tmp/endpoint_ok.$$ >&2; exit 1;
}

if queue_asset_check_endpoint_jurisdiction_allowed T2 "https://submit.us.example.com/api" framework=UK_DPA endpoint_policy_file="$policy" >/tmp/endpoint_bad.$$ 2>&1; then
    echo "US endpoint unexpectedly allowed for UK_DPA" >&2
    cat /tmp/endpoint_bad.$$ >&2
    exit 1
fi
grep -q 'region_disallowed' /tmp/endpoint_bad.$$

queue_asset_check_endpoint_region_allowed T3 "203.0.113.42" regions=eu-west-2 endpoint_policy_file="$policy" >/tmp/endpoint_cidr.$$ || {
    cat /tmp/endpoint_cidr.$$ >&2; exit 1;
}

export QUEUEBASH_COMMAND_COUNT=3
export QUEUEBASH_COMMAND_0="curl"
export QUEUEBASH_COMMAND_1="https://submit.uk.example.com/api"
export QUEUEBASH_COMMAND_2="--fail"
queue_asset_check_endpoint_command_jurisdiction_allowed T4 UK_DPA endpoint_policy_file="$policy" >/tmp/endpoint_cmd_ok.$$ || {
    cat /tmp/endpoint_cmd_ok.$$ >&2; exit 1;
}
export QUEUEBASH_COMMAND_1="https://submit.us.example.com/api"
if queue_asset_check_endpoint_command_jurisdiction_allowed T5 UK_DPA endpoint_policy_file="$policy" >/tmp/endpoint_cmd_bad.$$ 2>&1; then
    echo "command US endpoint unexpectedly allowed for UK_DPA" >&2
    cat /tmp/endpoint_cmd_bad.$$ >&2
    exit 1
fi
grep -q 'region_disallowed' /tmp/endpoint_cmd_bad.$$

rm -f "$policy" /tmp/endpoint_ok.$$ /tmp/endpoint_bad.$$ /tmp/endpoint_cidr.$$ /tmp/endpoint_cmd_ok.$$ /tmp/endpoint_cmd_bad.$$
echo "[PASS] endpoint governance blocks illegal submission endpoints"
