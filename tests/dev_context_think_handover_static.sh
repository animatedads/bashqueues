#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh
grep -q 'queue dev context' queuebash.sh
grep -q 'queue dev think' queuebash.sh
grep -q 'queue dev handover' queuebash.sh
grep -q '_queue_dev_context_command' queuebash.sh
grep -q '_queue_dev_think_command' queuebash.sh
grep -q '_queue_dev_handover_command' queuebash.sh
grep -q 'queuebash.dev_workflow.context.v1' queuebash.sh
grep -q 'queuebash.dev_workflow.think.v1' queuebash.sh
grep -q 'queuebash.dev_workflow.handover.v1' queuebash.sh

test -f docs/QUEUE_DEV_CONTEXT_THINK_HANDOVER.md
grep -q 'queue dev context' docs/QUEUE_DEV_CONTEXT_THINK_HANDOVER.md
grep -q 'queue dev think' docs/QUEUE_DEV_CONTEXT_THINK_HANDOVER.md
grep -q 'queue dev handover' docs/QUEUE_DEV_CONTEXT_THINK_HANDOVER.md

echo PASS dev_context_think_handover_static
