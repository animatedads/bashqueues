#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh

roles="$(_queue_resource_fetch_i18nl_command --name profile-signature-roles.txt --lang lang_eng --raw)"
[[ "$roles" == *author* ]]
[[ "$roles" == *auditor* ]]

policy="$(_queue_resource_fetch_i18nl_command --name profile-signature-required-policy-example.txt --lang lang_eng --raw)"
[[ "$policy" == *'profile_glob<TAB>role'* ]]
[[ "$policy" == *'prod-*'* ]]

schema="$(_queue_resource_fetch_i18nl_command --name profile-signature-schema-example.json --lang lang_eng --raw)"
[[ "$schema" == *'queuebash.profile_signatures.v1'* ]]
[[ "$schema" == *'signature_b64'* ]]

module_policy="$(_queue_resource_fetch_i18nl_command --name module-policy-provider-contract.txt --lang lang_eng --raw)"
[[ "$module_policy" == *'provider policy contract:'* ]]
[[ "$module_policy" == *'normalized data, never shell'* ]]

echo "PASS display_help_resources_wave8_rebased_smoke"
