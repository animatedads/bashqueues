#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL: $*" >&2; exit 1; }

[[ -x bin/queue-policy-wizard ]] || fail 'bin/queue-policy-wizard missing or not executable'
bash -n bin/queue-policy-wizard || fail 'wizard syntax failed'
grep -Eq 'WIZARD_VERSION="0\.[0-9]+\.[0-9]+"' bin/queue-policy-wizard || fail 'wizard version string missing/malformed'
grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"

grep -q 'QUEUEBASH_AI_LIVE_ENABLED' bin/queue-policy-wizard || fail 'current AI live gate missing'
! grep -q 'QUEUEBASH_AI_ASK_LIVE' bin/queue-policy-wizard || fail 'stale AI live variable found'
grep -q '/etc/queuebash/policies.d' docs/POLICY_SETUP_WIZARD.md || fail 'canonical system policy root missing from wizard docs'
! grep -q '/etc/bashqueues' bin/queue-policy-wizard || fail 'legacy /etc/bashqueues namespace found in wizard executable'
! grep -q 'queue policies list' bin/queue-policy-wizard docs/POLICY_SETUP_WIZARD.md || fail 'unsupported queue policies command suggested'
! grep -q 'queue assets validate' bin/queue-policy-wizard docs/POLICY_SETUP_WIZARD.md || fail 'unsupported queue assets command suggested'

grep -q 'queuebash.policy_wizard_run.v1' bin/queue-policy-wizard docs/POLICY_SETUP_WIZARD.md || fail 'audit schema missing'
grep -q 'secrets_written.*False\|secrets_written' bin/queue-policy-wizard || fail 'secrets_written audit flag missing'
grep -q 'ticket_created.*False\|ticket_created' bin/queue-policy-wizard || fail 'ticket_created audit flag missing'
grep -q -- '--dryrun' docs/POLICY_SETUP_WIZARD.md || fail 'dryrun docs missing'
grep -q -- '--non-interactive' docs/POLICY_SETUP_WIZARD.md || fail 'non-interactive docs missing'

echo 'PASS policy_wizard_static'
