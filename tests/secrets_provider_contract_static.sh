#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "FAIL secrets_provider_contract_static: $*" >&2; exit 1; }

[[ -f docs/SECRETS_PROVIDER_CONTRACT.md ]] || fail "missing provider contract doc"
[[ -f docs/SECRETS_SECURITY_MODEL.md ]] || fail "missing security model doc"
[[ -f providers.d/secrets/secrets_provider.sh ]] || fail "secrets broker helper missing"
[[ -f providers.d/secrets/file_provider.sh ]] || fail "file provider helper missing"
[[ -f policies.d/secrets/default.env.example ]] || fail "missing default policy example"
[[ -f policies.d/secrets/providers.tsv.example ]] || fail "missing provider registry example"
[[ -f policies.d/secrets/secret-acl.tsv.example ]] || fail "missing secret ACL example"
[[ -f schemas/secret_request.v1.example.json ]] || fail "missing request example schema"
[[ -f schemas/secret_provider_result.v1.example.json ]] || fail "missing result example schema"

grep -Fq '_queue_secrets_command' queuebash.sh || fail "queue secrets dispatcher missing"
grep -Fq 'providers.d/secrets/secrets_provider.sh' queuebash.sh || fail "queue secrets helper lookup missing"
grep -Fq 'bash "$helper"' queuebash.sh || fail "queue secrets should invoke helper through bash for patchset-safe permissions"

grep -Fq 'secret_value_included": false' docs/SECRETS_PROVIDER_CONTRACT.md || fail "contract does not state secret values are excluded"
grep -Fq 'QUEUEBASH_SECRET_ENV_ALLOWED=0' policies.d/secrets/default.env.example || fail "env delivery not denied by default"

# Static guard: provider code must not print a variable named secret or value.
if grep -RInE 'echo[[:space:]]+.*\$(SECRET_VALUE|secret_value|value)|printf[[:space:]].*\$(SECRET_VALUE|secret_value|value)' providers.d/secrets; then
    fail "provider appears to print secret-like variables"
fi

# No live cloud/Vault client invocation in the fixture-first package.
if grep -RInE '\b(vault|aws|oci|az|gcloud|ibmcloud)[[:space:]]+' providers.d/secrets tests/secrets_* docs/SECRETS_*; then
    fail "fixture-first secrets package contains live provider command invocation"
fi

echo "PASS secrets_provider_contract_static"
