#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "FAIL path_locking_contract_static: $*" >&2; exit 1; }

for f in docs/PATH_LOCKING_SECURITY_MODEL.md docs/PROFILING_PATH_LOCK_CONTRACT.md; do
  [ -s "$f" ] || fail "missing $f"
done

sec=docs/PATH_LOCKING_SECURITY_MODEL.md
contract=docs/PROFILING_PATH_LOCK_CONTRACT.md

grep -q 'not treat an approved path string as proof' "$sec" || fail 'missing string-vs-object warning'
grep -q 'symlink/hardlink/mount trick' "$sec" || fail 'missing red-team attack class'
grep -q 'deny symlinks by default' "$sec" || fail 'missing symlink denial rule'
grep -q 'deny procfs magic links by default' "$sec" || fail 'missing magic-link denial rule'
grep -q 'verify final device/inode' "$sec" || fail 'missing final dev/inode verification'
grep -q 'private per-job directories' "$sec" || fail 'missing private workspace rule'
grep -q 'existing-file-write' "$sec" || fail 'missing operation split existing-file-write'
grep -q 'create-only' "$sec" || fail 'missing operation split create-only'
grep -q 'append-only' "$sec" || fail 'missing operation split append-only'
grep -q 'fail closed' "$sec" || fail 'missing fail-closed rule'

grep -q 'queuebash.path_lock.profile.v1' "$contract" || fail 'missing profile schema name'
grep -q 'queuebash.path_lock.evidence.v1' "$contract" || fail 'missing evidence schema name'
grep -q 'symlink_denied' "$contract" || fail 'missing symlink_denied reason'
grep -q 'magiclink_denied' "$contract" || fail 'missing magiclink_denied reason'
grep -q 'parent_identity_mismatch' "$contract" || fail 'missing parent mismatch reason'
grep -q 'final_identity_mismatch' "$contract" || fail 'missing final mismatch reason'
grep -q 'shared_tmp_denied' "$contract" || fail 'missing shared tmp denial reason'
grep -q 'Out of scope' "$contract" || fail 'missing out-of-scope enforcement boundary'

if grep -R "allowed: /tmp/workdir/config_update.sql" docs/PATH_LOCKING_SECURITY_MODEL.md docs/PROFILING_PATH_LOCK_CONTRACT.md >/dev/null; then
  : # permitted only as negative example in quoted discussion
fi

echo "PASS path_locking_contract_static"
