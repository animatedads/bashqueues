#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q 'queue dev files begin|finish|add|remove|list|changed|scan|path' queuebash.sh
grep -q 'queue dev patchset create --output ZIP' queuebash.sh
grep -q 'queue dev files scan' docs/QUEUE_DEV_FILE_REGISTRY.md
grep -q '_queue_dev_file_registry_command' queuebash.sh
grep -q '_queue_dev_patchset_command' queuebash.sh
grep -q 'queuebash.dev_file_registry.v1' queuebash.sh
grep -q 'queuebash.dev_patchset.v1' queuebash.sh
grep -q 'old_md5' queuebash.sh
grep -q 'new_md5' queuebash.sh
grep -q 'check_preconditions.py' queuebash.sh
test -f docs/QUEUE_DEV_FILE_REGISTRY.md
test -f docs/QUEUE_DEV_PATCHSET_EXPORT.md
test -f schemas/dev_workflow/file_registry.example.json
test -f schemas/dev_workflow/patchset.example.json
echo "PASS dev_file_registry_static"
