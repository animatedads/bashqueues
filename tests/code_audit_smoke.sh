#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$(mktemp -d)"
tree="$(mktemp -d)"
trap 'rm -rf "$root" "$tree"' EXIT
mkdir -p "$tree/assets.d" "$tree/reporters.d"
cp queuebash.sh "$tree/queuebash.sh"
cp assets.d/path.sh "$tree/assets.d/path.sh"
cp reporters.d/snmp.sh "$tree/reporters.d/snmp.sh"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_CODE_SIGNATURE_MODE=off
source ./queuebash.sh
queue keygen code root >/dev/null
pub="$root/keys/public/root.ed25519.pub.pem"
sha="$(sha256sum "$pub" | awk '{print $1}')"
mkdir -p "$root/policies.d/code-signing"
printf 'QUEUEBASH_CODE_SIGNATURE_MODE="warn"\nQUEUEBASH_CODE_TRUSTED_PUBLIC_KEY_SHA256S="%s"\n' "$sha" > "$root/policies.d/code-signing/default.env"
queue code sign --tree "$tree" --key root >/dev/null
out="$root/audit.out"
json="$root/audit.json"
queue code audit --tree "$tree" --mode enforce > "$out"
grep -q '^ok=' "$out"
grep -q 'asset' "$out"
grep -q 'reporter' "$out"
grep -q "$sha" "$out"
queue code audit --tree "$tree" --mode enforce --json > "$json"
python3 - <<PY "$json" "$sha"
import json, sys
p, sha = sys.argv[1], sys.argv[2]
d = json.load(open(p, encoding='utf-8'))
assert d['fail'] == 0, d
paths = {c['path']: c for c in d['components']}
assert 'queuebash.sh' in paths
assert 'assets.d/path.sh' in paths
assert 'reporters.d/snmp.sh' in paths
assert all(c['status'] == 'ok' for c in d['components'])
assert any(c['category'] == 'asset' for c in d['components'])
assert any(c['category'] == 'reporter' for c in d['components'])
assert any(c['public_key_sha256'] == sha for c in d['components'])
PY
printf '[PASS] queue code audit reports signed components for audit\n'
