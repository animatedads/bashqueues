#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }
PROVIDER="providers.d/cloud_resource/cloud_resource_provider.sh"
DOC="docs/CLOUD_RESOURCE_RECONCILE_ENHANCEMENT.md"
[[ -f "$DOC" ]] || fail "missing reconcile enhancement doc"
[[ -x "$PROVIDER" || -f "$PROVIDER" ]] || fail "missing cloud_resource provider"
grep -q -- '--observations' "$PROVIDER" || fail "reconcile observations option missing"
grep -q -- '--mark-missing-stale' "$PROVIDER" || fail "mark missing stale option missing"
grep -q -- '--stale-after-seconds' "$PROVIDER" || fail "stale-after-seconds option missing"
grep -q 'suspect_claims' "$PROVIDER" || fail "suspect claims output missing"
grep -q 'cloud_mutation.*False' "$PROVIDER" || fail "cloud_mutation false evidence missing"
grep -q 'queuebash.cloud_resource_reconcile.v1' "$PROVIDER" || fail "reconcile schema missing"
grep -q 'local registry operation' "$DOC" || fail "doc does not state local registry boundary"
grep -q 'not provisioning and not scheduling' "$DOC" || fail "doc missing no scheduling boundary"
echo '[PASS] cloud resource reconcile enhancement static checks pass'
