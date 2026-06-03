#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

out="$(mktemp)"
trap 'rm -f "$out"' EXIT
python3 - <<'PY' > "$out"
import json, tempfile, subprocess
from pathlib import Path
root=Path.cwd()
job=json.loads((root/'tests/fixtures/class_classifier/jobs_normal.jsonl').read_text().splitlines()[0])
with tempfile.NamedTemporaryFile('w', suffix='.json') as f:
    json.dump(job, f); f.flush()
    print(subprocess.check_output(['python3','bin/queue-class-infer.py','recommend','--json','--history','tests/fixtures/class_classifier/history_normal.jsonl','--policy','tests/fixtures/class_classifier/policy_block_on_downgrade.json','--job',f.name], text=True))
PY
python3 - <<'PY' "$out"
import json, sys
obj=json.load(open(sys.argv[1]))
assert obj['decision']=='ok', obj
assert obj['recommended_action']=='allow', obj
assert obj['recommended_class']=='DB_EXPORT_HIGH_ASSURANCE', obj
assert obj['reasons'], obj
print('PASS class_classifier_fixture_smoke')
PY
