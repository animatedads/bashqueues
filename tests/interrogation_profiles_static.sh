#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
[[ -x bin/queue-interrogate ]] || fail "queue-interrogate missing/executable"
[[ -x bin/queue-interrogate-compile ]] || fail "queue-interrogate-compile missing/executable"
for f in assets.d/secprofile.sh assets.d/netprofile.sh assets.d/fileprofile.sh; do
  bash -n "$f" || fail "syntax error: $f"
  grep -q 'profile_verified' "$f" || fail "profile_verified missing in $f"
  grep -q 'SHOULD_BE_SIGNED' "$f" || fail "should-be-signed check missing in $f"
done
grep -q '_queue_profile_command' queuebash.sh || fail "queue profile command missing"
grep -q 'profile|profiles' queuebash.sh || fail "queue profile dispatch missing"
grep -q 'NETPROFILE_GLOBAL_SS_USED=0' bin/queue-interrogate-compile || fail "global ss must be context-only"
grep -q 'FILEPROFILE_ALLOW_DELETED_FILES={1 if' bin/queue-interrogate-compile || fail "deleted-file flag must not be inverted"
grep -q '^[a-z][a-z0-9_]*' bin/queue-interrogate-compile || fail "syscall token filter missing"
grep -q 'INTERROGATE_PROFILE' classes/INTERROGATE_PROFILE.env || fail "interrogation class missing"
grep -q 'SECURE_PROFILED' classes/SECURE_PROFILED.env || fail "secure profiled class missing"
grep -q 'Interrogation profiles' docs/INTERROGATION_PROFILES.md || fail "docs missing"
echo '[PASS] interrogation profile static checks pass'
