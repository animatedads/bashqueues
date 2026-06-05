#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

for path in \
  resources.d/display/lang_eng/vcs-help.txt \
  resources.d/display/fallback/vcs-help.txt; do
  [[ -s "$path" ]] || { echo "missing resource: $path" >&2; exit 1; }
  grep -Fq 'Usage: queue vcs detect [PATH] [--json]' "$path"
  grep -Fq 'Read-only VCS tenant diagnostics' "$path"
done

python3 - <<'PY'
from pathlib import Path
s=Path('queuebash.sh').read_text()
start=s.index('_queue_vcs_command()')
end=s.index('\n\n_queue_profile_multisig_command()', start)
body=s[start:end]
assert '_queue_resource_fetch_i18nl_command --name vcs-help.txt' in body
assert "cat <<'EOF'" not in body
assert 'Read-only VCS tenant diagnostics' not in body
PY
