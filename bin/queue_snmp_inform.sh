#!/usr/bin/env bash
# Send a strictly typed bashqueues SNMP INFORM notification.
#
# Usage:
#   queue_snmp_inform.sh <NMS_HOST> <COMMUNITY> [TRAP_OID]
#
# Environment consumed:
#   JOB_NAME
#   JOB_ID
#   JOB_SNMP_STATE_INT   1=failed, 2=pol_block, 3=security_cap_tripped, 4=auth_tampered
#   JOB_EXIT_REASON
#
# This helper is deliberately standalone so it can be used from ON_FAILURE,
# site-local event hooks, or external monitoring glue without requiring the
# queue engine to know the local NMS topology.

set -euo pipefail

usage() {
    cat >&2 <<'USAGE'
usage: queue_snmp_inform.sh <NMS_HOST> <COMMUNITY> [TRAP_OID]

Sends an SNMP v2c INFORM with strict varbind types:
  .1  bashqueuesJobName        OctetString
  .2  bashqueuesJobId          OctetString
  .3  bashqueuesTerminalState  Integer32
  .4  bashqueuesReason         OctetString

JOB_SNMP_STATE_INT values:
  1 failed
  2 pol_block
  3 security_cap_tripped
  4 auth_tampered
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

if (($# < 2 || $# > 3)); then
    usage
    exit 2
fi

nms="$1"
community="$2"
trap_oid="${3:-.1.3.6.1.4.1.99999.1}"
state_int="${JOB_SNMP_STATE_INT:-1}"

if ! command -v snmpinform >/dev/null 2>&1; then
    echo "queue_snmp_inform: tool_missing=snmpinform" >&2
    exit 127
fi

if [[ -z "$nms" || -z "$community" ]]; then
    echo "queue_snmp_inform: NMS host and community are required" >&2
    exit 2
fi

if [[ ! "$state_int" =~ ^[0-9]+$ ]]; then
    echo "queue_snmp_inform: JOB_SNMP_STATE_INT must be an integer" >&2
    exit 2
fi

snmpinform -v2c -c "$community" "$nms" 0 "$trap_oid" \
    "${trap_oid}.1" s "${JOB_NAME:-unknown}" \
    "${trap_oid}.2" s "${JOB_ID:-unknown}" \
    "${trap_oid}.3" i "$state_int" \
    "${trap_oid}.4" s "${JOB_EXIT_REASON:-none}"
