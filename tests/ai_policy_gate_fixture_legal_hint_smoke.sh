#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
qgate() { timeout -k 2 "${QUEUEBASH_AI_POLICY_GATE_COMMAND_TIMEOUT:-10}" "$ROOT/bin/queue-ai-policy-gate" "$@"; }
# Legal/case restriction hints apply deterministically while raw hint values are redacted from model-facing request text/findings.
LEGAL_ROOT="$TMP/legal_root"
mkdir -p "$LEGAL_ROOT/pending" "$LEGAL_ROOT/logs" "$TMP/legal_policy"
cat > "$TMP/legal_policy/restriction_hints.tsv" <<'HINTS'
phrase	custom_restricted_phrase	critical	ACME_RESTRICTED_CASE_42
database_entry	custom_restricted_table	high	acme_restricted_cases
HINTS
cat > "$LEGAL_ROOT/pending/legal1.job" <<'JOB'
JOB_ID=legal1
JOB_NAME=legal_hint_check
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
COMMAND=( psql -c 'select * from acme_restricted_cases where note = "ACME_RESTRICTED_CASE_42";' )
JOB
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ROOT="$LEGAL_ROOT" \
QUEUEBASH_AI_POLICY_GATE_LEGAL_CASE_HINTS_FILE="$TMP/legal_policy/restriction_hints.tsv" \
  qgate classify --job-file "$LEGAL_ROOT/pending/legal1.job" \
  --fixture-decision-json "$ROOT/tests/fixtures/ai_policy_gate/allow_decision.json" \
  --request-json "$TMP/legal_request.json" \
  > "$TMP/legal_decision.json"
python3 - "$TMP/legal_request.json" "$TMP/legal_decision.json" <<'PY'
import json, sys
req=json.load(open(sys.argv[1]))
dec=json.load(open(sys.argv[2]))
assert dec["decision"] == "advise_delay", dec
assert dec["category"] == "legal_case_restriction_hint", dec
text=req["job"]["command_text"]
assert "ACME_RESTRICTED_CASE_42" not in text, text
assert "acme_restricted_cases" not in text.lower(), text
assert "[LEGAL_CASE_HINT:custom_restricted_phrase]" in text, text
summary=req["examination"]["pattern_summary"]["legal_case_hint_summary"]
assert summary["present"] is True, summary
assert "custom_restricted_phrase" in summary["hint_ids"], summary
assert "custom_restricted_table" in summary["hint_ids"], summary
findings=req["examination"]["findings"]
assert any(f.get("hint_id") == "custom_restricted_phrase" for f in findings), findings
assert any(f.get("hint_id") == "custom_restricted_table" for f in findings), findings
blob=json.dumps(findings, sort_keys=True)
assert "ACME_RESTRICTED_CASE_42" not in blob, blob
assert "acme_restricted_cases" not in blob.lower(), blob
PY
echo "stage: legal-hint-redaction-and-application ok"
