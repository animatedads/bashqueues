#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }
canonical='/etc/queuebash/policies.d'
legacy='/etc/bashqueues/policies.d'

[[ -f queuebash.sh ]] || fail 'run from repository root'

grep -q 'QUEUEBASH_VERSION="0.18.113"' queuebash.sh || fail 'version not advanced to 0.18.113'
grep -q "$canonical" docs/SYSTEM_INSTALL.md || fail 'system install docs missing canonical policy root'
grep -q "$canonical" tests/policy_namespace_consistency_static.sh || fail 'namespace consistency test missing canonical root'

scan_paths=(
  assets.d
  policies.d
  resources.d/display
  systemd
  testr/assets.d
  testr/policies.d
  tests/fixtures/remote_admin
)

for p in "${scan_paths[@]}"; do
  [[ -e "$p" ]] || continue
  if grep -R "$legacy" -n "$p"; then
    fail "legacy policy root remains in live operator/template path: $p"
  fi
done

# The remote-management service and examples are the highest-risk operator copy/paste paths.
grep -q "$canonical/remote-queue/remote-management.env" systemd/bashqueues-remote-management.service || fail 'remote-management systemd unit not canonical'
grep -q "$canonical/remote-queue/remote-management.env" policies.d/remote-queue/remote-management.env.example || fail 'remote-management example not canonical'
grep -q "$canonical/ai-profiles" resources.d/display/lang_eng/ai-help.txt || fail 'AI help resource not canonical'

printf '[PASS] residual policy namespace path sweep static contract\n'
