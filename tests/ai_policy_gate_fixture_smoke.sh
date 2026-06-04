#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export QUEUEBASH_AI_POLICY_GATE_STAGE_TIMEOUT="${QUEUEBASH_AI_POLICY_GATE_STAGE_TIMEOUT:-30}"
python3 - "$ROOT" <<'PY'
import json, os, pathlib, signal, subprocess, sys, time
root=pathlib.Path(sys.argv[1])
stage_timeout=int(os.environ.get('QUEUEBASH_AI_POLICY_GATE_STAGE_TIMEOUT','30'))
stages=[
    ('core', ['bash', str(root/'tests/ai_policy_gate_fixture_core_smoke.sh')]),
    ('examination_matrix', ['python3', str(root/'tests/ai_policy_gate_fixture_examination_matrix.py'), str(root)]),
    ('legal_hint', ['bash', str(root/'tests/ai_policy_gate_fixture_legal_hint_smoke.sh')]),
]

def tail_bytes(data, limit=4000):
    if isinstance(data, str):
        data=data.encode('utf-8','replace')
    return data[-limit:].decode('utf-8','replace')

results=[]
for name, cmd in stages:
    started=time.time()
    proc=subprocess.Popen(cmd, cwd=str(root), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=False, start_new_session=True)
    status='pass'
    try:
        out, err = proc.communicate(timeout=stage_timeout)
        rc=proc.returncode
        if rc != 0:
            status='fail'
    except subprocess.TimeoutExpired:
        status='timeout'
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            out, err = proc.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            out, err = proc.communicate()
        rc=124
    duration=int(time.time()-started)
    row={
        'schema':'queuebash.ai_policy_gate.fixture_stage_result.v1',
        'stage':name,
        'status':status,
        'rc':int(rc),
        'duration_seconds':duration,
        'stdout_tail':tail_bytes(out),
        'stderr_tail':tail_bytes(err),
    }
    results.append(row)
    print(f"stage: {name} {status} rc={rc} duration={duration}s", flush=True)
    if status != 'pass':
        break
summary={
    'schema':'queuebash.ai_policy_gate.fixture_smoke_summary.v1',
    'status':'pass' if results and all(r['status']=='pass' for r in results) else 'fail',
    'stage_timeout_seconds':stage_timeout,
    'stage_count':len(results),
    'stages':results,
}
print(json.dumps(summary, sort_keys=True), flush=True)
sys.exit(0 if summary['status']=='pass' else 1)
PY
