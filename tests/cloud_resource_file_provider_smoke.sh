#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }
PROVIDER="$ROOT/providers.d/cloud_resource/cloud_resource_provider.sh"
REG="$(mktemp -d)"
trap 'rm -rf "$REG"' EXIT

out="$($PROVIDER self-test --registry "$REG" --json)"
grep -q '"reason": "self_test_passed"\|"reason":"self_test_passed"' <<<"$out" || fail 'provider self-test failed'
grep -q '"blocked_second_claim": true\|"blocked_second_claim":true' <<<"$out" || fail 'second claim was not blocked in self-test'
grep -q 'claim-expired-selftest' <<<"$out" || fail 'stale claim was not expired in self-test'
"$PROVIDER" list --registry "$REG" --json | grep -q 'queuebash.cloud_resource_inventory.v1' || fail 'list schema missing after self-test'
QUEUEBASH_CLOUD_RESOURCE_PROVIDER_SCRIPT="$PROVIDER" bash -c 'source assets.d/cloud_resource.sh; queue_asset_check_cloud_resource_available tok oci type=vm region=uk-london-1 compliance=gdpr class=CLOUD_RESOURCE_GDPR min_cpu=4 min_mem_gb=16 registry="'$REG'"' | grep -q 'asset_check_ok' || fail 'asset availability check failed'

echo '[PASS] cloud resource file provider smoke checks pass'
