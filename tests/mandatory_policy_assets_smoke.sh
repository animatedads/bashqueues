#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/assets.d" "$tmp/policies.d/class-statement"
cp assets.d/path.sh "$tmp/assets.d/path.sh"

touch "$tmp/required"
cat > "$tmp/policies.d/class-statement/default.env" <<POLICY
QUEUEBASH_POLICY_KIND=class-statement
QUEUEBASH_POLICY_NAME=default
CLASS_POLICY_USER_SANDBOX_POLICIES="off network-none restrict-egress strict queue-default"
CLASS_POLICY_USER_SECCOMP_POLICIES="off docker-default strict queue-default"
CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE="reason-or-authorisation"
CLASS_POLICY_WEAK_POLICY_REQUIRE="reason-or-authorisation"
CLASS_POLICY_MANDATORY_ASSETS=
POLICY
printf 'CLASS_POLICY_MANDATORY_ASSETS=%q\n' $'path\texists\t'"$tmp/required" >> "$tmp/policies.d/class-statement/default.env"

out="$(QUEUEBASH_ROOT="$tmp" QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc 'source ./queuebash.sh >/dev/null; _queue_class_asset_reset; _queue_asset_implied_preflight_for_class' 2>&1)"
if ! grep -q 'asset_check_ok: path:exists' <<< "$out"; then
    echo "FAIL: mandatory policy asset did not run/pass" >&2
    echo "$out" >&2
    exit 1
fi

rm -f "$tmp/required"
set +e
out="$(QUEUEBASH_ROOT="$tmp" QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc 'source ./queuebash.sh >/dev/null; _queue_class_asset_reset; _queue_asset_implied_preflight_for_class' 2>&1)"
rc=$?
set -e
if [[ "$rc" -eq 0 ]]; then
    echo "FAIL: missing mandatory policy asset target should block" >&2
    echo "$out" >&2
    exit 1
fi
if ! grep -q 'mandatory_policy_asset_blocked: asset=path:exists:' <<< "$out"; then
    echo "FAIL: block output did not identify mandatory policy asset" >&2
    echo "$out" >&2
    exit 1
fi

echo "[PASS] mandatory policy assets run and block outside class assets"
