#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL: $*" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

out="$(bin/queue-policy-wizard --root "$tmp/qroot" --dryrun --non-interactive --ai-provider gemini --allow-job-metadata --enable-itsm --itsm-backends servicenow,jira 2>&1)" || fail 'dryrun command failed'
printf '%s\n' "$out" | grep -q 'No files were written' || fail 'dryrun did not report no writes'
printf '%s\n' "$out" | grep -q '/etc/queuebash/secrets/gemini-api-key' || fail 'secret file path not shown'
printf '%s\n' "$out" | grep -q 'QUEUEBASH_AI_LIVE_ENABLED=0' || fail 'AI live gate default not shown'
[[ ! -e "$tmp/qroot" ]] || fail 'dryrun created queue root'

json="$(bin/queue-policy-wizard --root "$tmp/qroot" --dryrun --non-interactive --json)" || fail 'json dryrun failed'
python3 - "$json" <<'PY' || exit 1
import json, sys
obj=json.loads(sys.argv[1])
assert obj['schema']=='queuebash.policy_wizard_run.v1'
assert obj['dryrun'] is True
assert obj['applied'] is False
assert obj['secrets_written'] is False
assert obj['ticket_created'] is False
assert obj['files']
PY

apply_root="$tmp/applyroot"
audit="$tmp/audit/policy-wizard.audit.jsonl"
bin/queue-policy-wizard --root "$apply_root" --non-interactive --apply --audit-log "$audit" >/tmp/policy-wizard-apply.out
[[ -f "$apply_root/policies.d/legal_framework.env" ]] || fail 'legal policy not written on apply'
[[ -f "$apply_root/policies.d/class-statement/default.env" ]] || fail 'class policy not written on apply'
[[ -f "$apply_root/policies.d/ai_advisory.env" ]] || fail 'AI policy not written on apply'
[[ -f "$audit" ]] || fail 'audit log not written'
python3 - "$audit" <<'PY' || exit 1
import json, sys
line=open(sys.argv[1], encoding='utf-8').read().strip().splitlines()[-1]
obj=json.loads(line)
assert obj['schema']=='queuebash.policy_wizard_run.v1'
assert obj['applied'] is True
assert obj['secrets_written'] is False
assert obj['ticket_created'] is False
PY

echo 'PASS policy_wizard_dryrun_smoke'
