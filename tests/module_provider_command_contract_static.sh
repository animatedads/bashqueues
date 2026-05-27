#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }
cd "$(dirname "$0")/.."

grep -q 'QUEUEBASH_VERSION="0.18.11"' queuebash.sh || fail 'version not bumped to 0.18.11'
grep -q '0.18.5 - module provider command contract' CHANGELOG.md || fail 'changelog entry missing'
grep -q 'provider|providers' queuebash.sh || fail 'provider module kind missing'
grep -q '_queue_module_help' queuebash.sh || fail 'module help function missing'
grep -q '_queue_module_configure' queuebash.sh || fail 'module configure function missing'
grep -q '_queue_module_policy' queuebash.sh || fail 'module policy function missing'
grep -q '_queue_module_acl' queuebash.sh || fail 'module acl handoff function missing'
grep -q 'policy/providers.d' queuebash.sh || fail 'provider module path missing'
grep -q 'queue module configure provider' docs/MODULE_PROVIDER_CONTRACT.md || fail 'module provider docs missing configure command'
grep -q 'queue acl set module' docs/MODULE_PROVIDER_CONTRACT.md || fail 'ACL handoff docs missing'
grep -q 'Provider output is data, never shell' README.md || fail 'README provider safety wording missing'
! grep -R '/etc/bashqueues' docs/MODULE_PROVIDER_CONTRACT.md >/dev/null || fail 'legacy /etc/bashqueues namespace found'

echo PASS
