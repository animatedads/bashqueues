#!/usr/bin/env bash
set -euo pipefail
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
mkdir -p "$QUEUEBASH_ROOT"
# Avoid the expensive bundled catalog seed: this command only verifies bundled provider evidence.
grep -E '^QUEUEBASH_VERSION=' queuebash.sh | head -1 | sed -E 's/.*"([^"]+)".*/\1/' > "$QUEUEBASH_ROOT/.queuebash_bundled_install_version"
source ./queuebash.sh
profiles=(small-team-dev-default government-project-test-default hospital-live-readonly-default hospital-live-approved-maintenance-default)
for profile in "${profiles[@]}"; do
  out="$(queue enterprise validate-profile "$profile" --json)"
  alias_out="$(queue enterprise verify-profile "$profile" --json)"
  python3 - "$profile" "$out" "$alias_out" <<'PY'
import json, sys
profile=sys.argv[1]
objs=[json.loads(sys.argv[2]), json.loads(sys.argv[3])]
for data in objs:
    assert data['schema']=='queuebash.enterprise_profile_verify.v1', data
    assert data['profile']==profile, data
    assert data['status']=='ok', data
    assert data['ok'] is True, data
    assert data['mode']=='fixture-only', data
    assert data['live_clearance_granted'] is False, data
    assert data['system_modified'] is False, data
PY
done
profiles_json="$(queue enterprise list-profiles --json)"
alias_json="$(queue enterprise profiles --json)"
python3 - "$profiles_json" "$alias_json" <<'PY'
import json, sys
for raw in sys.argv[1:]:
    obj=json.loads(raw)
    assert obj['schema']=='queuebash.enterprise_profiles.v1', obj
    assert obj['activation_supported'] is False, obj
    assert obj['system_modified'] is False, obj
    assert len(obj['profiles']) == 4, obj
    names={p['name'] for p in obj['profiles']}
    assert 'hospital-live-readonly-default' in names, obj
    for p in obj['profiles']:
        assert p['example'] is True, p
        assert p['active'] is False, p
        assert p['path'].endswith('.env.example'), p
PY
req="tests/fixtures/enterprise/maintenance_evidence/valid_approved_maintenance.json"
maint_json="$(queue enterprise verify-maintenance --request "$req" --json)"
python3 - "$maint_json" <<'PY'
import json, sys
obj=json.loads(sys.argv[1])
assert obj['schema']=='queuebash.enterprise_maintenance_evidence_decision.v1', obj
assert obj['status']=='ok' and obj['ok'] is True, obj
assert obj['mode']=='fixture-only', obj
assert obj['live_clearance_granted'] is False, obj
assert obj['system_modified'] is False, obj
assert obj['secret_value_included'] is False, obj
PY
echo 'PASS enterprise_profile_command_smoke'
