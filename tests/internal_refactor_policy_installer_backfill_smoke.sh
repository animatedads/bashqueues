#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }

repo="$(cd "$(dirname "$0")/.." && pwd -P)"
tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$tmproot"
# shellcheck disable=SC1090
source "$repo/queuebash.sh"
_queue_install_bundled_policies

for f in \
  policies.d/sandbox/queue-default.env \
  policies.d/seccomp/queue-default.env \
  policies.d/class-statement/default.env \
  policies.d/acl/file.example.tsv \
  policies.d/key/file_registry.example.tsv \
  policies.d/profile-signatures/required.example.tsv \
  policies.d/finops/ibm.env.example \
  policies.d/legal-registry/ibm.example.tsv \
  policies.d/sovereign/ibm.env.example \
  policies.d/reporting/default.env \
  policies.d/security/levels.env \
  policies.d/snmp-map/default.env; do
    [[ -f "$tmproot/$f" ]] || fail "expected bundled policy not installed: $f"
done

# Existing local files must survive.
echo 'local override' > "$tmproot/policies.d/acl/file.example.tsv"
_queue_install_bundled_policies
grep -q 'local override' "$tmproot/policies.d/acl/file.example.tsv" || fail 'local policy example was overwritten'

# Disabled marker must block install.
rm -f "$tmproot/policies.d/key/file_registry.example.tsv"
mkdir -p "$tmproot/policies.d/key/.disabled"
touch "$tmproot/policies.d/key/.disabled/file_registry.example.tsv"
_queue_install_bundled_policies
[[ ! -f "$tmproot/policies.d/key/file_registry.example.tsv" ]] || fail '.disabled marker did not block policy install'

[[ ! -f "$repo/assets.d/net_usage.sh" ]] || fail 'assets.d/net_usage.sh must remain absent'
[[ -f "$repo/caps.d/net_usage.sh" ]] || fail 'caps.d/net_usage.sh should be present'

echo 'PASS internal refactor policy installer backfill smoke'
