#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q '_queue_lock_tree_prepare()' queuebash.sh
grep -q '_queue_lock_tree_writable()' queuebash.sh
grep -q 'state_lock_permission_denied' queuebash.sh
grep -q 'locks/state' queuebash.sh
grep -q 'logs/queue-state-reconcile' queuebash.sh
grep -q '_queue_lock_tree_prepare "$root"' queuebash.sh
