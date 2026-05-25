#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.17.25"' queuebash.sh || fail "version not 0.17.20"

grep -q 'add_restriction' queuemgr_panel.py || fail "Class Creator missing add_restriction row"
grep -q 'def build_class_restriction_record' queuemgr_panel.py || fail "missing hint-driven restriction builder"
grep -q 'def class_restriction_facility_choices' queuemgr_panel.py || fail "missing facility chooser"
grep -q 'def class_restriction_variable_choices' queuemgr_panel.py || fail "missing variable chooser"
grep -q 'asset-hint' queuemgr_panel.py || fail "restriction builder does not use asset hints"
grep -q 'modules", "explain", facility' queuemgr_panel.py || fail "restriction builder does not use cap/module explain hints"
grep -q 'queue_class_shared_asset' queuemgr_panel.py || fail "restriction builder cannot generate shared asset records"
grep -q 'queue_class_exclusive_asset' queuemgr_panel.py || fail "restriction builder cannot generate exclusive asset records"
grep -q 'queue_class_exclusive_claim' queuemgr_panel.py || fail "restriction builder cannot generate exclusive claims"
grep -q 'execute_classdraft_command' queuemgr_panel.py || fail "F2 Class Creator command handler missing"
grep -q 'classcreator restriction' queuemgr_panel.py || fail "F2 completions missing classcreator restriction"

grep -q 'Class Creator restriction builder' docs/QUEUEMGR.md || fail "QUEUEMGR docs missing restriction builder section"
grep -q 'Class Creator hint-driven restrictions' README.md || fail "README missing class creator restriction section"
grep -q '0.16.33' CHANGELOG.md || fail "CHANGELOG missing 0.16.33"

if find assets.d -maxdepth 1 -name 'net_usage.sh' | grep -q .; then
  fail "assets.d/net_usage.sh must not be restored"
fi

echo "[PASS] Class Creator builds restrictions from hints with contextual * choosers"
