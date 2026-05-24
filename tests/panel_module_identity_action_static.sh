#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
q=queuemgr_panel.py

grep -q 'QUEUEBASH_VERSION="0.17.4"' queuebash.sh || fail "version not 0.17.4"
grep -q 'elif rest and ":" in rest\[0\]' "$q" || fail "module command does not parse kind:name identity token"
grep -q 'maybe_kind, maybe_target = rest\[0\]\.split(":", 1)' "$q" || fail "module identity is not split into kind/name"
grep -q 'action, _ = resolve_unique_choice(rest\[1\], actions, action_aliases)' "$q" || fail "module identity parser does not use following token as action"
grep -q 'class:CAPS_TEST explain' README.md || fail "README does not document identity-action module form"
grep -q 'class:CAPS_TEST explain' docs/QUEUEMGR.md || fail "QUEUEMGR docs do not document identity-action module form"

if find . -path './assets.d/net_usage.sh' -print -quit | grep -q .; then
  fail "assets.d/net_usage.sh must not be restored"
fi

echo "[PASS] module command line accepts kind:name identity followed by action"
