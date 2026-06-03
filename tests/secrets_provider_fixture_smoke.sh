#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root/qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_SECRETS_FILE_PROVIDER_DIR="$root/fixtures"
export QUEUEBASH_SECRET_RUN_DIR="$root/run"
export QUEUEBASH_SECRETS_POLICY_DIR="$root/policies"
export QUEUEBASH_CLASS_SOURCE_DIR="$root/empty-source/classes"
export QUEUEBASH_ENV_SOURCE_DIR="$root/empty-source/envs.d"
export QUEUEBASH_PLUGIN_SOURCE_DIR="$root/empty-source/assets.d"
export QUEUEBASH_CAP_PLUGIN_SOURCE_DIR="$root/empty-source/caps.d"
export QUEUEBASH_REPORTER_PLUGIN_SOURCE_DIR="$root/empty-source/reporters.d"
export QUEUEBASH_POLICY_SOURCE_DIR="$root/empty-source/policies.d"
mkdir -p "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR" "$QUEUEBASH_SECRETS_POLICY_DIR" "$root/empty-source/classes" "$root/empty-source/envs.d" "$root/empty-source/assets.d" "$root/empty-source/caps.d" "$root/empty-source/reporters.d" "$root/empty-source/policies.d"
printf '%s' 'not-a-secret-fixture-value' > "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
chmod 600 "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
cat > "$QUEUEBASH_SECRETS_POLICY_DIR/class-bindings.tsv" <<'TSV'
# class	uses_secrets	delivery	env_allowed	refresh_allowed
DB_MIGRATION	1	file	0	0
DEFAULT	0	file	0	0
TSV
cat > "$QUEUEBASH_SECRETS_POLICY_DIR/secret-acl.tsv" <<'TSV'
# class	secret_ref	purpose_pattern	delivery	max_ttl_seconds
DB_MIGRATION	customer-db/prod/password	approved database migration*	file	3600
TSV

# Use the provider broker helper directly here. Top-level queue secrets dispatch is
# covered statically; avoiding queue wrapper calls keeps this fixture smoke bounded.
providers_json="$(bash providers.d/secrets/secrets_provider.sh providers --json)"
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["schema"]=="queuebash.secrets.providers.v1"; assert d["providers"][0]["name"]=="file"' "$providers_json"

request_json="$(bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DB_MIGRATION --purpose 'approved database migration' --qid job123 --delivery file --ttl-seconds 1800 --max-runtime-seconds 60 --json)"
python3 - "$request_json" <<'PY'
import json, os, stat, sys
payload=json.loads(sys.argv[1])
assert payload["schema"] == "queuebash.secret_provider.result.v1"
assert payload["ok"] is True
assert payload["provider"] == "file"
assert payload["delivery"] == "file"
assert payload["secret_value_included"] is False
assert payload["redacted"] is True
assert "not-a-secret-fixture-value" not in json.dumps(payload)
path=payload["path"]
mode=stat.S_IMODE(os.stat(path).st_mode)
assert mode == 0o600, oct(mode)
assert open(path).read() == "not-a-secret-fixture-value"
PY

if grep -Fq 'not-a-secret-fixture-value' <<<"$request_json"; then
    echo "secret leaked into request JSON" >&2
    exit 1
fi


if bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DEFAULT --purpose 'approved database migration' --qid jobclass --delivery file --ttl-seconds 1800 --max-runtime-seconds 60 --json >$root/secret_class_denied.json 2>$root/secret_class_denied.err; then
    echo "denied class unexpectedly allowed" >&2
    exit 1
fi
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["schema"]=="queuebash.error.v1"; assert d["error"]["code"]=="class_denied"' "$root/secret_class_denied.json"

if bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DB_MIGRATION --purpose 'wrong purpose' --qid jobpurpose --delivery file --ttl-seconds 1800 --max-runtime-seconds 60 --json >$root/secret_acl_denied.json 2>$root/secret_acl_denied.err; then
    echo "denied purpose unexpectedly allowed" >&2
    exit 1
fi
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["schema"]=="queuebash.error.v1"; assert d["error"]["code"]=="acl_denied"' "$root/secret_acl_denied.json"

if bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DB_MIGRATION --purpose 'approved database migration' --qid jobpolicyttl --delivery file --ttl-seconds 7200 --max-runtime-seconds 60 --json >$root/secret_policy_ttl.json 2>$root/secret_policy_ttl.err; then
    echo "over-policy TTL unexpectedly allowed" >&2
    exit 1
fi
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["schema"]=="queuebash.error.v1"; assert d["error"]["code"]=="ttl_exceeds_policy"' "$root/secret_policy_ttl.json"

if bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DB_MIGRATION --purpose 'approved database migration' --qid jobenv --delivery env --json >$root/secret_env_allowed.json 2>$root/secret_env_allowed.err; then
    echo "env delivery unexpectedly allowed" >&2
    exit 1
fi
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["schema"]=="queuebash.error.v1"; assert d["error"]["code"]=="delivery_denied"' "$root/secret_env_allowed.json"

if bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DB_MIGRATION --purpose 'approved database migration' --qid jobttl --delivery file --ttl-seconds 5 --max-runtime-seconds 60 --json >$root/secret_ttl.json 2>$root/secret_ttl.err; then
    echo "short TTL unexpectedly allowed" >&2
    exit 1
fi
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["error"]["code"]=="ttl_too_short"' "$root/secret_ttl.json"

cleanup_json="$(bash providers.d/secrets/secrets_provider.sh cleanup job123 --json)"
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["schema"]=="queuebash.secret_cleanup.v1"; assert d["removed"] is True' "$cleanup_json"
[[ ! -e "$QUEUEBASH_SECRET_RUN_DIR/job123/db_password" ]] || { echo "secret file remained after cleanup" >&2; exit 1; }

echo "PASS secrets_provider_fixture_smoke"
