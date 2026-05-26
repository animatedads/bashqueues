#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source assets.d/snmp.sh

grep -q '/etc/bashqueues/snmp-map.env' assets.d/snmp.sh || { echo "missing /etc SNMP map path" >&2; exit 1; }
grep -q '/etc/bashqueues/snmp.d/default.env' assets.d/snmp.sh || { echo "missing /etc SNMP map directory path" >&2; exit 1; }
grep -q 'policies.d/snmp-map/default.env' assets.d/snmp.sh || { echo "missing queue/bundled SNMP map path" >&2; exit 1; }
grep -q 'SNMP_MAP_' assets.d/snmp.sh && grep -q 'OID' assets.d/snmp.sh || { echo "missing SNMP_MAP alias OID lookup" >&2; exit 1; }
grep -q 'SNMP_MAP_SAN_CPU_TARGET' policies.d/snmp-map/default.env || { echo "missing example SAN_CPU map entry" >&2; exit 1; }
grep -q 'SNMP map' docs/SNMP_INTEGRATION.md || { echo "missing SNMP map docs" >&2; exit 1; }
grep -q 'SAN_CPU' README.md || { echo "missing README alias example" >&2; exit 1; }

echo "[PASS] SNMP central map alias support is wired"
