#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_KEY_PROVIDER=file
export QUEUEBASH_FILE_KEY_REGISTRY="$root/policy/keys/key_registry.tsv"
mkdir -p "$root/policy/keys" "$root/profiles/goodrexx"
cat > "$root/profiles/goodrexx/signatures.json" <<'JSON'
{
  "schema": "queuebash.profile_signatures.v1",
  "profile": "goodrexx",
  "artifact_sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "signatures": [
    {
      "signer": "self:hc3",
      "role": "author",
      "alg": "ed25519",
      "public_key_sha256": "1111111111111111111111111111111111111111111111111111111111111111",
      "signature_b64": "ZmFrZS1zaWduYXR1cmU=",
      "signed_at": "2026-05-27T12:00:00Z"
    },
    {
      "signer": "team:security-review",
      "role": "reviewer",
      "alg": "ed25519",
      "public_key_sha256": "2222222222222222222222222222222222222222222222222222222222222222",
      "signature_b64": "ZmFrZS1yZXZpZXctc2lnbmF0dXJl",
      "signed_at": "2026-05-27T12:30:00Z"
    }
  ]
}
JSON
{
  printf '%s\t%s\t%s\t%s\t%s\n' '*' author 'self:*' required 'author required'
  printf '%s\t%s\t%s\t%s\t%s\n' '*' reviewer 'team:security-review' required 'reviewer required'
} > "$root/policy/required.tsv"
cat > "$QUEUEBASH_FILE_KEY_REGISTRY" <<'EOF_KEYS'
self:hc3	profile.sign	goodrexx	file:/keys/hc3.pub	active	self	local author trusted
team:security-review	profile.sign	goodrexx	file:/keys/sec.pub	active	team	security review trusted
EOF_KEYS
source ./queuebash.sh
out="$(queue profile-signature verify "$root/profiles/goodrexx" --policy "$root/policy/required.tsv" --json)"
OUT="$out" python3 - <<'PY'
import json, os
obj=json.loads(os.environ['OUT'])
assert obj['schema']=='queuebash.profile_signature_verification.v1'
assert obj['decision']=='allow'
assert obj['file_verifier'] is True
assert obj['key_provider_consulted'] is True
assert obj['cryptographic_verification_performed'] is False
assert obj['cryptographic_verification_status']=='not_performed'
assert obj['signature_count']==2
assert all(x['decision']=='allow' for x in obj['key_provider_lookups'])
PY
# Missing key trust must fail closed.
sed -i '/team:security-review/d' "$QUEUEBASH_FILE_KEY_REGISTRY"
if queue profile-signature verify "$root/profiles/goodrexx" --policy "$root/policy/required.tsv" --json >/tmp/bq-profile-msig-deny.json; then
  echo 'expected key provider trust failure' >&2
  exit 1
fi
python3 - <<'PY'
import json
obj=json.load(open('/tmp/bq-profile-msig-deny.json'))
assert obj['decision']=='deny'
assert obj['reason']=='key_provider_trust_not_satisfied'
assert obj['fail_closed'] is True
PY

echo 'PASS profile multisignature file verifier smoke'
