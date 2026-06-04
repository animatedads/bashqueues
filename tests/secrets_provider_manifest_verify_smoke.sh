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
printf '%s' 'verify-secret-must-not-leak' > "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
chmod 600 "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
cat > "$QUEUEBASH_SECRETS_POLICY_DIR/class-bindings.tsv" <<'TSV'
# class	uses_secrets	delivery	env_allowed	refresh_allowed
DB_MIGRATION	1	file	0	0
TSV
cat > "$QUEUEBASH_SECRETS_POLICY_DIR/secret-acl.tsv" <<'TSV'
# class	secret_ref	purpose_pattern	delivery	max_ttl_seconds
DB_MIGRATION	customer-db/prod/password	approved verification*	file	1800
TSV

request_json="$(bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DB_MIGRATION --purpose 'approved verification CHG-VERIFY' --qid jobverify --delivery file --ttl-seconds 900 --max-runtime-seconds 60 --json)"
python3 - "$request_json" <<'PY'
import json, sys
payload=json.loads(sys.argv[1])
assert payload["schema"] == "queuebash.secret_provider.result.v1"
assert payload["ok"] is True
assert payload["secret_value_included"] is False
PY

verify_json="$(bash providers.d/secrets/secrets_provider.sh verify-manifest jobverify --json)"
python3 - "$verify_json" <<'PY'
import json, pathlib, stat, sys
payload=json.loads(sys.argv[1])
assert payload["schema"] == "queuebash.secret_manifest_verify.v1"
assert payload["ok"] is True
assert payload["entries"] == 1
assert payload["insecure_permissions"] == 0
assert payload["unsafe_paths"] == 0
assert payload["missing_paths"] == 0
assert payload["malformed_entries"] == 0
assert payload["secret_value_markers"] == 0
assert payload["redacted"] is True
assert payload["secret_value_included"] is False
manifest=pathlib.Path(payload["manifest"])
assert stat.S_IMODE(manifest.stat().st_mode) == 0o600
text=manifest.read_text()
assert "verify-secret-must-not-leak" not in text
assert "approved verification CHG-VERIFY" not in text
PY

manifest="$QUEUEBASH_SECRET_RUN_DIR/jobverify/.queuebash_secret_manifest.jsonl"
chmod 644 "$manifest"
if bash providers.d/secrets/secrets_provider.sh verify-manifest jobverify --json >/tmp/verify_bad.json; then
    echo "verify-manifest unexpectedly passed insecure manifest mode" >&2
    cat /tmp/verify_bad.json >&2
    exit 1
fi
python3 - /tmp/verify_bad.json <<'PY'
import json, sys
payload=json.load(open(sys.argv[1]))
assert payload["schema"] == "queuebash.secret_manifest_verify.v1"
assert payload["ok"] is False
assert payload["insecure_permissions"] == 1
assert payload["secret_value_included"] is False
PY

if grep -R 'verify-secret-must-not-leak\|approved verification CHG-VERIFY' "$QUEUEBASH_SECRET_AUDIT_DIR"; then
    echo "audit leaked secret value or raw purpose" >&2
    exit 1
fi

echo "PASS secrets_provider_manifest_verify_smoke"
