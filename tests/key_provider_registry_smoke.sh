#!/usr/bin/env bash
set -euo pipefail
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bq-key-provider.XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$ROOT"
source ./queuebash.sh
mkdir -p "$ROOT/policy/keys"
cat > "$ROOT/policy/keys/key_registry.tsv" <<'TSV'
# signer operation resource public_key_ref status delegation reason
team:security-review	profile.approve	*	sha256:review-key	active	team:security-review	security review may approve profiles
external:vendor	profile.approve	*	sha256:vendor-key	revoked	external:vendor	vendor revoked
*	policy.override	*	sha256:none	revoked	*	policy override denied
TSV
export QUEUEBASH_KEY_PROVIDER=file
export QUEUEBASH_FILE_KEY_REGISTRY="$ROOT/policy/keys/key_registry.tsv"

allow_json="$(_queue_key_provider_lookup team:security-review profile.approve profile:goodrexx --json)"
printf '%s' "$allow_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.key_lookup_response.v1"; assert d["provider"]=="file"; assert d["decision"]=="allow"; assert d["public_key_ref"]=="sha256:review-key"; assert d["fail_closed"] is False'

deny_json="$(_queue_key_provider_lookup external:vendor profile.approve profile:goodrexx --json || true)"
printf '%s' "$deny_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"]=="deny"; assert d["revoked"] is True; assert d["fail_closed"] is True'

nomatch_json="$(_queue_key_provider_lookup self:hc3 code.sign script:demo --json || true)"
printf '%s' "$nomatch_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"]=="deny"; assert d["reason"]=="no matching key trust rule"; assert d["fail_closed"] is True'

cat > "$ROOT/policy/keys/key_registry.tsv" <<'BAD'
bad	row
BAD
bad_json="$(_queue_key_provider_lookup team:security-review profile.approve profile:goodrexx --json || true)"
printf '%s' "$bad_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"]=="error"; assert d["reason"]=="file_key_registry_malformed"; assert d["fail_closed"] is True'
cat > "$ROOT/policy/keys/key_registry.tsv" <<'TSV'
# signer<TAB>operation<TAB>resource<TAB>public_key_ref<TAB>status<TAB>delegation<TAB>reason
TSV

_queue_key_provider_register_revoke_rotate register self:hc3 profile.sign profile:dev sha256:self-key --reason 'local dev signing' >/dev/null
reg_json="$(_queue_key_provider_lookup self:hc3 profile.sign profile:dev --json)"
printf '%s' "$reg_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"]=="allow"; assert d["public_key_ref"]=="sha256:self-key"'
_queue_key_provider_register_revoke_rotate revoke self:hc3 profile.sign profile:dev --reason 'rotation required' >/dev/null
rev_json="$(_queue_key_provider_lookup self:hc3 profile.sign profile:dev --json || true)"
printf '%s' "$rev_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"]=="deny"; assert d["status"]=="revoked"'

echo '[PASS] key provider registry smoke checks pass'
