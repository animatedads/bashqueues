#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source assets.d/snmp.sh

facilities="$(queue_asset_facilities)"
hints="$(queue_asset_hints)"

for token in \
  snmp:int_below \
  snmp:int_above \
  snmp:truth_ok \
  snmp:string_match
 do
    grep -q "^${token}[[:space:]]" <<< "$facilities" || { echo "missing facility $token" >&2; exit 1; }
    grep -q "^${token}[[:space:]]" <<< "$hints" || { echo "missing hint $token" >&2; exit 1; }
    func="queue_asset_check_${token//:/_}"
    declare -F "$func" >/dev/null || { echo "missing check function $func" >&2; exit 1; }
 done

grep -q -- '-Oqv' assets.d/snmp.sh || { echo "snmpget must use -Oqv" >&2; exit 1; }
grep -q 'tool_missing=snmpget' assets.d/snmp.sh || { echo "missing snmpget tool_missing handling" >&2; exit 1; }
grep -q 'invalid_smi_type_returned' assets.d/snmp.sh || { echo "missing SMI type validation failure" >&2; exit 1; }
grep -q 'snmpinform' bin/queue_snmp_inform.sh || { echo "missing SNMP inform helper" >&2; exit 1; }

echo "[PASS] SNMP asset and NMS inform helper are wired"
