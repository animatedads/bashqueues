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


grep -Fq 'class-bindings.tsv' docs/SECRETS_PROVIDER_CONTRACT.md || fail "contract does not document active class binding policy"
grep -Fq 'secret-acl.tsv' docs/SECRETS_PROVIDER_CONTRACT.md || fail "contract does not document active secret ACL policy"
grep -Fq '_secret_policy_class_allowed' providers.d/secrets/file_provider.sh || fail "file provider does not enforce class binding policy"
grep -Fq '_secret_policy_acl_allowed' providers.d/secrets/file_provider.sh || fail "file provider does not enforce secret ACL policy"
grep -Fq '_secret_audit_emit' providers.d/secrets/file_provider.sh || fail "file provider does not write redacted audit events"
grep -Fq 'purpose_hash' providers.d/secrets/file_provider.sh || fail "audit events must hash purpose text"
grep -Fq 'break-glass|breakglass' providers.d/secrets/secrets_provider.sh || fail "broker does not expose break-glass refusal path"
grep -Fq 'authorization_required' providers.d/secrets/secrets_provider.sh || fail "break-glass fixture path must require authorization"
if grep -Fq 'python3 -c' providers.d/secrets/secrets_provider.sh; then
    fail "secrets broker should not depend on python for JSON escaping"
fi
[[ -f tests/secrets_provider_policy_gate_smoke.sh ]] || fail "missing policy gate smoke test"
[[ -f tests/secrets_provider_manifest_verify_smoke.sh ]] || fail "missing manifest verify smoke test"

# Static guard: provider code must not print a variable named secret or value.
if grep -RInE 'echo[[:space:]]+.*\$(SECRET_VALUE|secret_value|value)|printf[[:space:]].*\$(SECRET_VALUE|secret_value|value)' providers.d/secrets; then
    fail "provider appears to print secret-like variables"
fi

# No live cloud/Vault client invocation in the fixture-first package.
if grep -RInE '\b(vault|aws|oci|az|gcloud|ibmcloud)[[:space:]]+' providers.d/secrets tests/secrets_* docs/SECRETS_*; then
    fail "fixture-first secrets package contains live provider command invocation"
fi


# 0.18.103 cleanup manifest/evidence hardening
grep -Fq 'queuebash.secret_delivery_manifest.v1' providers.d/secrets/file_provider.sh || { echo "missing secret delivery manifest schema" >&2; exit 1; }
grep -Fq 'queuebash.secret_cleanup_evidence.v1' providers.d/secrets/file_provider.sh || { echo "missing secret cleanup evidence schema" >&2; exit 1; }
grep -Fq 'secret_ref_hash' providers.d/secrets/file_provider.sh || { echo "manifest should hash secret reference metadata" >&2; exit 1; }
grep -Fq 'cleanup_evidence' providers.d/secrets/file_provider.sh || { echo "cleanup should return cleanup evidence path" >&2; exit 1; }
grep -Fq '0.18.103 hardening: delivery manifest and cleanup evidence' docs/SECRETS_PROVIDER_CONTRACT.md || { echo "contract doc missing 0.18.103 cleanup manifest section" >&2; exit 1; }

# 0.18.104 manifest verification hardening
grep -Fq 'queuebash.secret_manifest_verify.v1' providers.d/secrets/file_provider.sh || { echo "missing secret manifest verify schema" >&2; exit 1; }
grep -Fq 'verify-manifest|manifest-verify|verify' providers.d/secrets/secrets_provider.sh || { echo "broker missing verify-manifest forwarding" >&2; exit 1; }
grep -Fq '0.18.104 hardening: delivery manifest verification' docs/SECRETS_PROVIDER_CONTRACT.md || { echo "contract doc missing 0.18.104 manifest verify section" >&2; exit 1; }


# 0.18.106 manifest seal/tamper-evidence hardening
grep -Fq 'queuebash.secret_manifest_seal.v1' providers.d/secrets/file_provider.sh || { echo "missing secret manifest seal schema" >&2; exit 1; }
grep -Fq 'seal-manifest|manifest-seal|seal' providers.d/secrets/secrets_provider.sh || { echo "broker missing seal-manifest forwarding" >&2; exit 1; }
grep -Fq 'seal_status' providers.d/secrets/file_provider.sh || { echo "verify-manifest should report seal status" >&2; exit 1; }
grep -Fq '0.18.106 hardening: delivery manifest seal evidence' docs/SECRETS_PROVIDER_CONTRACT.md || { echo "contract doc missing 0.18.106 manifest seal section" >&2; exit 1; }
[[ -f tests/secrets_provider_manifest_seal_smoke.sh ]] || { echo "missing manifest seal smoke test" >&2; exit 1; }

echo "PASS secrets_provider_contract_static"
