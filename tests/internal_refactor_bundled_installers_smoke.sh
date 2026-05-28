#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }

repo="$(cd "$(dirname "$0")/.." && pwd -P)"
tmproot="$(mktemp -d)"
src="$(mktemp -d)"
trap 'rm -rf "$tmproot" "$src"' EXIT

mkdir -p "$src/classes" "$src/envs.d" "$src/assets.d" "$src/caps.d" "$src/reporters.d" \
         "$src/policies.d/sandbox" "$src/policies.d/seccomp" "$src/policies.d/class-statement"

cat > "$src/classes/TEST.env" <<'EOC'
CLASS_ALLOW_PARALLEL=1
EOC
cat > "$src/envs.d/demo.env" <<'EOE'
QUEUEBASH_ENV_PROFILE_NAME=demo
EOE
cat > "$src/assets.d/demo_asset.sh" <<'EOS'
#!/usr/bin/env bash
return 0 2>/dev/null || exit 0
EOS
cat > "$src/caps.d/demo_cap.sh" <<'EOS'
#!/usr/bin/env bash
return 0 2>/dev/null || exit 0
EOS
cat > "$src/reporters.d/demo_reporter.sh" <<'EOS'
#!/usr/bin/env bash
return 0 2>/dev/null || exit 0
EOS
cat > "$src/policies.d/sandbox/demo.env" <<'EOP'
SANDBOX_LEVEL=network-none
EOP
cat > "$src/policies.d/seccomp/demo.env" <<'EOP'
SECCOMP_PROFILE=off
EOP
cat > "$src/policies.d/class-statement/demo.env" <<'EOP'
QUEUEBASH_POLICY_KIND=class-statement
EOP

mkdir -p "$tmproot/classes/.disabled" "$tmproot/assets.d/.disabled"
echo 'local copy must survive' > "$tmproot/classes/LOCAL.env"
echo 'do not overwrite me' > "$tmproot/classes/TEST.env"
touch "$tmproot/assets.d/.disabled/demo_asset.sh"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$tmproot"
export QUEUEBASH_CLASS_SOURCE_DIR="$src/classes"
export QUEUEBASH_ENV_SOURCE_DIR="$src/envs.d"
export QUEUEBASH_PLUGIN_SOURCE_DIR="$src/assets.d"
export QUEUEBASH_CAP_PLUGIN_SOURCE_DIR="$src/caps.d"
export QUEUEBASH_REPORTER_PLUGIN_SOURCE_DIR="$src/reporters.d"
export QUEUEBASH_POLICY_SOURCE_DIR="$src/policies.d"
# shellcheck disable=SC1090
source "$repo/queuebash.sh"
_queue_install_bundled_classes
_queue_install_bundled_env_profiles
_queue_install_bundled_asset_plugins
_queue_install_bundled_cap_plugins
_queue_install_bundled_reporter_plugins
_queue_install_bundled_policies

[[ -f "$tmproot/classes/TEST.env" ]] || fail 'class not installed/preserved'
grep -q 'do not overwrite me' "$tmproot/classes/TEST.env" || fail 'class overwrite protection failed'
[[ -f "$tmproot/envs.d/demo.env" ]] || fail 'env profile not installed'
[[ ! -f "$tmproot/assets.d/demo_asset.sh" ]] || fail 'disabled asset should not be installed'
[[ -f "$tmproot/caps.d/demo_cap.sh" && -x "$tmproot/caps.d/demo_cap.sh" ]] || fail 'cap plugin not installed executable'
[[ -f "$tmproot/reporters.d/demo_reporter.sh" && -x "$tmproot/reporters.d/demo_reporter.sh" ]] || fail 'reporter plugin not installed executable'
[[ -f "$tmproot/policies.d/sandbox/demo.env" ]] || fail 'sandbox policy not installed'
[[ -f "$tmproot/policies.d/seccomp/demo.env" ]] || fail 'seccomp policy not installed'
[[ -f "$tmproot/policies.d/class-statement/demo.env" ]] || fail 'class-statement policy not installed'

echo 'PASS internal refactor bundled installers smoke'
