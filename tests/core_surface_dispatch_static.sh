#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL core_surface_dispatch_static: $*" >&2; exit 1; }
python3 - <<'PY'
import re, pathlib, sys
s=pathlib.Path('queuebash.sh').read_text()
start=s.index('\nqueue() {')+1
depth=0; end=None
for i in range(start,len(s)):
    if s[i]=='{': depth+=1
    elif s[i]=='}':
        depth-=1
        if depth==0:
            end=i; break
body=s[start:end]
refs=sorted(set(re.findall(r'\b(_queue_[A-Za-z0-9_]+)\b', body)))
defs=set(re.findall(r'^(_queue_[A-Za-z0-9_]+)\s*\(\)\s*\{', s, re.M))
missing=[r for r in refs if r not in defs]
if missing:
    print('missing dispatcher function definitions: '+', '.join(missing), file=sys.stderr)
    sys.exit(1)
required=['_queue_dev_command','_queue_remote_admin_command','_queue_cloud_command','_queue_cloud_signals_command','_queue_secrets_command','_queue_vcs_command','_queue_cluster_command','_queue_plan_command','_queue_policy_paths_command','_queue_policy_status_command']
for r in required:
    if r not in defs:
        print(f'missing required core surface: {r}', file=sys.stderr)
        sys.exit(1)
print('PASS core_surface_dispatch_static')
PY
