#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source assets.d/snmp.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/snmpget" <<'FAKE'
#!/usr/bin/env bash
case "${SNMP_FAKE_VALUE:-45}" in
  FAIL) echo "Timeout: No Response" >&2; exit 1 ;;
  *) printf '%s\n' "$SNMP_FAKE_VALUE" ;;
esac
FAKE
chmod +x "$tmp/snmpget"
PATH="$tmp:$PATH"

SNMP_FAKE_VALUE=45 queue_asset_check_snmp_int_below "10.0.0.5" oid=.1 max=80 comm=monitor > "$tmp/below.out"
grep -q 'asset_check_ok: snmp:int_below' "$tmp/below.out" || { cat "$tmp/below.out" >&2; exit 1; }

if SNMP_FAKE_VALUE=99 queue_asset_check_snmp_int_below "10.0.0.5" oid=.1 max=80 > "$tmp/below_block.out" 2>&1; then
    echo "int_below should block when value exceeds max" >&2
    exit 1
fi
grep -q 'asset_check_blocked: snmp:int_below' "$tmp/below_block.out" || { cat "$tmp/below_block.out" >&2; exit 1; }

if SNMP_FAKE_VALUE='No Such Instance currently exists' queue_asset_check_snmp_int_above "10.0.0.5" oid=.1 min=10 > "$tmp/type.out" 2>&1; then
    echo "int_above should block on non-integer SNMP value" >&2
    exit 1
fi
grep -q 'invalid_smi_type_returned' "$tmp/type.out" || { cat "$tmp/type.out" >&2; exit 1; }

SNMP_FAKE_VALUE='"Active"' queue_asset_check_snmp_string_match "10.0.0.5" oid=.1 expect_str=Active match=exact > "$tmp/string.out"
grep -q 'asset_check_ok: snmp:string_match' "$tmp/string.out" || { cat "$tmp/string.out" >&2; exit 1; }

cat > "$tmp/snmpinform" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${SNMP_INFORM_CAPTURE:?}"
FAKE
chmod +x "$tmp/snmpinform"
SNMP_INFORM_CAPTURE="$tmp/inform.args" JOB_NAME=job JOB_ID=qid JOB_SNMP_STATE_INT=2 JOB_EXIT_REASON=pol_blocked \
    bin/queue_snmp_inform.sh 10.0.0.250 alerts .1.3.6.1.4.1.99999.1

grep -q '.1.3.6.1.4.1.99999.1.3 i 2' "$tmp/inform.args" || { cat "$tmp/inform.args" >&2; exit 1; }
grep -q '.1.3.6.1.4.1.99999.1.4 s pol_blocked' "$tmp/inform.args" || { cat "$tmp/inform.args" >&2; exit 1; }

echo "[PASS] SNMP assets validate values and SNMP inform emits typed varbinds"
