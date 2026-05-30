#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -q 'Provider: OCI' docs/OCI_EXPLAINABILITY.md || fail 'missing human provider line'
grep -q 'Decision: allow / deny / unknown' docs/OCI_EXPLAINABILITY.md || fail 'missing decision line'
grep -q 'Fail-closed' docs/OCI_EXPLAINABILITY.md || fail 'missing fail closed line'
grep -q 'remediation_hint' docs/OCI_EXPLAINABILITY.md || fail 'missing remediation hint json'
grep -q 'queuebash.oci.explain.v1' docs/OCI_EXPLAINABILITY.md || fail 'missing explain schema'

QUEUEBASH_OCI_FIXTURE_DIR=tests/fixtures/oci providers.d/oci/oci_provider.sh identity explain | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.oci.identity.v1"; assert d["decision"]=="allow"'

mkdir -p /tmp/oci_missing_fixture.$$ 
QUEUEBASH_OCI_FIXTURE_DIR=/tmp/oci_missing_fixture.$$ providers.d/oci/oci_provider.sh identity explain | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"]=="deny"; assert d["fail_closed"] is True'
rmdir /tmp/oci_missing_fixture.$$

echo 'PASS oci_explain_static'
