#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

grep -q 'queuebash.command_result.v1' queuebash.sh
grep -q 'Usage: queue pids <qid-or-exact-job-name> \[--json\]' queuebash.sh
grep -q 'Usage: queue metrics <qid-or-exact-job-name> \[--json\]' queuebash.sh
grep -q 'Usage: queue hooks <qid-or-exact-job-name> \[--json\]' queuebash.sh
grep -q 'Usage: queue .*\[--dryrun\] \[--json\] -- <command' queuebash.sh
grep -q 'no_systemd_unit' queuebash.sh
grep -q 'systemd_active' queuebash.sh
grep -q 'ON_SUCCESS' queuebash.sh

echo "PASS command_json_diagnostics_hooks_static"
