#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root/qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_SECRETS_FILE_PROVIDER_DIR="$root/fixtures"
export QUEUEBASH_SECRET_RUN_DIR="$root/run"
export QUEUEBASH_SECRET_AUDIT_DIR="$root/audit"
export QUEUEBASH_SECRETS_POLICY_DIR="$root/policies"
mkdir -p "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR" "$QUEUEBASH_SECRETS_POLICY_DIR"
printf '%s' 'seal-secret-must-not-leak' > "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
chmod 600 "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
cat > "$QUEUEBASH_SECRETS_POLICY_DIR/class-bindings.tsv" <<'TSV'
# class	uses_secrets	delivery	env_allowed	refresh_allowed
DB_MIGRATION	1	file	0	0
TSV
cat > "$QUEUEBASH_SECRETS_POLICY_DIR/secret-acl.tsv" <<'TSV'
# class	secret_ref	purpose_pattern	delivery	max_ttl_seconds
DB_MIGRATION	customer-db/prod/password	approved seal*	file	1800
TSV

request_json="$(bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DB_MIGRATION --purpose 'approved seal CHG-SEAL' --qid jobseal --delivery file --ttl-seconds 900 --max-runtime-seconds 60 --json)"
python3 - "$request_json" <<'PY'
import json, sys
payload=json.loads(sys.argv[1])
assert payload["schema"] == "queuebash.secret_provider.result.v1"
assert payload["ok"] is True
assert payload["secret_value_included"] is False
PY

pre_verify="$(bash providers.d/secrets/secrets_provider.sh verify-manifest jobseal --json)"
python3 - "$pre_verify" <<'PY'
import json, sys
payload=json.loads(sys.argv[1])
assert payload["schema"] == "queuebash.secret_manifest_verify.v1"
assert payload["ok"] is True
assert payload["seal_status"] == "absent"
assert payload["manifest_hash"]
assert payload["secret_value_included"] is False
PY

seal_json="$(bash providers.d/secrets/secrets_provider.sh seal-manifest jobseal --json)"
python3 - "$seal_json" <<'PY'
import json, os, stat, sys
payload=json.loads(sys.argv[1])
assert payload["schema"] == "queuebash.secret_manifest_seal.v1"
assert payload["ok"] is True
assert payload["entries"] == 1
assert payload["manifest_mode"] == "600"
assert payload["manifest_hash"]
assert payload["redacted"] is True
assert payload["secret_value_included"] is False
PY

seal_file="$QUEUEBASH_SECRET_AUDIT_DIR/secret_manifest_seal_jobseal.json"
[[ -f "$seal_file" ]] || { echo "missing manifest seal evidence" >&2; exit 1; }
mode="$(stat -c '%a' "$seal_file" 2>/dev/null || stat -f '%Lp' "$seal_file")"
[[ "$mode" == "600" ]] || { echo "seal mode was $mode, expected 600" >&2; exit 1; }

post_verify="$(bash providers.d/secrets/secrets_provider.sh verify-manifest jobseal --json)"
python3 - "$post_verify" "$seal_json" <<'PY'
import json, sys
verify=json.loads(sys.argv[1])
seal=json.loads(sys.argv[2])
assert verify["schema"] == "queuebash.secret_manifest_verify.v1"
assert verify["ok"] is True
assert verify["seal_status"] == "match"
assert verify["manifest_hash"] == seal["manifest_hash"]
assert verify["secret_value_included"] is False
PY

manifest="$QUEUEBASH_SECRET_RUN_DIR/jobseal/.queuebash_secret_manifest.jsonl"
printf '%s\n' '{"schema":"queuebash.secret_delivery_manifest.v1","qid":"jobseal","path":"/tmp/escaped","redacted":true,"secret_value_included":false}' >> "$manifest"
if bash providers.d/secrets/secrets_provider.sh verify-manifest jobseal --json > "$root/tampered.json"; then
    echo "verify-manifest unexpectedly passed after manifest tamper" >&2
    cat "$root/tampered.json" >&2
    exit 1
fi
python3 - "$root/tampered.json" <<'PY'
import json, sys
payload=json.load(open(sys.argv[1]))
assert payload["schema"] == "queuebash.secret_manifest_verify.v1"
assert payload["ok"] is False
assert payload["seal_status"] == "mismatch"
assert payload["secret_value_included"] is False
PY

if grep -R 'seal-secret-must-not-leak\|approved seal CHG-SEAL' "$QUEUEBASH_SECRET_AUDIT_DIR"; then
    echo "audit/seal evidence leaked secret value or raw purpose" >&2
    exit 1
fi

echo "PASS secrets_provider_manifest_seal_smoke"
