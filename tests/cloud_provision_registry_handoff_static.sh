#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL $*" >&2; exit 1; }
require_grep(){ grep -q "$1" "$2" || fail "missing '$1' in $2"; }

[ -f providers.d/cloud_provision/cloud_provision.sh ] || fail 'missing cloud_provision provider'
[ -f docs/CLOUD_PROVISIONING_REGISTRY_HANDOFF_CONTROLLED.md ] || fail 'missing registry handoff doc'

bash -n providers.d/cloud_provision/cloud_provision.sh || fail 'cloud_provision bash -n failed'
require_grep 'registry-handoff' providers.d/cloud_provision/cloud_provision.sh
require_grep 'handoff-explain' providers.d/cloud_provision/cloud_provision.sh
require_grep 'queuebash.cloud_provision.registry_handoff.v1' providers.d/cloud_provision/cloud_provision.sh
require_grep 'queuebash.cloud_provision.handoff_explain.v1' providers.d/cloud_provision/cloud_provision.sh
require_grep 'registry_handoff_state' providers.d/cloud_provision/cloud_provision.sh
require_grep 'cloud_mutation' providers.d/cloud_provision/cloud_provision.sh
require_grep 'not-claimable' providers.d/cloud_provision/cloud_provision.sh

if grep -R 'run-instances\|oci compute instance launch\|az vm create\|gcloud compute instances create\|ibmcloud is instance-create' providers.d/cloud_provision >/dev/null 2>&1; then
  fail 'cloud_provision contains live create command text'
fi
if grep -R 'queue cloud-provision\|_queue_cloud_provision' queuebash.sh providers.d/cloud_provision >/dev/null 2>&1; then
  fail 'cloud_provision unexpectedly wired into queuebash dispatcher'
fi

echo 'PASS cloud_provision_registry_handoff_static'
