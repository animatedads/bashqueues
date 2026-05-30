#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail(){ echo "FAIL: $*" >&2; exit 1; }
assert_file(){ [[ -f "$1" ]] || fail "missing file $1"; }
assert_grep(){ grep -R -- "$1" "$2" >/dev/null || fail "missing pattern '$1' in $2"; }
assert_not_grep(){ ! grep -R -- "$1" "$2" >/dev/null || fail "forbidden pattern '$1' in $2"; }

assert_file docs/OCI_PROVIDER_CONTRACTS.md
assert_file docs/OCI_CLASS_CRITERIA.md
assert_file docs/OCI_EXPLAINABILITY.md
assert_file docs/OCI_LEGAL_COMPLIANCE.md
assert_file providers.d/oci/oci_provider.sh
assert_file policies.d/oci/default.env.example
assert_file policies.d/oci/regions.tsv
assert_file policies.d/oci/object-storage.example.env
assert_file policies.d/oci/network.example.tsv
assert_file policies.d/oci/legal-frameworks.example.tsv
assert_file classes/CLOUD_OCI_DEFAULT.env
assert_file classes/CLOUD_OCI_HIGH_ASSURANCE.env
assert_file classes/CLOUD_OCI_ARTIFACT_RUNNER.env
assert_file classes/CLOUD_OCI_LEGAL_COMPLIANCE.env

assert_grep 'queuebash.oci.detect.v1' docs/OCI_PROVIDER_CONTRACTS.md
assert_grep 'queuebash.oci.identity.v1' docs/OCI_PROVIDER_CONTRACTS.md
assert_grep 'queuebash.oci.resource_shape.v1' docs/OCI_PROVIDER_CONTRACTS.md
assert_grep 'queuebash.oci.object_storage.v1' docs/OCI_PROVIDER_CONTRACTS.md
assert_grep 'queuebash.oci.network.v1' docs/OCI_PROVIDER_CONTRACTS.md
assert_grep 'queuebash.oci.region.v1' docs/OCI_PROVIDER_CONTRACTS.md
assert_grep 'queuebash.oci.explain.v1' docs/OCI_EXPLAINABILITY.md
assert_grep 'instance_principal' docs/OCI_PROVIDER_CONTRACTS.md
assert_grep 'Authorization: Bearer Oracle' docs/OCI_PROVIDER_CONTRACTS.md
assert_grep 'PAR URLs are sensitive' docs/OCI_PROVIDER_CONTRACTS.md
assert_grep 'Security Lists and Network Security Groups' docs/OCI_PROVIDER_CONTRACTS.md
assert_grep 'sovereignty' docs/OCI_LEGAL_COMPLIANCE.md
assert_grep 'retention' docs/OCI_LEGAL_COMPLIANCE.md
assert_grep 'shared responsibility' docs/OCI_LEGAL_COMPLIANCE.md
assert_grep 'primary-source validation' docs/OCI_LEGAL_COMPLIANCE.md

# This planning package must not wire into the core dispatcher.
assert_not_grep '_queue_oci_command' queuebash.sh
assert_not_grep 'queue oci' queuebash.sh
assert_not_grep 'OCI_CLI_AUTH=instance_principal oci ' queuebash.sh
assert_not_grep 'curl .*169.254.169.254' queuebash.sh

# Provider helper must be fixture-first and must not implement live calls yet.
assert_grep 'QUEUEBASH_OCI_FIXTURE_DIR' providers.d/oci/oci_provider.sh
assert_grep 'Live OCI checks are intentionally not implemented' providers.d/oci/oci_provider.sh
! grep -R --exclude='oci_provider_contracts_static.sh' -- 'BEGIN RSA PRIVATE KEY' . >/dev/null || fail 'forbidden RSA private key material found'
! grep -R --exclude='oci_provider_contracts_static.sh' -- 'BEGIN PRIVATE KEY' . >/dev/null || fail 'forbidden private key material found'

[[ ! -e assets.d/net_usage.sh ]] || fail 'assets.d/net_usage.sh must remain absent'
[[ -e caps.d/net_usage.sh ]] || fail 'caps.d/net_usage.sh should remain present'

echo 'PASS oci_provider_contracts_static'
