#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

for name in cluster-help.txt enterprise-help.txt; do
  test -f "resources.d/display/lang_eng/$name"
  test -f "resources.d/display/fallback/$name"
  cmp -s "resources.d/display/lang_eng/$name" "resources.d/display/fallback/$name"
  grep -Fq 'Usage: queue' "resources.d/display/lang_eng/$name"
done

python3 - <<'PY'
from pathlib import Path
s=Path('queuebash.sh').read_text()
for fn,res in [('_queue_cluster_command','cluster-help.txt'),('_queue_enterprise_command','enterprise-help.txt')]:
    start=s.index(fn+'() {')
    rest=s[start:]
    depth=0; end=None
    for off,line in enumerate(rest.splitlines(True)):
        depth += line.count('{') - line.count('}')
        if off and depth<=0:
            end=sum(len(x) for x in rest.splitlines(True)[:off+1]); break
    body=rest[:end]
    assert '_queue_resource_fetch_i18nl_command' in body, fn
    assert res in body, (fn,res)
    assert "cat <<'EOF'" not in body and 'ENTERPRISE_HELP' not in body, fn
print('display_help_resources_wave11_static: ok')
PY
