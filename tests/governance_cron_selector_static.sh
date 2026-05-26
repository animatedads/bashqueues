#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q -- '--jurisdiction' bin/bashqueues-cron-class-selector.py || fail "selector lacks jurisdiction CLI"
grep -q -- '--classification' bin/bashqueues-cron-class-selector.py || fail "selector lacks classification CLI"
grep -q 'CRON_POLICY_BLOCKED' bin/bashqueues-cron-class-selector.py || fail "selector lacks fail-closed class"
grep -q 'jurisdiction' bin/bashqueues-cron-ticker.py || fail "ticker does not parse jurisdiction metadata"
grep -q 'BASHQUEUES_CLASSIFICATION' bin/bashqueues-cron-ticker.py || fail "ticker does not parse classification assignment"
[[ -f policies.d/legal-registry/default.env ]] || fail "missing legal registry policy"
[[ -f policies.d/security/levels.env ]] || fail "missing security levels policy"
[[ -f classes/CRON_POLICY_BLOCKED.env ]] || fail "missing fail-closed class"
[[ -f assets.d/audit.sh ]] || fail "missing audit asset"
grep -q 'net:egress_policy' assets.d/net.sh || fail "missing net egress policy facility"
[[ ! -e assets.d/net_usage.sh ]] || fail "assets.d/net_usage.sh must remain absent"
echo '[PASS] governance cron selector static checks pass'
