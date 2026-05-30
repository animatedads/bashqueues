#!/usr/bin/env bash
# bashqueues cloud resource provider: file-backed registry and lease contract
# Contract-only provider. No live cloud API calls and no provisioning.
set -euo pipefail

_registry_dir() {
  if [[ -n "${QUEUEBASH_CLOUD_RESOURCE_REGISTRY:-}" ]]; then
    printf '%s\n' "$QUEUEBASH_CLOUD_RESOURCE_REGISTRY"
  else
    printf '%s\n' "${QUEUEBASH_ROOT:-$HOME/.queuebash}/cloud_resources"
  fi
}

case "${1:-help}" in
  help|-h|--help)
    cat <<'USAGE'
Usage:
  cloud_resource_provider.sh init [--registry DIR]
  cloud_resource_provider.sh add --file RESOURCE.json [--registry DIR]
  cloud_resource_provider.sh list [--json] [--registry DIR]
  cloud_resource_provider.sh show RESOURCE_ID [--json] [--registry DIR]
  cloud_resource_provider.sh check-matching [filters...] [--json] [--registry DIR]
  cloud_resource_provider.sh claim-matching --qid QID --class CLASS [filters...] [--lease-seconds N] [--json] [--registry DIR]
  cloud_resource_provider.sh claim RESOURCE_ID --qid QID --class CLASS [--lease-seconds N] [--json] [--registry DIR]
  cloud_resource_provider.sh heartbeat CLAIM_ID [--lease-seconds N] [--json] [--registry DIR]
  cloud_resource_provider.sh release CLAIM_ID [--json] [--registry DIR]
  cloud_resource_provider.sh reconcile [--json] [--registry DIR] [--observations FILE] [--stale-after-seconds N] [--mark-missing-stale]
  cloud_resource_provider.sh explain [filters...] [--json] [--registry DIR]
  cloud_resource_provider.sh self-test [--json] [--registry DIR]

Filters:
  --provider NAME --type TYPE --resource-type TYPE --region REGION --zone ZONE
  --compliance LABEL --label LABEL --class CLASS --min-cpu N --min-mem-gb N

Default registry: $QUEUEBASH_CLOUD_RESOURCE_REGISTRY or $QUEUEBASH_ROOT/cloud_resources.
This provider is file-backed and fail-closed. It does not call cloud APIs.
USAGE
    exit 0
    ;;
esac

cmd="$1"; shift || true
export QUEUEBASH_CLOUD_RESOURCE_REGISTRY_RESOLVED="$(_registry_dir)"
python3 - "$cmd" "$@" <<'PY'
import argparse, json, os, sys, time, uuid
from pathlib import Path

SCHEMA_RESOURCE = "queuebash.cloud_resource.v1"
SCHEMA_CLAIM = "queuebash.cloud_resource_claim.v1"
SCHEMA_DECISION = "queuebash.cloud_resource_decision.v1"
SCHEMA_EVENT = "queuebash.cloud_resource_event.v1"
SCHEMA_INVENTORY = "queuebash.cloud_resource_inventory.v1"

cmd = sys.argv[1]
argv = sys.argv[2:]

def parse_common(args):
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument('--registry')
    p.add_argument('--json', action='store_true', dest='json_out')
    ns, rest = p.parse_known_args(args)
    root = Path(ns.registry or os.environ.get('QUEUEBASH_CLOUD_RESOURCE_REGISTRY_RESOLVED') or os.path.expanduser('~/.queuebash/cloud_resources'))
    return ns, rest, root

def ensure(root):
    root.mkdir(parents=True, exist_ok=True)
    for name, default in [('resources.json', []), ('claims.json', [])]:
        path = root / name
        if not path.exists():
            path.write_text(json.dumps(default, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    (root / 'events.jsonl').touch(exist_ok=True)

def load_json(path, default):
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding='utf-8') or json.dumps(default))
    except Exception as e:
        raise SystemExit(f'ERROR: invalid JSON in {path}: {e}')

def save_json(path, data):
    tmp = path.with_suffix(path.suffix + '.tmp')
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    tmp.replace(path)

def event(root, action, **fields):
    rec = {'schema': SCHEMA_EVENT, 'time': int(time.time()), 'action': action}
    rec.update(fields)
    with (root / 'events.jsonl').open('a', encoding='utf-8') as f:
        f.write(json.dumps(rec, sort_keys=True) + '\n')

def emit(obj, code=0, json_out=True):
    if json_out:
        print(json.dumps(obj, sort_keys=True))
    else:
        if isinstance(obj, dict):
            print(obj.get('decision') or obj.get('status') or json.dumps(obj, sort_keys=True))
        else:
            print(obj)
    raise SystemExit(code)

def now():
    return int(time.time())

def active_claims(claims, epoch=None):
    epoch = now() if epoch is None else epoch
    out = []
    for c in claims:
        if c.get('released_at'):
            continue
        if int(c.get('lease_until_epoch') or 0) <= epoch:
            continue
        out.append(c)
    return out

def norm_resource(data):
    rid = data.get('resource_id') or data.get('id') or f"res-{uuid.uuid4().hex[:12]}"
    cap = data.get('capacity') or {}
    labels = data.get('labels') or []
    compliance = data.get('compliance') or data.get('compliance_labels') or []
    classes = data.get('allowed_classes') or []
    if isinstance(labels, str): labels = [labels]
    if isinstance(compliance, str): compliance = [compliance]
    if isinstance(classes, str): classes = [classes]
    out = {
        'schema': SCHEMA_RESOURCE,
        'resource_id': rid,
        'provider': data.get('provider', 'unknown'),
        'resource_type': data.get('resource_type') or data.get('type', 'unknown'),
        'region': data.get('region', 'unknown'),
        'zone': data.get('zone', ''),
        'lifecycle_state': data.get('lifecycle_state', 'available'),
        'status': data.get('status', 'available'),
        'capacity': {
            'cpu': int(cap.get('cpu') or data.get('cpu') or 0),
            'memory_gb': float(cap.get('memory_gb') or cap.get('mem_gb') or data.get('memory_gb') or data.get('mem_gb') or 0),
        },
        'labels': labels,
        'compliance': compliance,
        'allowed_classes': classes,
        'cost': data.get('cost') or {},
        'provenance': data.get('provenance') or {'source': 'file-provider'},
        'last_seen_epoch': int(data.get('last_seen_epoch') or now()),
    }
    for k, v in data.items():
        if k not in out and k not in ('id','type','cpu','memory_gb','mem_gb','compliance_labels'):
            out[k] = v
    return out

def parse_filters(args):
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument('--provider')
    p.add_argument('--type', dest='resource_type')
    p.add_argument('--resource-type', dest='resource_type')
    p.add_argument('--region')
    p.add_argument('--zone')
    p.add_argument('--compliance', action='append', default=[])
    p.add_argument('--label', action='append', default=[])
    p.add_argument('--class', dest='class_name')
    p.add_argument('--min-cpu', type=int, default=0)
    p.add_argument('--min-mem-gb', type=float, default=0)
    return p.parse_known_args(args)

def matches(res, filt, occupied_ids):
    reasons = []
    if res.get('resource_id') in occupied_ids:
        reasons.append('claimed')
    if res.get('status') not in ('available','ready','idle'):
        reasons.append(f"status={res.get('status')}")
    if res.get('lifecycle_state') not in ('available','running','ready','active'):
        reasons.append(f"lifecycle_state={res.get('lifecycle_state')}")
    if filt.provider and res.get('provider') != filt.provider:
        reasons.append('provider_mismatch')
    if filt.resource_type and res.get('resource_type') != filt.resource_type:
        reasons.append('resource_type_mismatch')
    if filt.region and res.get('region') != filt.region:
        reasons.append('region_mismatch')
    if filt.zone and res.get('zone') != filt.zone:
        reasons.append('zone_mismatch')
    labels = set(res.get('labels') or [])
    compliance = set(res.get('compliance') or [])
    for label in filt.label:
        if label not in labels:
            reasons.append(f'label_missing={label}')
    for comp in filt.compliance:
        if comp not in compliance:
            reasons.append(f'compliance_missing={comp}')
    if filt.class_name:
        allowed = res.get('allowed_classes') or []
        if allowed and filt.class_name not in allowed and '*' not in allowed:
            reasons.append('class_not_allowed')
    cap = res.get('capacity') or {}
    if int(cap.get('cpu') or 0) < filt.min_cpu:
        reasons.append('cpu_insufficient')
    if float(cap.get('memory_gb') or 0) < filt.min_mem_gb:
        reasons.append('memory_insufficient')
    return not reasons, reasons

def decision(root, filt, resources, claims):
    occupied = {c.get('resource_id') for c in active_claims(claims)}
    considered = []
    for r in resources:
        ok, reasons = matches(r, filt, occupied)
        considered.append({'resource_id': r.get('resource_id'), 'provider': r.get('provider'), 'resource_type': r.get('resource_type'), 'region': r.get('region'), 'match': ok, 'reasons': reasons[:6]})
        if ok:
            return {
                'schema': SCHEMA_DECISION,
                'decision': 'allow',
                'reason': 'matching_resource_available',
                'resource_id': r.get('resource_id'),
                'provider': r.get('provider'),
                'resource_type': r.get('resource_type'),
                'region': r.get('region'),
                'fail_closed': False,
                'considered': considered,
            }
    return {
        'schema': SCHEMA_DECISION,
        'decision': 'deny',
        'reason': 'no_matching_resource_available',
        'fail_closed': True,
        'considered': considered[:25],
    }

ns, rest, root = parse_common(argv)
if cmd == 'init':
    ensure(root)
    event(root, 'init', registry=str(root))
    emit({'schema': 'queuebash.cloud_resource_registry.v1', 'status': 'ok', 'registry': str(root)}, json_out=ns.json_out or True)

ensure(root)
resources_path = root / 'resources.json'
claims_path = root / 'claims.json'
resources = load_json(resources_path, [])
claims = load_json(claims_path, [])


if cmd == 'self-test':
    # Fast contract exercise in one Python process for CI/sandbox use.
    resources = []
    claims = []
    sample = norm_resource({
        'resource_id': 'selftest-oci-vm-001',
        'provider': 'oci',
        'resource_type': 'vm',
        'region': 'uk-london-1',
        'lifecycle_state': 'running',
        'status': 'available',
        'capacity': {'cpu': 4, 'memory_gb': 16},
        'compliance': ['gdpr', 'uk-dpa'],
        'allowed_classes': ['CLOUD_RESOURCE_GDPR', '*'],
        'provenance': {'source': 'self-test', 'redacted': True},
    })
    resources.append(sample)
    save_json(resources_path, resources)
    filt, _ = parse_filters(['--provider','oci','--resource-type','vm','--region','uk-london-1','--compliance','gdpr','--min-cpu','4','--min-mem-gb','16','--class','CLOUD_RESOURCE_GDPR'])
    dec1 = decision(root, filt, resources, claims)
    if dec1.get('decision') != 'allow':
        emit({'schema': SCHEMA_DECISION, 'decision': 'error', 'reason': 'selftest_availability_failed', 'detail': dec1, 'fail_closed': True}, 1)
    claim_id = f"claim-{uuid.uuid4().hex[:16]}"
    claim = {'schema': SCHEMA_CLAIM, 'claim_id': claim_id, 'resource_id': sample['resource_id'], 'qid': 'SELFTEST-QID-1', 'class_name': 'CLOUD_RESOURCE_GDPR', 'exclusive': True, 'claimed_at_epoch': now(), 'lease_until_epoch': now() + 60, 'provenance': {'provider': 'file'}}
    claims.append(claim)
    save_json(claims_path, claims)
    dec2 = decision(root, filt, resources, claims)
    if dec2.get('decision') != 'deny':
        emit({'schema': SCHEMA_DECISION, 'decision': 'error', 'reason': 'selftest_second_claim_not_blocked', 'detail': dec2, 'fail_closed': True}, 1)
    claim['heartbeat_at_epoch'] = now()
    claim['lease_until_epoch'] = now() + 120
    claim['released_at'] = now()
    claims.append({'schema': SCHEMA_CLAIM, 'claim_id': 'claim-expired-selftest', 'resource_id': sample['resource_id'], 'qid': 'SELFTEST-QID-2', 'class_name': 'CLOUD_RESOURCE_GDPR', 'exclusive': True, 'claimed_at_epoch': now() - 20, 'lease_until_epoch': now() - 10, 'provenance': {'provider': 'file'}})
    expired = []
    for c in claims:
        if not c.get('released_at') and int(c.get('lease_until_epoch') or 0) <= now():
            c['expired_at_epoch'] = now()
            c['released_at'] = now()
            expired.append(c.get('claim_id'))
    save_json(claims_path, claims)
    event(root, 'self-test', resource_id=sample['resource_id'], claim_id=claim_id, expired_claims=expired)
    emit({'schema': 'queuebash.cloud_resource_self_test.v1', 'decision': 'allow', 'reason': 'self_test_passed', 'resource_id': sample['resource_id'], 'claim_id': claim_id, 'blocked_second_claim': True, 'heartbeat': True, 'released': True, 'expired_claims': expired, 'fail_closed': False}, json_out=ns.json_out or True)

if cmd == 'add':
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument('--file', required=True)
    ans, unknown = p.parse_known_args(rest)
    data = json.loads(Path(ans.file).read_text(encoding='utf-8'))
    res = norm_resource(data)
    resources = [r for r in resources if r.get('resource_id') != res['resource_id']]
    resources.append(res)
    save_json(resources_path, resources)
    event(root, 'add', resource_id=res['resource_id'], provider=res['provider'])
    emit({'schema': SCHEMA_RESOURCE, 'status': 'ok', 'resource_id': res['resource_id'], 'provider': res['provider']}, json_out=ns.json_out or True)

if cmd == 'list':
    emit({'schema': SCHEMA_INVENTORY, 'registry': str(root), 'resources': resources, 'active_claims': active_claims(claims)}, json_out=ns.json_out or True)

if cmd == 'show':
    if not rest:
        emit({'schema': SCHEMA_DECISION, 'decision': 'error', 'reason': 'resource_id_required', 'fail_closed': True}, 2)
    rid = rest[0]
    for r in resources:
        if r.get('resource_id') == rid:
            emit(r, json_out=ns.json_out or True)
    emit({'schema': SCHEMA_DECISION, 'decision': 'deny', 'reason': 'resource_not_found', 'resource_id': rid, 'fail_closed': True}, 1)

if cmd in ('check-matching','explain','claim-matching'):
    filt, unknown = parse_filters(rest)
    dec = decision(root, filt, resources, claims)
    if cmd == 'check-matching':
        emit(dec, 0 if dec['decision'] == 'allow' else 1, json_out=ns.json_out or True)
    if cmd == 'explain':
        emit(dec, 0 if dec['decision'] == 'allow' else 1, json_out=ns.json_out or True)
    # claim-matching below
    if dec['decision'] != 'allow':
        emit(dec, 1, json_out=ns.json_out or True)
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument('--qid', required=True)
    p.add_argument('--class', dest='class_name', required=True)
    p.add_argument('--lease-seconds', type=int, default=3600)
    ans, unknown2 = p.parse_known_args(rest)
    rid = dec['resource_id']
    claim_id = f"claim-{uuid.uuid4().hex[:16]}"
    claim = {'schema': SCHEMA_CLAIM, 'claim_id': claim_id, 'resource_id': rid, 'qid': ans.qid, 'class_name': ans.class_name, 'exclusive': True, 'claimed_at_epoch': now(), 'lease_until_epoch': now() + max(ans.lease_seconds, 1), 'provenance': {'provider': 'file'}}
    claims.append(claim)
    save_json(claims_path, claims)
    event(root, 'claim', claim_id=claim_id, resource_id=rid, qid=ans.qid, class_name=ans.class_name)
    emit({'schema': SCHEMA_DECISION, 'decision': 'allow', 'reason': 'resource_claimed', 'claim': claim, 'fail_closed': False}, json_out=ns.json_out or True)

if cmd == 'claim':
    if not rest:
        emit({'schema': SCHEMA_DECISION, 'decision': 'error', 'reason': 'resource_id_required', 'fail_closed': True}, 2)
    rid = rest[0]
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument('--qid', required=True)
    p.add_argument('--class', dest='class_name', required=True)
    p.add_argument('--lease-seconds', type=int, default=3600)
    ans, unknown = p.parse_known_args(rest[1:])
    exists = any(r.get('resource_id') == rid for r in resources)
    if not exists:
        emit({'schema': SCHEMA_DECISION, 'decision': 'deny', 'reason': 'resource_not_found', 'resource_id': rid, 'fail_closed': True}, 1)
    occupied = {c.get('resource_id') for c in active_claims(claims)}
    if rid in occupied:
        emit({'schema': SCHEMA_DECISION, 'decision': 'deny', 'reason': 'resource_already_claimed', 'resource_id': rid, 'fail_closed': True}, 1)
    claim_id = f"claim-{uuid.uuid4().hex[:16]}"
    claim = {'schema': SCHEMA_CLAIM, 'claim_id': claim_id, 'resource_id': rid, 'qid': ans.qid, 'class_name': ans.class_name, 'exclusive': True, 'claimed_at_epoch': now(), 'lease_until_epoch': now() + max(ans.lease_seconds, 1), 'provenance': {'provider': 'file'}}
    claims.append(claim)
    save_json(claims_path, claims)
    event(root, 'claim', claim_id=claim_id, resource_id=rid, qid=ans.qid, class_name=ans.class_name)
    emit({'schema': SCHEMA_DECISION, 'decision': 'allow', 'reason': 'resource_claimed', 'claim': claim, 'fail_closed': False}, json_out=ns.json_out or True)

if cmd == 'heartbeat':
    if not rest:
        emit({'schema': SCHEMA_DECISION, 'decision': 'error', 'reason': 'claim_id_required', 'fail_closed': True}, 2)
    claim_id = rest[0]
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument('--lease-seconds', type=int, default=3600)
    ans, unknown = p.parse_known_args(rest[1:])
    for c in claims:
        if c.get('claim_id') == claim_id and not c.get('released_at'):
            c['lease_until_epoch'] = now() + max(ans.lease_seconds, 1)
            c['heartbeat_at_epoch'] = now()
            save_json(claims_path, claims)
            event(root, 'heartbeat', claim_id=claim_id, resource_id=c.get('resource_id'))
            emit({'schema': SCHEMA_DECISION, 'decision': 'allow', 'reason': 'claim_heartbeat_recorded', 'claim': c, 'fail_closed': False}, json_out=ns.json_out or True)
    emit({'schema': SCHEMA_DECISION, 'decision': 'deny', 'reason': 'claim_not_found', 'claim_id': claim_id, 'fail_closed': True}, 1)

if cmd == 'release':
    if not rest:
        emit({'schema': SCHEMA_DECISION, 'decision': 'error', 'reason': 'claim_id_required', 'fail_closed': True}, 2)
    claim_id = rest[0]
    for c in claims:
        if c.get('claim_id') == claim_id and not c.get('released_at'):
            c['released_at'] = now()
            save_json(claims_path, claims)
            event(root, 'release', claim_id=claim_id, resource_id=c.get('resource_id'))
            emit({'schema': SCHEMA_DECISION, 'decision': 'allow', 'reason': 'claim_released', 'claim_id': claim_id, 'fail_closed': False}, json_out=ns.json_out or True)
    emit({'schema': SCHEMA_DECISION, 'decision': 'deny', 'reason': 'claim_not_found_or_already_released', 'claim_id': claim_id, 'fail_closed': True}, 1)

def load_observation_resources(path):
    try:
        data = json.loads(Path(path).read_text(encoding='utf-8'))
    except Exception as e:
        raise SystemExit(f'ERROR: invalid observation JSON in {path}: {e}')
    if isinstance(data, dict):
        if isinstance(data.get('resources'), list):
            data = data['resources']
        elif data.get('schema') == SCHEMA_RESOURCE or data.get('resource_id') or data.get('id'):
            data = [data]
        else:
            raise SystemExit(f'ERROR: observation file {path} must contain a resource object or resources list')
    if not isinstance(data, list):
        raise SystemExit(f'ERROR: observation file {path} must contain a resource object or resources list')
    return [norm_resource(item) for item in data]

if cmd == 'reconcile':
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument('--observations')
    p.add_argument('--stale-after-seconds', type=int, default=0)
    p.add_argument('--mark-missing-stale', action='store_true')
    ans, unknown = p.parse_known_args(rest)
    epoch = now()
    expired = []
    suspect = []
    stale_resources = []
    observed_resources = []
    added_resources = []
    updated_resources = []
    missing_resources = []

    observed = []
    observed_ids = set()
    observed_providers = set()
    if ans.observations:
        observed = load_observation_resources(ans.observations)
        by_id = {r.get('resource_id'): dict(r) for r in resources}
        for obs in observed:
            rid = obs.get('resource_id')
            if not rid:
                continue
            observed_ids.add(rid)
            if obs.get('provider'):
                observed_providers.add(obs.get('provider'))
            if rid in by_id:
                old = by_id[rid]
                merged = dict(old)
                merged.update(obs)
                merged['last_seen_epoch'] = int(obs.get('last_seen_epoch') or epoch)
                merged.setdefault('provenance', {})
                if isinstance(merged.get('provenance'), dict):
                    merged['provenance']['reconcile_source'] = 'observation_file'
                by_id[rid] = merged
                updated_resources.append(rid)
            else:
                obs['last_seen_epoch'] = int(obs.get('last_seen_epoch') or epoch)
                obs.setdefault('provenance', {'source': 'observation_file'})
                if isinstance(obs.get('provenance'), dict):
                    obs['provenance'].setdefault('source', 'observation_file')
                    obs['provenance']['reconcile_source'] = 'observation_file'
                by_id[rid] = obs
                added_resources.append(rid)
        resources = list(by_id.values())
        observed_resources = sorted(observed_ids)

        if ans.mark_missing_stale:
            for r in resources:
                rid = r.get('resource_id')
                if rid in observed_ids:
                    continue
                # Only mark resources from providers represented by this observation set.
                # This prevents an AWS observation file from making OCI/IBM/Azure/GCP stale.
                if observed_providers and r.get('provider') not in observed_providers:
                    continue
                if r.get('status') != 'stale' or r.get('lifecycle_state') != 'stale':
                    r['status'] = 'stale'
                    r['lifecycle_state'] = 'stale'
                    r['missing_at_epoch'] = epoch
                    r['stale_reason'] = 'not_in_observation_set'
                    missing_resources.append(rid)
                    stale_resources.append(rid)

    if ans.stale_after_seconds and ans.stale_after_seconds > 0:
        cutoff = epoch - ans.stale_after_seconds
        for r in resources:
            rid = r.get('resource_id')
            if int(r.get('last_seen_epoch') or 0) < cutoff:
                if r.get('status') != 'stale' or r.get('lifecycle_state') != 'stale':
                    r['status'] = 'stale'
                    r['lifecycle_state'] = 'stale'
                    r['stale_at_epoch'] = epoch
                    r['stale_reason'] = 'last_seen_too_old'
                    stale_resources.append(rid)

    resource_ids = {r.get('resource_id') for r in resources}
    resource_by_id = {r.get('resource_id'): r for r in resources}
    for c in claims:
        if c.get('released_at'):
            continue
        if int(c.get('lease_until_epoch') or 0) <= epoch:
            c['expired_at_epoch'] = epoch
            c['released_at'] = epoch
            expired.append(c.get('claim_id'))
            continue
        rid = c.get('resource_id')
        res = resource_by_id.get(rid)
        if rid not in resource_ids:
            c['suspect_at_epoch'] = epoch
            c['suspect_reason'] = 'resource_missing'
            suspect.append(c.get('claim_id'))
        elif res and (res.get('status') == 'stale' or res.get('lifecycle_state') == 'stale'):
            c['suspect_at_epoch'] = epoch
            c['suspect_reason'] = 'resource_stale'
            suspect.append(c.get('claim_id'))

    save_json(resources_path, resources)
    save_json(claims_path, claims)
    event(root, 'reconcile', expired_claims=expired, suspect_claims=suspect, stale_resources=stale_resources, observed_resources=observed_resources, cloud_mutation=False)
    emit({
        'schema': 'queuebash.cloud_resource_reconcile.v1',
        'decision': 'allow',
        'reason': 'reconciled',
        'expired_claims': sorted(expired),
        'suspect_claims': sorted(set(suspect)),
        'stale_resources': sorted(set(stale_resources)),
        'observed_resources': sorted(observed_resources),
        'added_resources': sorted(added_resources),
        'updated_resources': sorted(updated_resources),
        'missing_resources': sorted(set(missing_resources)),
        'registry_mutation': 'local_only',
        'live': False,
        'cloud_mutation': False,
        'fail_closed': False,
    }, json_out=ns.json_out or True)

emit({'schema': SCHEMA_DECISION, 'decision': 'error', 'reason': f'unsupported_command:{cmd}', 'fail_closed': True}, 2)
PY
