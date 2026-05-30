#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q 'patchset inspect' queuebash.sh
grep -q 'missing_baseline_md5' queuebash.sh
grep -q 'new_or_unbaselined_file' queuebash.sh
grep -q 'queuebash.dev_patchset.inspect.v1' queuebash.sh
grep -q 'QUEUE_DEV_PATCHSET_HARDENING' < <(find docs -maxdepth 1 -name 'QUEUE_DEV_PATCHSET_HARDENING.md' -print)
grep -q 'queue dev patchset inspect' docs/QUEUE_DEV_PATCHSET_HARDENING.md
