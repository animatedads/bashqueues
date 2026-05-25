#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source assets.d/snmp.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/q/policies.d/snmp-map"
cat > "$tmp/q/policies.d/snmp-map/default.env" <<'MAP'
SNMP_MAP_SAN_CPU_TARGET="10.0.0.5"
SNMP_MAP_SAN_CPU_OID=".1.3.6.1.4.1.2021.11.9.0"
SNMP_MAP_SAN_CPU_COMM="monitor"
SNMP_MAP_SAN_CPU_V="2c"
SNMP_MAP_SAN_CPU_TIMEOUT="2"
SNMP_MAP_SAN_CPU_RETRIES="0"
SNMP_MAP_SAN_CPU_MAX="80"
SNMP_MAP_MAINT_WINDOW_TARGET="10.0.0.250"
SNMP_MAP_MAINT_WINDOW_OID=".1.3.6.1.4.1.99999.10.1.0"
SNMP_MAP_MAINT_WINDOW_EXPECT_INT="1"
MAP

cat > "$tmp/snmpget" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${SNMP_CAPTURE:?}"
printf '%s\n' "${SNMP_FAKE_VALUE:-45}"
FAKE
chmod +x "$tmp/snmpget"
PATH="$tmp:$PATH"

QUEUEBASH_ROOT="$tmp/q" SNMP_CAPTURE="$tmp/snmp.args" SNMP_FAKE_VALUE=45 \
    queue_asset_check_snmp_int_below SAN_CPU > "$tmp/out"
grep -q 'asset_check_ok: snmp:int_below target=10.0.0.5 value=45 max=80' "$tmp/out" || { cat "$tmp/out" >&2; exit 1; }
grep -q -- '-Oqv -v2c -c monitor -t 2 -r 0 -- 10.0.0.5 .1.3.6.1.4.1.2021.11.9.0' "$tmp/snmp.args" || { cat "$tmp/snmp.args" >&2; exit 1; }

if QUEUEBASH_ROOT="$tmp/q" SNMP_CAPTURE="$tmp/snmp2.args" SNMP_FAKE_VALUE=45 \
    queue_asset_check_snmp_int_below SAN_CPU max=40 > "$tmp/override.out" 2>&1; then
    echo "explicit class max should override mapped max and block" >&2
    exit 1
fi
grep -q 'value=45 max=40' "$tmp/override.out" || { cat "$tmp/override.out" >&2; exit 1; }

QUEUEBASH_ROOT="$tmp/q" SNMP_CAPTURE="$tmp/truth.args" SNMP_FAKE_VALUE=1 \
    queue_asset_check_snmp_truth_ok MAINT_WINDOW > "$tmp/truth.out"
grep -q 'asset_check_ok: snmp:truth_ok target=10.0.0.250 value=1 expect_int=1' "$tmp/truth.out" || { cat "$tmp/truth.out" >&2; exit 1; }

if QUEUEBASH_ROOT="$tmp/q" SNMP_CAPTURE="$tmp/missing.args" \
    queue_asset_check_snmp_int_below UNKNOWN_ALIAS max=1 > "$tmp/missing.out" 2>&1; then
    echo "unknown alias should block" >&2
    exit 1
fi
grep -q 'unknown SNMP map alias: UNKNOWN_ALIAS' "$tmp/missing.out" || { cat "$tmp/missing.out" >&2; exit 1; }

echo "[PASS] SNMP central map aliases resolve targets, OIDs, and defaults"
