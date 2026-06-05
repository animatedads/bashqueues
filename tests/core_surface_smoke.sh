#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "FAIL core_surface_smoke: $*" >&2; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$tmp/root"
mkdir -p "$QUEUEBASH_ROOT/classes"
printf 'CLASS_ALLOW_PARALLEL=1\nCLASS_MAX_CONCURRENT=0\n' > "$QUEUEBASH_ROOT/classes/DEFAULT.env"
printf '0.18.123\n' > "$QUEUEBASH_ROOT/.queuebash_bundled_install_version"
source ./queuebash.sh >/dev/null
for fn in _queue_dev_command _queue_remote_admin_command _queue_cloud_command _queue_cloud_signals_command _queue_secrets_command _queue_vcs_command _queue_cluster_command _queue_plan_command _queue_enterprise_command; do
  type "$fn" >/dev/null 2>&1 || fail "missing loaded function $fn"
done
for cmd in \
  'queue cloud --help' \
  'queue cloud-signals --help' \
  'queue secrets --help' \
  'queue dev --help' \
  'queue remote-admin --help' \
  'queue vcs --help' \
  'queue cluster help' \
  'queue plan help' \
  'queue enterprise help' \
  'queue policy paths --json'; do
  if ! timeout 20s bash -lc "cd '$PWD'; export QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_ROOT='$QUEUEBASH_ROOT'; source ./queuebash.sh >/dev/null; $cmd" >/tmp/core_surface_smoke.out 2>/tmp/core_surface_smoke.err; then
    cat /tmp/core_surface_smoke.out >&2 || true
    cat /tmp/core_surface_smoke.err >&2 || true
    fail "command failed: $cmd"
  fi
  if grep -q 'command not found' /tmp/core_surface_smoke.out /tmp/core_surface_smoke.err 2>/dev/null; then
    cat /tmp/core_surface_smoke.out >&2 || true
    cat /tmp/core_surface_smoke.err >&2 || true
    fail "command-not-found from: $cmd"
  fi
done
echo 'PASS core_surface_smoke'
