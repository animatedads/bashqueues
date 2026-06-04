#!/usr/bin/env bash
set -euo pipefail

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root/qroot"
export QUEUEBASH_SECRETS_FILE_PROVIDER_DIR="$root/fixtures"
export QUEUEBASH_SECRETS_POLICY_DIR="$root/policies"
export QUEUEBASH_SECRET_RUN_DIR="$root/run"
export QUEUEBASH_SECRET_AUDIT_DIR="$root/audit"
mkdir -p "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR" "$QUEUEBASH_SECRETS_POLICY_DIR" "$QUEUEBASH_SECRET_RUN_DIR" "$QUEUEBASH_SECRET_AUDIT_DIR"
printf 'fixture-secret-value\n' > "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
chmod 600 "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
cat > "$QUEUEBASH_SECRETS_POLICY_DIR/class-bindings.tsv" <<'POLICY'
# class	uses_secrets	allowed_delivery	env_allowed	refresh_allowed
DB_MIGRATION	1	file	0	0
POLICY
cat > "$QUEUEBASH_SECRETS_POLICY_DIR/secret-acl.tsv" <<'POLICY'
# class	secret_ref	purpose_pattern	delivery	max_ttl_seconds
DB_MIGRATION	customer-db/prod/password	approved seal verify*	file	1800
POLICY

bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password \
  --name db_password \
  --class DB_MIGRATION \
  --purpose 'approved seal verify CHG-SEAL-VERIFY' \
  --qid jobsealverify \
  --delivery file \
  --ttl-seconds 900 \
  --max-runtime-seconds 60 \
  --json > "$root/request.json"

bash providers.d/secrets/secrets_provider.sh seal-manifest jobsealverify --json > "$root/seal.json"
python3 - <<'PY' "$root/seal.json"
import json, pathlib, sys
payload=json.load(open(sys.argv[1]))
assert payload["schema"] == "queuebash.secret_manifest_seal.v1"
assert payload["ok"] is True
assert payload["redacted"] is True
assert payload["secret_value_included"] is False
assert payload["manifest_hash"]
seal_path=pathlib.Path(sys.argv[1]).parent / "seal_path.txt"
seal_path.write_text(payload.get("manifest", ""))
PY

bash providers.d/secrets/secrets_provider.sh verify-manifest jobsealverify --json > "$root/verify_ok.json"
python3 - <<'PY' "$root/verify_ok.json"
import json, sys
payload=json.load(open(sys.argv[1]))
assert payload["schema"] == "queuebash.secret_manifest_verify.v1"
assert payload["ok"] is True, payload
assert payload["seal_status"] == "match", payload
assert payload["seal_mode"] == "600", payload
assert payload["seal_schema_ok"] == 1, payload
assert payload["seal_redacted_ok"] == 1, payload
assert payload["seal_secret_value_marker_ok"] == 1, payload
assert payload["seal_manifest_path_ok"] == 1, payload
assert payload["seal_qid_ok"] == 1, payload
assert payload["seal_hash_present"] == 1, payload
assert payload["secret_value_included"] is False
PY

seal_file="$QUEUEBASH_SECRET_AUDIT_DIR/secret_manifest_seal_jobsealverify.json"
chmod 0644 "$seal_file"
if bash providers.d/secrets/secrets_provider.sh verify-manifest jobsealverify --json > "$root/insecure_seal.json"; then
    echo "verify-manifest unexpectedly passed with insecure seal mode" >&2
    exit 1
fi
python3 - <<'PY' "$root/insecure_seal.json"
import json, sys
payload=json.load(open(sys.argv[1]))
assert payload["ok"] is False, payload
assert payload["seal_status"] == "invalid", payload
assert payload["seal_mode"] != "600", payload
PY
chmod 0600 "$seal_file"

python3 - <<'PY' "$seal_file"
import pathlib, sys
p=pathlib.Path(sys.argv[1])
s=p.read_text()
s=s.replace('"redacted":true', '"redacted":false')
p.write_text(s)
PY
if bash providers.d/secrets/secrets_provider.sh verify-manifest jobsealverify --json > "$root/unredacted_seal.json"; then
    echo "verify-manifest unexpectedly passed with unredacted seal metadata" >&2
    exit 1
fi
python3 - <<'PY' "$root/unredacted_seal.json"
import json, sys
payload=json.load(open(sys.argv[1]))
assert payload["ok"] is False, payload
assert payload["seal_status"] == "invalid", payload
assert payload["seal_redacted_ok"] == 0, payload
assert payload["secret_value_included"] is False
PY

bash providers.d/secrets/secrets_provider.sh seal-manifest jobsealverify --json >/dev/null
python3 - <<'PY' "$seal_file"
import pathlib, sys
p=pathlib.Path(sys.argv[1])
s=p.read_text()
s=s.replace('"qid":"jobsealverify"', '"qid":"otherjob"')
p.write_text(s)
PY
if bash providers.d/secrets/secrets_provider.sh verify-manifest jobsealverify --json > "$root/wrong_qid_seal.json"; then
    echo "verify-manifest unexpectedly passed with wrong seal qid" >&2
    exit 1
fi
python3 - <<'PY' "$root/wrong_qid_seal.json"
import json, sys
payload=json.load(open(sys.argv[1]))
assert payload["ok"] is False, payload
assert payload["seal_status"] == "invalid", payload
assert payload["seal_qid_ok"] == 0, payload
PY

if grep -R 'fixture-secret-value' "$QUEUEBASH_SECRET_AUDIT_DIR"; then
    echo "secret value leaked into seal/verify audit metadata" >&2
    exit 1
fi

echo "PASS secrets_provider_manifest_seal_verify_smoke"
