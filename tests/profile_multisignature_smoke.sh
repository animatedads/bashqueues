#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "FAIL: $*" >&2; exit 1; }

repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo"
export QUEUEBASH_ROOT="$(mktemp -d)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_KEY_PROVIDER=file
export QUEUEBASH_FILE_KEY_REGISTRY="$QUEUEBASH_ROOT/policy/keys/key_registry.tsv"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
source ./queuebash.sh >/dev/null 2>&1
mkdir -p "$(dirname "$QUEUEBASH_FILE_KEY_REGISTRY")"
{
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' 'self:hc3' 'profile.sign' 'goodrexx' 'file:/keys/hc3.pub' active self 'local author trusted'
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' 'team:security-review' 'profile.sign' 'goodrexx' 'file:/keys/sec.pub' active team 'security review trusted'
} > "$QUEUEBASH_FILE_KEY_REGISTRY"

prof="$QUEUEBASH_ROOT/profiles/interrogation/goodrexx"
mkdir -p "$prof"
cp examples/profiles/multisig/signatures.goodrexx.json.example "$prof/signatures.json"
policy="$QUEUEBASH_ROOT/policy/profile-signatures/required.tsv"
mkdir -p "$(dirname "$policy")"
cat > "$policy" <<'POL'
*	author	self:*	required	author required
*	reviewer	team:security-review	required	reviewer required
POL

out="$(queue profile-signature verify "$prof" --policy "$policy" --json)"
python3 - <<'PY' "$out"
import json,sys
j=json.loads(sys.argv[1])
assert j["schema"] == "queuebash.profile_signature_verification.v1"
assert j["decision"] == "allow"
assert j["reason"] == "profile_signatures_file_verifier_valid"
assert j["key_provider_consulted"] is True
assert j["cryptographic_verification_performed"] is False
assert j["migration_required"] is False
assert j["signature_count"] == 2
PY

cat > "$policy" <<'POL'
*	approver	org:bashqueues	required	org approval required
POL
if queue profile-signature verify "$prof" --policy "$policy" --json >"$QUEUEBASH_ROOT/deny.json"; then
  fail "missing required signer should deny"
fi
python3 - <<'PY' "$QUEUEBASH_ROOT/deny.json"
import json,sys
j=json.load(open(sys.argv[1]))
assert j["decision"] == "deny"
assert j["reason"] == "required_signature_missing"
assert j["fail_closed"] is True
PY

printf '{bad json' > "$prof/signatures.json"
if queue profile-signature verify "$prof" --json >"$QUEUEBASH_ROOT/error.json"; then
  fail "malformed sidecar should error"
fi
python3 - <<'PY' "$QUEUEBASH_ROOT/error.json"
import json,sys
j=json.load(open(sys.argv[1]))
assert j["decision"] == "error"
assert j["fail_closed"] is True
PY

echo "PASS profile multi-signature smoke"
