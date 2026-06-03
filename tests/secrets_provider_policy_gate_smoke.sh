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
printf '%s' 'fixture-secret-must-not-leak' > "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
chmod 600 "$QUEUEBASH_SECRETS_FILE_PROVIDER_DIR/customer-db__prod__password.secret"
cat > "$QUEUEBASH_SECRETS_POLICY_DIR/class-bindings.tsv" <<'TSV'
# class	uses_secrets	delivery	env_allowed	refresh_allowed
DB_MIGRATION	1	file	0	0
REPORT_GENERATION	0	file	0	0
TSV
cat > "$QUEUEBASH_SECRETS_POLICY_DIR/secret-acl.tsv" <<'TSV'
# class	secret_ref	purpose_pattern	delivery	max_ttl_seconds
DB_MIGRATION	customer-db/prod/password	approved database migration*	file	1800
TSV

ok_json="$(bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DB_MIGRATION --purpose 'approved database migration CHG-1' --qid jobok --delivery file --ttl-seconds 1200 --max-runtime-seconds 60 --json)"
python3 - "$ok_json" <<'PY'
import json, sys
payload=json.loads(sys.argv[1])
assert payload["ok"] is True
assert payload["secret_value_included"] is False
assert payload["redacted"] is True
assert "fixture-secret-must-not-leak" not in json.dumps(payload)
PY

if bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class REPORT_GENERATION --purpose 'approved database migration CHG-1' --qid jobclass --delivery file --ttl-seconds 1200 --max-runtime-seconds 60 --json >"$root/class.json" 2>"$root/class.err"; then
    echo "class denial was not enforced" >&2
    exit 1
fi
python3 - <<'PY' "$root/class.json"
import json, sys
d=json.load(open(sys.argv[1]))
assert d["schema"] == "queuebash.error.v1"
assert d["error"]["code"] == "class_denied"
PY

if bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DB_MIGRATION --purpose 'wrong purpose' --qid jobpurpose --delivery file --ttl-seconds 1200 --max-runtime-seconds 60 --json >"$root/purpose.json" 2>"$root/purpose.err"; then
    echo "purpose denial was not enforced" >&2
    exit 1
fi
python3 - <<'PY' "$root/purpose.json"
import json, sys
d=json.load(open(sys.argv[1]))
assert d["schema"] == "queuebash.error.v1"
assert d["error"]["code"] == "acl_denied"
PY

if bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DB_MIGRATION --purpose 'approved database migration CHG-1' --qid jobttl --delivery file --ttl-seconds 2400 --max-runtime-seconds 60 --json >"$root/ttl.json" 2>"$root/ttl.err"; then
    echo "ACL TTL denial was not enforced" >&2
    exit 1
fi
python3 - <<'PY' "$root/ttl.json"
import json, sys
d=json.load(open(sys.argv[1]))
assert d["schema"] == "queuebash.error.v1"
assert d["error"]["code"] == "ttl_exceeds_policy"
PY

if bash providers.d/secrets/secrets_provider.sh request customer-db/prod/password --name db_password --class DB_MIGRATION --purpose 'approved database migration CHG-1' --qid jobenv --delivery env --ttl-seconds 1200 --max-runtime-seconds 60 --json >"$root/env.json" 2>"$root/env.err"; then
    echo "env delivery denial was not enforced" >&2
    exit 1
fi
python3 - <<'PY' "$root/env.json"
import json, sys
d=json.load(open(sys.argv[1]))
assert d["schema"] == "queuebash.error.v1"
assert d["error"]["code"] == "delivery_denied"
PY

if bash providers.d/secrets/secrets_provider.sh break-glass request customer-db/prod/password --reason emergency --ticket CHG-1 --json >"$root/breakglass.json" 2>"$root/breakglass.err"; then
    echo "break-glass fixture request unexpectedly allowed" >&2
    exit 1
fi
python3 - <<'PY' "$root/breakglass.json"
import json, sys
d=json.load(open(sys.argv[1]))
assert d["schema"] == "queuebash.secrets.break_glass.v1"
assert d["ok"] is False
assert d["error"]["code"] == "authorization_required"
assert d["secret_value_included"] is False
PY

audit_json="$(bash providers.d/secrets/secrets_provider.sh audit --json)"
python3 - "$audit_json" <<'PY'
import json, os, sys
d=json.loads(sys.argv[1])
assert d["schema"] == "queuebash.secret_audit.v1"
assert d["secret_value_included"] is False
assert d["redacted"] is True
assert d["event_count"] >= 3
assert os.path.exists(d["audit_log"])
PY

if grep -R 'fixture-secret-must-not-leak\|approved database migration CHG-1\|wrong purpose' "$QUEUEBASH_SECRET_AUDIT_DIR"; then
    echo "audit log leaked secret value or raw purpose text" >&2
    exit 1
fi
grep -Fq 'queuebash.secret_audit_event.v1' "$QUEUEBASH_SECRET_AUDIT_DIR/secrets_audit.jsonl" || { echo "missing audit event schema" >&2; exit 1; }
grep -Fq 'purpose_hash' "$QUEUEBASH_SECRET_AUDIT_DIR/secrets_audit.jsonl" || { echo "missing purpose hash" >&2; exit 1; }

echo "PASS secrets_provider_policy_gate_smoke"
