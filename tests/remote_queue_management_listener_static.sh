#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "[FAIL] $*" >&2; exit 1; }

[[ -x bin/queue-remote-management-listener.py ]] || fail 'listener helper missing or not executable'
python3 -m py_compile bin/queue-remote-management-listener.py || fail 'listener py_compile failed'

for f in \
  docs/REMOTE_QUEUE_MANAGEMENT_LISTENER.md \
  policies.d/remote-queue/remote-management.env.example \
  policies.d/remote-queue/clients.example.tsv \
  policies.d/remote-queue/acl.example.tsv \
  examples/remote.d/local-management.env.example \
  systemd/bashqueues-remote-management.service; do
  [[ -f "$f" ]] || fail "missing $f"
done

grep -q -- '--with-remote-listener' install-system.sh || fail 'installer option missing'
grep -q 'install-remote-listener-policy.sh' install-system.sh || fail 'installer remote-listener policy step missing'
grep -q 'install-remote-listener-service.sh' install-system.sh || fail 'installer remote-listener service step missing'
grep -q 'install-remote-listener-verify.sh' install-system.sh || fail 'installer remote-listener verify step missing'
grep -q 'queue-remote-management-listener.py' install-system.sh || fail 'installer does not install listener helper'
grep -q 'queue submit system-install-remote-listener-policy --after-success system-install-core' install-system.sh || fail 'remote listener policy job is not queued after core'
grep -q 'queue submit system-install-remote-listener-service --after-success system-install-remote-listener-policy' install-system.sh || fail 'remote listener service job is not queued after policy'
grep -q 'queue submit system-install-remote-listener-verify --after-success system-install-remote-listener-service' install-system.sh || fail 'remote listener verify job is not queued after service'
grep -q 'installer_pending_jobs_count' install-system.sh || fail 'installer does not count pending dogfood jobs'
grep -q 'dogfood installation queue did not drain' install-system.sh || fail 'installer does not fail when dogfood queue remains pending'
! grep -q 'bash "\$work_dir/install-remote-listener.sh"' install-system.sh || fail 'remote listener installer must be dogfooded through queued jobs, not run directly'
grep -q 'remote listener policy file was not installed' install-system.sh || fail 'installer missing remote listener post-install file verification'
grep -q 'remote-management.env' install-system.sh || fail 'installer does not install remote-management policy'
grep -q 'clients.tsv' install-system.sh || fail 'installer does not install client registry'
grep -q 'acl.tsv' install-system.sh || fail 'installer does not install ACL'

grep -q '/etc/bashqueues/policies.d/remote-queue' install-system.sh || fail 'installer uses wrong remote policies.d path'
! grep -q '/etc/queuebash/policy.d/remote-queue' install-system.sh || fail 'installer still references old remote policy.d path'
! grep -q '/etc/queuebash/policy/remote-queue' install-system.sh || fail 'installer still references old remote policy path'
grep -q 'policy files copied under:' install-system.sh || fail 'installer completion message does not say files are copied'
grep -q '/etc/bashqueues/policies.d/remote-queue/remote-management.env' install-system.sh || fail 'installer completion message missing remote-management.env path'
grep -q '/etc/bashqueues/policies.d/remote-queue/acl.tsv' install-system.sh || fail 'installer completion message missing acl.tsv path'
grep -q '/etc/bashqueues/policies.d/remote-queue/clients.tsv' install-system.sh || fail 'installer completion message missing clients.tsv path'
grep -q 'policies.d/remote-queue/remote-management.env.example' install-system.sh || fail 'installer completion message missing remote-management example source'
grep -q 'policies.d/remote-queue/acl.example.tsv' install-system.sh || fail 'installer completion message missing ACL example source'
grep -q 'policies.d/remote-queue/clients.example.tsv' install-system.sh || fail 'installer completion message missing clients example source'

grep -q 'QUEUE_REMOTE_MANAGEMENT_LOOPBACK_ONLY=1' policies.d/remote-queue/remote-management.env.example || fail 'loopback default missing'
grep -q 'No matching ACL line means deny' docs/REMOTE_QUEUE_MANAGEMENT_LISTENER.md || fail 'fail-closed ACL docs missing'
grep -q 'run.*exec.*shell.*command.*cmd.*bash.*sh.*kill.*cancel' docs/REMOTE_QUEUE_MANAGEMENT_LISTENER.md || fail 'blocked operation docs missing'
grep -q 'DENIED_OPERATION_PREFIXES' bin/queue-remote-management-listener.py || fail 'listener guard missing'
grep -q 'READONLY_OPERATIONS' bin/queue-remote-management-listener.py || fail 'listener allowlist missing'
grep -q 'remote-queue-management-audit.jsonl' bin/queue-remote-management-listener.py docs/REMOTE_QUEUE_MANAGEMENT_LISTENER.md || fail 'audit log contract missing'

bash -n install-system.sh || fail 'install-system syntax failed'

echo '[PASS] remote queue management listener static checks pass'
