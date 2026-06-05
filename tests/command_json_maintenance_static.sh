#!/usr/bin/env bash
set -euo pipefail
q=queuebash.sh
grep -q 'queuebash.command_result.v1.*clean-logs' "$q"
grep -q 'command":"backup' "$q"
grep -q 'command":"reevaluate' "$q"
grep -q 'command":"%s".*target":"logs' "$q"
grep -q 'compress-logs|gzip-logs)' "$q"
grep -q -- '--json|-j) json_output=1' "$q"
echo PASS command_json_maintenance_static
