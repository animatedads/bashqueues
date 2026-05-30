#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL $*" >&2; exit 1; }

doc="docs/IBM_EXPLAINABILITY.md"
[[ -f "$doc" ]] || fail "missing $doc"

# Explainability doc must list all checks
for check in detect identity region resource network finops legal; do
    grep -q "$check" "$doc" || fail "$doc missing check: $check"
done

# Reason vocabulary must cover key reasons
for reason in ibm_fixture_detected ibm_iam_token_valid region_in_allowed_framework \
              budget_ok_no_anomaly finops_cache_stale anomaly_detected missing_fixture; do
    grep -q "$reason" "$doc" || fail "$doc missing reason: $reason"
done

# Redaction section must exist and cover tokens and API keys
grep -qi 'iam token\|api.key\|redact' "$doc" || fail "$doc missing redaction section"

# Forbidden terms must not appear in fixture files
for fixture in tests/fixtures/ibm/*.json; do
    for term in api_key ibmcloud_api_key password secret par_url; do
        grep -qi "\"$term\"" "$fixture" && fail "$fixture contains forbidden field: $term" || true
    done
done

# Provider explain output must include remediation_hint
out="$(QUEUEBASH_IBM_FIXTURE_DIR="" providers.d/ibm/ibm_provider.sh detect 2>&1)"
echo "$out" | /usr/bin/python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert 'remediation_hint' in d, 'fail-closed output missing remediation_hint'
print('PASS remediation_hint present in fail-closed output')
" || fail "fail-closed output missing remediation_hint"

echo 'PASS ibm_explain_static'
