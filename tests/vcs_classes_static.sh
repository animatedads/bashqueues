#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "[FAIL] $*" >&2; exit 1; }

for c in VCS_CHECKOUT VCS_RELEASE_GATE VCS_LEGACY_SERIAL VCS_CHANGESET_AUDIT; do
    f="classes/$c.env"
    [[ -f "$f" ]] || fail "missing class $f"
    bash -n "$f" || fail "class syntax failed: $f"
    grep -q "^# bashqueues class: $c" "$f" || fail "class header missing for $c"
    grep -q 'queue_class_shared_asset vcs repo_exists' "$f" || fail "class does not gate repo_exists: $c"
done

grep -q 'queue_class_shared_asset vcs clean_tree' classes/VCS_RELEASE_GATE.env || fail "release gate must require clean tree"
grep -q 'queue_class_exclusive_claim "vcs:release:' classes/VCS_RELEASE_GATE.env || fail "release gate must be serialised"
grep -q 'queue_class_exclusive_claim "vcs:legacy:' classes/VCS_LEGACY_SERIAL.env || fail "legacy class must be serialised"
grep -q 'queue_class_exclusive_claim "vcs:audit:' classes/VCS_CHANGESET_AUDIT.env || fail "changeset audit class must be serialised"
grep -q 'queue_class_shared_asset vcs identity' classes/VCS_CHANGESET_AUDIT.env || fail "changeset audit must support identity gates"
grep -q 'queue_class_shared_asset vcs revision' classes/VCS_CHANGESET_AUDIT.env || fail "changeset audit must support revision gates"
grep -q 'Existing `git:\*` assets remain valid' docs/VCS_TENANT_CONTRACT.md || fail "contract must state git is preserved"
grep -q 'Subversion, CVS, Mercurial, and Perforce' docs/VCS_TENANT_CONTRACT.md || fail "contract must cover legacy VCS systems"

echo "[PASS] VCS classes and tenant contract are wired"
