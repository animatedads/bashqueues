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
printf 'QUEUEBASH_CODE_SIGNATURE_MODE="enforce"\nQUEUEBASH_CODE_TRUSTED_PUBLIC_KEY_SHA256S="%s"\n' "$sha" > "$root/policies.d/code-signing/default.env"
queue code sign --tree "$tree" --key root >/dev/null
queue code verify --tree "$tree" --mode enforce >/tmp/bq-code-verify.$$.out
if ! grep -q 'fail=0' /tmp/bq-code-verify.$$.out; then
  cat /tmp/bq-code-verify.$$.out >&2
  exit 1
fi
printf '\n# tamper\n' >> "$tree/assets.d/path.sh"
if queue code verify --tree "$tree" --mode enforce >/tmp/bq-code-verify2.$$.out 2>&1; then
  echo "expected tamper verification failure" >&2
  cat /tmp/bq-code-verify2.$$.out >&2
  exit 1
fi
grep -q 'sha_mismatch' /tmp/bq-code-verify2.$$.out
rm -f /tmp/bq-code-verify.$$.out /tmp/bq-code-verify2.$$.out
printf '[PASS] code signing verifies trusted signatures and rejects tampering\n'
