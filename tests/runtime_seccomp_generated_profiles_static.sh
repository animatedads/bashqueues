#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
grep -q 'QUEUEBASH_VERSION="0.17.97"' queuebash.sh || fail 'version not bumped to 0.17.95'
grep -q '_queue_profiled_seccomp_allowed_syscalls' queuebash.sh || fail 'profiled seccomp helper missing'
grep -q 'SECCOMP_PROFILED_ALLOWED_SYSCALLS' queuebash.sh || fail 'profiled syscall env not used'
grep -q 'SystemCallFilter=\$profiled_allow' queuebash.sh || fail 'SystemCallFilter not emitted from profiled syscalls'
grep -q 'PROFILED_SECCOMP_BLOCKED: systemd_runner_required' queuebash.sh || fail 'systemd fail-closed guard missing'
grep -q 'CLASS_DEFAULT_SECCOMP_PROFILED_NAME' classes/SECURE_PROFILED.env || fail 'SECURE_PROFILED missing runtime seccomp class default'
grep -q 'CLASS_DEFAULT_SECCOMP_PROFILED_ENFORCE=1' classes/SECURE_PROFILED.env || fail 'SECURE_PROFILED missing runtime seccomp enforce default'
grep -q 'CLASS_DEFAULT_SECCOMP_PROFILED_NAME=%q' queuebash.sh || fail 'generated class template does not stamp profiled seccomp name'
grep -q '0.17.95 - runtime seccomp generated profiles' CHANGELOG.md || fail 'changelog entry missing'
grep -q 'trust decisions to the profile verification layer' CHANGELOG.md || fail 'provider-boundary note missing'
echo '[PASS] runtime seccomp generated profiles static checks pass'
