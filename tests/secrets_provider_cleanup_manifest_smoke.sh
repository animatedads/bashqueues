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
printf '%s' 'manifest-secret-must-not-leak' > "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
chmod 600 "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
cat > "$QUEUEBASH_SECRETS_POLICY_DIR/class-bindings.tsv" <<'TSV'
# class	uses_secrets	delivery	env_allowed	refresh_allowed
DB_MIGRATION	1	file	0	0
TSV
cat > "$QUEUEBASH_SECRETS_POLICY_DIR/secret-acl.tsv" <<'TSV'
# class	secret_ref	purpose_pattern	delivery	max_ttl_seconds
DB_MIGRATION	customer-db/prod/password	approved database migration*	file	1800
TSV

request_json="$(bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DB_MIGRATION --purpose 'approved database migration CHG-MANIFEST' --qid jobmanifest --delivery file --ttl-seconds 1200 --max-runtime-seconds 60 --json)"
python3 - "$request_json" <<'PY'
import json, os, stat, sys
payload=json.loads(sys.argv[1])
assert payload["schema"] == "queuebash.secret_provider.result.v1"
assert payload["ok"] is True
path=payload["path"]
assert os.path.exists(path)
assert stat.S_IMODE(os.stat(path).st_mode) == 0o600
PY

manifest="$QUEUEBASH_SECRET_RUN_DIR/jobmanifest/.queuebash_secret_manifest.jsonl"
[[ -f "$manifest" ]] || { echo "missing secret delivery manifest" >&2; exit 1; }
mode="$(stat -c '%a' "$manifest" 2>/dev/null || stat -f '%Lp' "$manifest")"
[[ "$mode" == "600" ]] || { echo "manifest mode was $mode, expected 600" >&2; exit 1; }
python3 - <<'PY' "$manifest"
import json, pathlib, sys
text=pathlib.Path(sys.argv[1]).read_text()
assert "manifest-secret-must-not-leak" not in text
assert "approved database migration CHG-MANIFEST" not in text
rows=[json.loads(line) for line in text.splitlines() if line.strip()]
assert len(rows) == 1
row=rows[0]
assert row["schema"] == "queuebash.secret_delivery_manifest.v1"
assert row["qid"] == "jobmanifest"
assert row["name"] == "db_password"
assert row["provider"] == "file"
assert row["delivery"] == "file"
assert row["ttl_seconds"] == 1200
assert row["redacted"] is True
assert row["secret_value_included"] is False
assert "secret_ref_hash" in row and row["secret_ref_hash"]
assert "path_hash" in row and row["path_hash"]
PY

cleanup_json="$(bash providers.d/secrets/secrets_provider.sh cleanup jobmanifest --json)"
python3 - "$cleanup_json" <<'PY'
import json, os, stat, sys
payload=json.loads(sys.argv[1])
assert payload["schema"] == "queuebash.secret_cleanup.v1"
assert payload["ok"] is True
assert payload["removed"] is True
assert payload["manifest_entries"] == 1
assert payload["redacted"] is True
assert payload["secret_value_included"] is False
path=payload["cleanup_evidence"]
assert os.path.exists(path)
assert stat.S_IMODE(os.stat(path).st_mode) == 0o600
PY
[[ ! -e "$QUEUEBASH_SECRET_RUN_DIR/jobmanifest/db_password" ]] || { echo "secret remained after cleanup" >&2; exit 1; }
[[ ! -e "$manifest" ]] || { echo "manifest remained in secret run dir after cleanup" >&2; exit 1; }

evidence="$QUEUEBASH_SECRET_AUDIT_DIR/secret_cleanup_jobmanifest.json"
python3 - <<'PY' "$evidence"
import json, pathlib, sys
text=pathlib.Path(sys.argv[1]).read_text()
assert "manifest-secret-must-not-leak" not in text
assert "approved database migration CHG-MANIFEST" not in text
payload=json.loads(text)
assert payload["schema"] == "queuebash.secret_cleanup_evidence.v1"
assert payload["ok"] is True
assert payload["removed"] is True
assert payload["manifest_entries"] == 1
assert payload["unsafe_paths"] == 0
assert payload["redacted"] is True
assert payload["secret_value_included"] is False
PY

if grep -R 'manifest-secret-must-not-leak\|approved database migration CHG-MANIFEST' "$QUEUEBASH_SECRET_AUDIT_DIR"; then
    echo "audit/evidence leaked secret value or raw purpose" >&2
    exit 1
fi

echo "PASS secrets_provider_cleanup_manifest_smoke"
