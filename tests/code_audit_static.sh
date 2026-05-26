#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q '_queue_code_audit_command()' queuebash.sh
grep -q 'audit|components|inventory)' queuebash.sh
grep -q 'Usage: queue code sign|verify|audit|trust|policy' queuebash.sh
# Installer must not copy operator-local publish helper into system share.
grep -q 'publish_to_github.sh is a local/operator helper' install-system.sh
grep -q 'rm -f -- "\$share_dir/publish_to_github.sh"' install-system.sh
if grep -q 'for item in .*publish_to_github.sh' install-system.sh; then
  echo 'publish_to_github.sh must not be included in the install-core item loop' >&2
  exit 1
fi
# Generated trusted key policy line must keep the hash inside an assignment.
grep -q 'QUEUEBASH_CODE_TRUSTED_PUBLIC_KEY_SHA256S=\\"${existing} ${sha}\\"' install-system.sh
printf '[PASS] code audit command and installer policy quoting are present\n'
