#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -x install-system.sh ]]
bash -n install-system.sh
grep -q 'install-system.sh must be run as root' install-system.sh
grep -q 'queue submit system-install-core' install-system.sh
grep -q 'QUEUEBASH_SUBMIT_REASON_DEFAULT' install-system.sh
grep -q 'QUEUEBASH_ALLOW_NONINTERACTIVE=1' install-system.sh
grep -q -- '--with-cron' install-system.sh
grep -q 'bashqueues-cron.timer' install-system.sh
grep -q 'queue keygen' install-system.sh
grep -q 'CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_SHA256' install-system.sh
grep -q '/etc/profile.d/bashqueues.sh' install-system.sh
grep -q '/etc/bashqueues/policies.d' install-system.sh
echo "[PASS] root system installer, optional cron, root signing key setup, and noninteractive queue sourcing are wired"
