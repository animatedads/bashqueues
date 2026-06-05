#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
provider="$ROOT/providers.d/enterprise/maintenance_evidence_verify.sh"
fix="$ROOT/tests/fixtures/enterprise/maintenance_evidence"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cases=(
  valid_approved_maintenance:0:
  valid_cluster_maintenance:0:
  cluster_missing_blast_radius:1:cluster_blast_radius_required
  cluster_canary_not_completed:1:cluster_canary_completion_required
  cluster_drain_not_verified:1:cluster_drain_verified_required
  cluster_rollback_raw_checkpoint:1:cluster_rollback_checkpoint_must_be_redacted
  cluster_observation_missing:1:cluster_observation_required
  cluster_observation_unhealthy:1:cluster_observation_health_ok_required
  cluster_observation_slo_regression:1:cluster_observation_latency_regression_denied
  cluster_observation_raw_evidence:1:cluster_observation_raw_evidence_must_be_redacted
)
: > "$tmp/cases.tsv"
for spec in "${cases[@]}"; do
  IFS=: read -r name expected_rc expected_failure <<<"$spec"
  out="$tmp/$name.out"; err="$tmp/$name.err"
  set +e
  timeout 20s "$provider" --request "$fix/$name.json" --json >"$out" 2>"$err"
  rc=$?
  set -e
  if [[ $rc -eq 124 ]]; then echo "[FAIL] $name timed out" >&2; cat "$err" >&2; exit 1; fi
  [[ -s "$out" ]] || { echo "[FAIL] $name produced no stdout" >&2; cat "$err" >&2; exit 1; }
  printf '%s\t%s\t%s\t%s\n' "$name" "$rc" "$expected_rc" "$expected_failure" >> "$tmp/cases.tsv"
done
python3 - "$tmp" <<'PY'
import json, sys
from pathlib import Path
tmp = Path(sys.argv[1])
for line in (tmp/'cases.tsv').read_text().splitlines():
    name, rc_s, expected_rc, expected_failure = line.split('\t')
    obj = json.loads((tmp/f'{name}.out').read_text())
    assert obj['schema'] == 'queuebash.enterprise_maintenance_evidence_decision.v1', name
    assert obj['mode'] == 'fixture-only', name
    assert obj['live_clearance_granted'] is False, name
    assert obj['system_modified'] is False, name
    assert obj['redacted'] is True, name
    assert obj['secret_value_included'] is False, name
    assert obj.get('evidence_hash', '').startswith('sha256:'), name
    assert obj.get('requester_hash', '').startswith('sha256:'), name
    assert 'maintenance-requester@example.invalid' not in json.dumps(obj), name
    if expected_rc == '0':
        assert rc_s == '0', (name, rc_s, obj)
        assert obj['ok'] is True and obj['status'] == 'ok', obj
        assert obj['failures'] == [], obj
    else:
        assert rc_s != '0', (name, rc_s, obj)
        assert obj['ok'] is False and obj['status'] == 'blocked', obj
        assert expected_failure in obj['failures'], (name, expected_failure, obj['failures'])
    if name == 'valid_approved_maintenance':
        assert obj['checks']['approver_independence'] is True, obj
        assert obj['checks']['expiry_covers_window'] is True, obj
    if name == 'valid_cluster_maintenance':
        for key in [
            'cluster_context_required', 'cluster_quorum', 'cluster_vote_approval',
            'cluster_leader_lease_covers_window', 'cluster_membership_hash',
            'cluster_node_targets_in_membership', 'cluster_vote_nodes_cover_quorum',
            'cluster_fence_token_hash', 'cluster_fence_token_redacted',
            'cluster_split_brain_guard', 'cluster_blast_radius_limited',
            'cluster_canary_completed', 'cluster_drain_verified',
            'cluster_rollback_checkpoint_hash', 'cluster_rollback_checkpoint_redacted',
            'cluster_observation_completed', 'cluster_observation_health_ok',
            'cluster_observation_slo_ok', 'cluster_observation_evidence_redacted'
        ]:
            assert obj['checks'][key] is True, (key, obj)
print('[PASS] enterprise_maintenance_evidence_smoke')
PY
