#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

for rel in \
  resources.d/display/lang_eng/ai-high-risk-operation-response.txt \
  resources.d/display/fallback/ai-high-risk-operation-response.txt
 do
  [[ -s "$rel" ]] || { echo "missing resource: $rel" >&2; exit 1; }
  grep -Fq "Use a governed bashqueues workflow instead" "$rel"
  grep -Fq "queue explain JOB_ID" "$rel"
 done

python3 - <<'PY'
from pathlib import Path
text=Path('queuebash.sh').read_text()
start=text.index('_queue_ai_high_risk_operation_response_text()')
end=text.index('\n}\n', start)+3
body=text[start:end]
assert '_queue_resource_fetch_i18nl_command --name ai-high-risk-operation-response.txt' in body
assert "cat <<'EOT'" not in body
assert 'This looks like a high-risk destructive' not in body
assert 'Detected job reference' in body
PY
