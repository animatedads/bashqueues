#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root/qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_SECRETS_FILE_PROVIDER_DIR="$root/fixtures"
export QUEUEBASH_SECRET_RUN_DIR="$root/run"
mkdir -p "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR"
printf '%s' 'not-a-secret-fixture-value' > "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
chmod 600 "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"

source ./queuebash.sh

# Exercise top-level queue dispatch once, then use the helper directly to avoid repeated _queue_init in suite runs.
providers_json="$(queue secrets providers --json)"
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

if bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DB_MIGRATION --purpose test --qid jobenv --delivery env --json >/tmp/secret_env_allowed.json 2>/tmp/secret_env_allowed.err; then
    echo "env delivery unexpectedly allowed" >&2
    exit 1
fi
python3 -c 'import json; d=json.load(open("/tmp/secret_env_allowed.json")); assert d["schema"]=="queuebash.error.v1"; assert d["error"]["code"]=="delivery_denied"'

if bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DB_MIGRATION --purpose test --qid jobttl --delivery file --ttl-seconds 5 --max-runtime-seconds 60 --json >/tmp/secret_ttl.json 2>/tmp/secret_ttl.err; then
    echo "short TTL unexpectedly allowed" >&2
    exit 1
fi
python3 -c 'import json; d=json.load(open("/tmp/secret_ttl.json")); assert d["error"]["code"]=="ttl_too_short"'

cleanup_json="$(bash providers.d/secrets/secrets_provider.sh cleanup job123 --json)"
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["schema"]=="queuebash.secret_cleanup.v1"; assert d["removed"] is True' "$cleanup_json"
[[ ! -e "$QUEUEBASH_SECRET_RUN_DIR/job123/db_password" ]] || { echo "secret file remained after cleanup" >&2; exit 1; }

echo "PASS secrets_provider_fixture_smoke"
