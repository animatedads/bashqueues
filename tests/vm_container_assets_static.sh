#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

for t in \
  tests/asset_docker_static.sh \
  tests/asset_k8s_static.sh \
  tests/asset_vm_static.sh \
  tests/asset_lxc_static.sh \
  tests/asset_vsphere_static.sh \
  tests/asset_vagrant_static.sh; do
    bash "$t"
done

out="$(QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -c 'source ./queuebash.sh >/dev/null; queue assets list --json')"
for facility in \
  docker:running docker:no_privileged \
  k8s:reachable k8s:no_crashlooping \
  vm:running vm:snapshot_exists \
  lxc:running lxc:storage_pool_ok \
  vsphere:vm_running vsphere:datastore_free \
  vagrant:running vagrant:box_outdated; do
    grep -q '"facility":"'"$facility"'"' <<<"$out" || { echo "[FAIL] missing facility in queue assets list --json: $facility" >&2; exit 1; }
done

if grep -qiE 'authenticity of host|are you sure you want to continue|asset_check_blocked|asset_check_ok' <<<"$out"; then
    echo "[FAIL] queue assets list --json appears to have executed a live VM/container check" >&2
    echo "$out" >&2
    exit 1
fi

[[ ! -e assets.d/net_usage.sh ]] || { echo "[FAIL] assets.d/net_usage.sh must remain absent" >&2; exit 1; }

echo "[PASS] VM/container assets are published through metadata-only JSON discovery"
