#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
fail(){ echo "FAIL queue_dev_core_surface_static: $*" >&2; exit 1; }
for fn in \
  _queue_dev_usage \
  _queue_dev_functions \
  _queue_dev_locate \
  _queue_dev_extract \
  _queue_dev_scope \
  _queue_dev_patch \
  _queue_dev_diff \
  _queue_dev_symbols \
  _queue_dev_flow \
  _queue_dev_splice \
  _queue_dev_scratchpad_command \
  _queue_dev_test_command \
  _queue_dev_file_registry_command \
  _queue_dev_patchset_command \
  _queue_dev_merge_plan_command \
  _queue_dev_validate_command \
  _queue_dev_scope_check_command \
  _queue_dev_resource_command; do
  grep -q "^${fn}()" queuebash.sh || fail "missing queue dev function: $fn"
done
for dispatch in \
  'functions|list) _queue_dev_functions' \
  'extract) _queue_dev_extract' \
  'patchset) _queue_dev_patchset_command' \
  'merge-plan|mergeplan) _queue_dev_merge_plan_command' \
  'validate) _queue_dev_validate_command'; do
  grep -qF "$dispatch" queuebash.sh || fail "missing queue dev dispatcher: $dispatch"
done
bash -n queuebash.sh
QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -c 'source ./queuebash.sh; queue dev functions --file queuebash.sh | grep -q "^_queue_dev_functions"'
QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -c 'source ./queuebash.sh; queue dev extract _queue_remote_admin_command --file queuebash.sh | grep -q "_queue_remote_admin_command"'
echo 'PASS queue_dev_core_surface_static'
