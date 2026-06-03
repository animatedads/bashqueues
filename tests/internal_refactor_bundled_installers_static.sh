#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q '_queue_resolve_bundled_source_dir()' queuebash.sh || fail 'missing bundled source resolver helper'
grep -q '_queue_install_bundled_flat_files()' queuebash.sh || fail 'missing bundled flat install helper'
grep -q '_queue_install_bundled_classes()' queuebash.sh || fail 'missing class installer wrapper'
grep -q '_queue_install_bundled_env_profiles()' queuebash.sh || fail 'missing env installer wrapper'
grep -q '_queue_install_bundled_asset_plugins()' queuebash.sh || fail 'missing asset installer wrapper'
grep -q '_queue_install_bundled_reporter_plugins()' queuebash.sh || fail 'missing reporter installer wrapper'
grep -q '_queue_install_bundled_cap_plugins()' queuebash.sh || fail 'missing cap installer wrapper'
grep -q '_queue_install_bundled_policies()' queuebash.sh || fail 'missing policy installer wrapper'
grep -q '_queue_prune_obsolete_asset_plugins' queuebash.sh || fail 'obsolete asset pruning lost'
grep -q 'net_usage' queuebash.sh || fail 'net_usage obsolete marker lost'

echo 'PASS internal refactor bundled installers static'
