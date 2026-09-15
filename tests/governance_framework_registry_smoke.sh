#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh
queue governance frameworks --json | python3 -m json.tool >/tmp/qb-gov-frameworks.json
queue governance controls cis_controls_v8 --json | python3 -m json.tool >/tmp/qb-gov-cis.json
queue governance controls nist_sp_800_53_rev5 --json | python3 -m json.tool >/tmp/qb-gov-nist.json
queue governance windows-risk --json | python3 -m json.tool >/tmp/qb-gov-win.json
queue governance classify-windows 'disable defender' --json | python3 -m json.tool >/tmp/qb-gov-classify.json
grep -q 'cis_controls_v8' /tmp/qb-gov-frameworks.json
grep -q 'nist_sp_800_53_rev5' /tmp/qb-gov-frameworks.json
grep -q 'disabling_security_controls' /tmp/qb-gov-win.json
grep -q 'windows.disable_security_controls' /tmp/qb-gov-classify.json
queue rto queue-services --json | python3 -m json.tool >/tmp/qb-rto-services-gov.json
grep -q 'governance' /tmp/qb-rto-services-gov.json
echo governance_framework_registry_smoke: ok
