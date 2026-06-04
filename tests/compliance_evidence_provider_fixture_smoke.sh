#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/compliance_evidence/compliance_evidence_provider.sh"
QUEUEBASH_COMPLIANCE_EVIDENCE_FIXTURE_DIR="$PWD/tests/fixtures/compliance_evidence" "$helper" detect > /tmp/compliance_evidence_detect.json
python3 -m json.tool /tmp/compliance_evidence_detect.json >/dev/null
QUEUEBASH_COMPLIANCE_EVIDENCE_FIXTURE_DIR="$PWD/tests/fixtures/compliance_evidence" "$helper" control explain > /tmp/compliance_evidence_control.json
python3 -m json.tool /tmp/compliance_evidence_control.json >/dev/null
QUEUEBASH_COMPLIANCE_EVIDENCE_FIXTURE_DIR="$PWD/tests/fixtures/compliance_evidence" "$helper" evidence_pack explain > /tmp/compliance_evidence_evidence_pack.json
python3 -m json.tool /tmp/compliance_evidence_evidence_pack.json >/dev/null
QUEUEBASH_COMPLIANCE_EVIDENCE_FIXTURE_DIR="$PWD/tests/fixtures/compliance_evidence" "$helper" attestation explain > /tmp/compliance_evidence_attestation.json
python3 -m json.tool /tmp/compliance_evidence_attestation.json >/dev/null
QUEUEBASH_COMPLIANCE_EVIDENCE_FIXTURE_DIR="$PWD/tests/fixtures/compliance_evidence" "$helper" retention explain > /tmp/compliance_evidence_retention.json
python3 -m json.tool /tmp/compliance_evidence_retention.json >/dev/null
printf 'PASS compliance_evidence_provider_fixture_smoke
'
