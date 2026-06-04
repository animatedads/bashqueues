#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Bob23 guard: _queue_init should seed bundled classes/assets/policies once
# per root/version. Worker/startup paths must not rescan the whole bundled tree
# before finalising the Karen first-job path.
grep -Fq 'local bundle_stamp="$root/.queuebash_bundled_install_version"' queuebash.sh
grep -Fq 'QUEUEBASH_BUNDLED_INSTALL_MODE:-once-per-version' queuebash.sh
grep -Fq '"$QUEUEBASH_VERSION" > "$bundle_stamp"' queuebash.sh

echo '[PASS] bundled init stamp static guard passes'
