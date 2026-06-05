#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'queuebash.health.v1' queuebash.sh
grep -q '_queue_health_report_json_from_text' queuebash.sh
grep -q '_queue_health_report_json_usage_error' queuebash.sh
grep -q '_queue_health_report_text' queuebash.sh
grep -q -- '--json|-j' queuebash.sh
bash -n queuebash.sh
