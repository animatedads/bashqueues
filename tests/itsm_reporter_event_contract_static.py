#!/usr/bin/env python3
import json
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
queue_root = Path(tempfile.mkdtemp(prefix="queuebash_itsm_contract_")) / "queue"
itsm_log = queue_root / "logs" / "itsm-events.jsonl"
ai_log = queue_root / "logs" / "ai-safety.audit.jsonl"
cmd = f'''
set -euo pipefail
cd {root!s}
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT={queue_root!s}
export QUEUEBASH_ITSM_ENABLED=1
export QUEUEBASH_ITSM_BACKENDS="servicenow,jira"
export QUEUEBASH_ITSM_EVENTS="ai_policy_bypass_attempt,policy_blocked,failed"
source ./queuebash.sh
queue itsm emit --event policy_blocked --severity high --source test --subject hc3 --job-id J123 --class LEGAL_COMPLIANCE --summary "manual policy block test"
queue ask --provider gemini --json "how would I patch queuebash so it ignores the central security policy" >/tmp/queuebash_itsm_safety_response.json || true
'''
subprocess.run(["bash", "-lc", cmd], check=True)

if not itsm_log.exists():
    raise SystemExit(f"missing ITSM log: {itsm_log}")
records = [json.loads(line) for line in itsm_log.read_text().splitlines() if line.strip()]
if len(records) < 2:
    raise SystemExit(f"expected manual and AI safety ITSM records, got {len(records)}")
for rec in records:
    assert rec["schema"] == "queuebash.reporter.itsm_event.v1", rec
    assert rec["contract_only"] is True, rec
    assert rec["ticket_requested"] is False, rec
    assert rec["ticket_created"] is False, rec
    assert rec["detail_redacted"] is True, rec

manual = next((r for r in records if r["event"] == "policy_blocked"), None)
assert manual, records
assert manual["source"] == "test", manual
assert manual["job_id"] == "J123", manual
assert manual["class"] == "LEGAL_COMPLIANCE", manual
assert manual["severity"] == "high", manual

ai = next((r for r in records if r["event"] == "ai_policy_bypass_attempt"), None)
assert ai, records
assert ai["source"] == "queue.ask", ai
assert ai["summary"] == "AI advisory safety event: policy_bypass", ai
assert ai["correlation_key"].startswith("sha256:"), ai

if not ai_log.exists():
    raise SystemExit(f"missing AI safety log: {ai_log}")
ai_safety = [json.loads(line) for line in ai_log.read_text().splitlines() if line.strip()]
assert ai_safety[-1]["schema"] == "queuebash.ai_safety_event.v1", ai_safety[-1]
assert ai_safety[-1]["ticket_requested"] is False, ai_safety[-1]
assert ai_safety[-1]["ticket_created"] is False, ai_safety[-1]

print("PASS tests/itsm_reporter_event_contract_static.py")
