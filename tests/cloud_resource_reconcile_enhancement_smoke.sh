#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }
PROVIDER="$ROOT/providers.d/cloud_resource/cloud_resource_provider.sh"
REG="$(mktemp -d)"
TMP="$(mktemp -d)"
trap 'rm -rf "$REG" "$TMP"' EXIT

"$PROVIDER" init --registry "$REG" --json >/dev/null
cat > "$TMP/old.json" <<'JSON'
{
  "schema": "queuebash.cloud_resource.v1",
  "resource_id": "aws-old-001",
  "provider": "aws",
  "resource_type": "vm",
  "region": "eu-west-2",
  "status": "available",
  "lifecycle_state": "running",
  "last_seen_epoch": 1,
  "capacity": {"cpu": 2, "memory_gb": 8},
  "compliance": ["gdpr"],
  "allowed_classes": ["*"]
}
JSON
"$PROVIDER" add --file "$TMP/old.json" --registry "$REG" --json >/dev/null
claim_out="$($PROVIDER claim aws-old-001 --qid QID-RECON-1 --class CLOUD_AWS_GDPR --lease-seconds 3600 --registry "$REG" --json)"
grep -q 'resource_claimed' <<<"$claim_out" || fail "initial claim failed"
cat > "$TMP/observed.json" <<'JSON'
{
  "resources": [
    {
      "schema": "queuebash.cloud_resource.v1",
      "resource_id": "aws-new-001",
      "provider": "aws",
      "resource_type": "vm",
      "region": "eu-west-2",
      "status": "available",
      "lifecycle_state": "running",
      "capacity": {"cpu": 4, "memory_gb": 16},
      "compliance": ["gdpr"],
      "allowed_classes": ["*"]
    }
  ]
}
JSON
out="$($PROVIDER reconcile --observations "$TMP/observed.json" --mark-missing-stale --registry "$REG" --json)"
grep -q '"added_resources"' <<<"$out" || fail "added_resources missing"
grep -q 'aws-new-001' <<<"$out" || fail "new observed resource not reported"
grep -q 'aws-old-001' <<<"$out" || fail "missing old resource not reported"
grep -q '"suspect_claims"' <<<"$out" || fail "suspect_claims missing"
grep -q '"cloud_mutation": false\|"cloud_mutation":false' <<<"$out" || fail "cloud_mutation false missing"
grep -q '"live": false\|"live":false' <<<"$out" || fail "live false missing"
show_old="$($PROVIDER show aws-old-001 --registry "$REG" --json)"
grep -q '"status": "stale"\|"status":"stale"' <<<"$show_old" || fail "old missing resource not marked stale"
show_new="$($PROVIDER show aws-new-001 --registry "$REG" --json)"
grep -q '"status": "available"\|"status":"available"' <<<"$show_new" || fail "new observed resource not available"
echo '[PASS] cloud resource reconcile enhancement smoke checks pass'
