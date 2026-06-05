#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/certificate_authority/certificate_authority_provider.sh"
QUEUEBASH_CERTIFICATE_AUTHORITY_FIXTURE_DIR="$PWD/tests/fixtures/certificate_authority" "$helper" detect > /tmp/certificate_authority_detect.json
python3 -m json.tool /tmp/certificate_authority_detect.json >/dev/null
QUEUEBASH_CERTIFICATE_AUTHORITY_FIXTURE_DIR="$PWD/tests/fixtures/certificate_authority" "$helper" issuer explain > /tmp/certificate_authority_issuer.json
python3 -m json.tool /tmp/certificate_authority_issuer.json >/dev/null
QUEUEBASH_CERTIFICATE_AUTHORITY_FIXTURE_DIR="$PWD/tests/fixtures/certificate_authority" "$helper" certificate explain > /tmp/certificate_authority_certificate.json
python3 -m json.tool /tmp/certificate_authority_certificate.json >/dev/null
QUEUEBASH_CERTIFICATE_AUTHORITY_FIXTURE_DIR="$PWD/tests/fixtures/certificate_authority" "$helper" policy explain > /tmp/certificate_authority_policy.json
python3 -m json.tool /tmp/certificate_authority_policy.json >/dev/null
QUEUEBASH_CERTIFICATE_AUTHORITY_FIXTURE_DIR="$PWD/tests/fixtures/certificate_authority" "$helper" revocation explain > /tmp/certificate_authority_revocation.json
python3 -m json.tool /tmp/certificate_authority_revocation.json >/dev/null
printf 'PASS certificate_authority_provider_fixture_smoke
'
