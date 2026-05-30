#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL $*" >&2; exit 1; }

helper="providers.d/ibm/ibm_provider.sh"
[[ -f "$helper" ]] || fail "missing $helper"
[[ -x "$helper" ]] || fail "not executable: $helper"
bash -n "$helper" || fail "syntax error: $helper"

# Provider must not contain live API calls in default path
grep -E 'curl|wget|ibmcloud\b' "$helper" && fail "$helper contains live network call in default path" || true

# No-fixture path must produce fail-closed JSON
out="$(QUEUEBASH_IBM_FIXTURE_DIR="" "$helper" detect 2>&1)"
echo "$out" | /usr/bin/python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert d.get('provider') == 'ibm', 'provider field'
assert d.get('decision') == 'deny', 'fail-closed decision'
assert d.get('fail_closed') is True, 'fail_closed field'
assert 'missing_fixture' in d.get('reason', ''), 'reason must reference missing_fixture'
print('PASS no-fixture fail-closed check')
" || fail "no-fixture path did not produce valid fail-closed JSON"

# Help subcommand exits 0
"$helper" help >/dev/null || fail "help subcommand failed"

# Unknown subcommand must exit non-zero
"$helper" bad_command 2>/dev/null && fail "unknown subcommand should exit non-zero" || true

# All fixture files present
for f in detect.json identity.json region.json resource.json network.json finops.json legal.json; do
    [[ -f "tests/fixtures/ibm/$f" ]] || fail "missing fixture: tests/fixtures/ibm/$f"
done

# Docs present
for doc in IBM_PROVIDER_CONTRACTS IBM_CLASS_CRITERIA IBM_EXPLAINABILITY IBM_LEGAL_COMPLIANCE; do
    [[ -f "docs/${doc}.md" ]] || fail "missing doc: docs/${doc}.md"
done

# Policy files present
for policy in regions.tsv identity.env finops.env; do
    [[ -f "policies.d/ibm/$policy" ]] || fail "missing policy: policies.d/ibm/$policy"
done

# regions.tsv has expected regions
grep -q 'eu-de' policies.d/ibm/regions.tsv || fail "regions.tsv missing eu-de"
grep -q 'eu-gb' policies.d/ibm/regions.tsv || fail "regions.tsv missing eu-gb"
grep -q 'FINREG' policies.d/ibm/regions.tsv || fail "regions.tsv missing FINREG framework"
grep -q 'GDPR' policies.d/ibm/regions.tsv || fail "regions.tsv missing GDPR framework"

echo 'PASS ibm_provider_contracts_static'
