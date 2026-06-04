#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

required=(
  profile-signature-roles.txt
  profile-signature-required-policy-example.txt
  profile-signature-schema-example.json
  module-policy-provider-contract.txt
)
for name in "${required[@]}"; do
  test -s "resources.d/display/lang_eng/$name"
  test -s "resources.d/display/fallback/$name"
done

grep -q '_queue_resource_fetch_i18nl_command --name profile-signature-roles.txt' queuebash.sh
grep -q '_queue_resource_fetch_i18nl_command --name profile-signature-required-policy-example.txt' queuebash.sh
grep -q '_queue_resource_fetch_i18nl_command --name profile-signature-schema-example.json' queuebash.sh
grep -q '_queue_resource_fetch_i18nl_command --name module-policy-provider-contract.txt' queuebash.sh

if sed -n '/_queue_profile_multisig_roles()/,/^}/p' queuebash.sh | grep -q "cat <<'EOF'"; then
  echo "profile-signature roles still embeds heredoc" >&2
  exit 1
fi
if sed -n '/_queue_profile_multisig_schema()/,/^}/p' queuebash.sh | grep -q "cat <<'EOF'"; then
  echo "profile-signature schema still embeds heredoc" >&2
  exit 1
fi
if sed -n '/_queue_module_policy()/,/^}/p' queuebash.sh | grep -q 'provider policy contract:'; then
  echo "module provider policy contract still embedded in queuebash.sh" >&2
  exit 1
fi

if grep -R '\$[({]' resources.d/display/lang_eng/profile-signature-roles.txt resources.d/display/lang_eng/module-policy-provider-contract.txt; then
  echo "display resources must remain presentation data, not shell templates" >&2
  exit 1
fi

echo "PASS display_help_resources_wave8_rebased_static"
