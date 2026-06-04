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
printf '%s' 'row-integrity-secret-must-not-leak' > "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
chmod 600 "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
cat > "$QUEUEBASH_SECRETS_POLICY_DIR/class-bindings.tsv" <<'TSV'
# class	uses_secrets	delivery	env_allowed	refresh_allowed
DB_MIGRATION	1	file	0	0
TSV
cat > "$QUEUEBASH_SECRETS_POLICY_DIR/secret-acl.tsv" <<'TSV'
# class	secret_ref	purpose_pattern	delivery	max_ttl_seconds
DB_MIGRATION	customer-db/prod/password	approved row integrity*	file	1800
TSV

bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password \
  --name db_password \
  --class DB_MIGRATION \
  --purpose 'approved row integrity CHG-ROW' \
  --qid jobrow \
  --delivery file \
  --ttl-seconds 900 \
  --max-runtime-seconds 60 \
  --json > "$root/request.json"

bash providers.d/secrets/secrets_provider.sh verify-manifest jobrow --json > "$root/verify_ok.json"
python3 - <<'PY' "$root/verify_ok.json"
import json, sys
payload=json.load(open(sys.argv[1]))
assert payload["schema"] == "queuebash.secret_manifest_verify.v1", payload
assert payload["ok"] is True, payload
assert payload["qid_mismatches"] == 0, payload
assert payload["missing_hashes"] == 0, payload
assert payload["path_hash_mismatches"] == 0, payload
assert payload["secret_value_included"] is False, payload
PY

manifest="$QUEUEBASH_SECRET_RUN_DIR/jobrow/.queuebash_secret_manifest.jsonl"
python3 - <<'PY' "$manifest"
import pathlib, sys
p=pathlib.Path(sys.argv[1])
s=p.read_text()
s=s.replace('"qid":"jobrow"', '"qid":"otherjob"')
p.write_text(s)
PY
if bash providers.d/secrets/secrets_provider.sh verify-manifest jobrow --json > "$root/wrong_qid.json"; then
    echo "verify-manifest unexpectedly passed a delivery row with the wrong qid" >&2
    exit 1
fi
python3 - <<'PY' "$root/wrong_qid.json"
import json, sys
payload=json.load(open(sys.argv[1]))
assert payload["ok"] is False, payload
assert payload["qid_mismatches"] == 1, payload
assert payload["secret_value_included"] is False, payload
PY

bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password \
  --name db_password2 \
  --class DB_MIGRATION \
  --purpose 'approved row integrity CHG-ROW2' \
  --qid jobhash \
  --delivery file \
  --ttl-seconds 900 \
  --max-runtime-seconds 60 \
  --json > "$root/request2.json"
manifest2="$QUEUEBASH_SECRET_RUN_DIR/jobhash/.queuebash_secret_manifest.jsonl"
python3 - <<'PY' "$manifest2"
import pathlib, re, sys
p=pathlib.Path(sys.argv[1])
s=p.read_text()
s=re.sub(r'"path_hash":"[^"]+"', '"path_hash":"badpathhash"', s)
p.write_text(s)
PY
if bash providers.d/secrets/secrets_provider.sh verify-manifest jobhash --json > "$root/bad_path_hash.json"; then
    echo "verify-manifest unexpectedly passed a delivery row with a bad path_hash" >&2
    exit 1
fi
python3 - <<'PY' "$root/bad_path_hash.json"
import json, sys
payload=json.load(open(sys.argv[1]))
assert payload["ok"] is False, payload
assert payload["path_hash_mismatches"] == 1, payload
assert payload["secret_value_included"] is False, payload
PY

bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password \
  --name db_password3 \
  --class DB_MIGRATION \
  --purpose 'approved row integrity CHG-ROW3' \
  --qid jobmissinghash \
  --delivery file \
  --ttl-seconds 900 \
  --max-runtime-seconds 60 \
  --json > "$root/request3.json"
manifest3="$QUEUEBASH_SECRET_RUN_DIR/jobmissinghash/.queuebash_secret_manifest.jsonl"
python3 - <<'PY' "$manifest3"
import pathlib, re, sys
p=pathlib.Path(sys.argv[1])
s=p.read_text()
s=re.sub(r'"secret_ref_hash":"[^"]+"', '"secret_ref_hash":""', s)
p.write_text(s)
PY
if bash providers.d/secrets/secrets_provider.sh verify-manifest jobmissinghash --json > "$root/missing_hash.json"; then
    echo "verify-manifest unexpectedly passed a delivery row with a missing secret_ref_hash" >&2
    exit 1
fi
python3 - <<'PY' "$root/missing_hash.json"
import json, sys
payload=json.load(open(sys.argv[1]))
assert payload["ok"] is False, payload
assert payload["missing_hashes"] == 1, payload
assert payload["secret_value_included"] is False, payload
PY

if grep -R 'row-integrity-secret-must-not-leak\|approved row integrity CHG-ROW' "$QUEUEBASH_SECRET_AUDIT_DIR"; then
    echo "secret value or raw purpose leaked into audit metadata" >&2
    exit 1
fi

echo "PASS secrets_provider_manifest_row_integrity_smoke"
