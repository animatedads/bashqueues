#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
fail(){ echo "FAIL: $*" >&2; exit 1; }

desc_file="$(mktemp)"
bin/queue-ai-ask-baseten --describe > "$desc_file"
python3 - "$desc_file" <<'PY' || exit 1
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ask_provider.contract.v1'
assert j['provider']=='baseten'
assert j['fixture_supported'] is True
assert j['live_supported'] is True
assert j['advisory_only'] is True
assert 'baseten' in j['endpoint_family']
PY
rm -f "$desc_file"

bash -lc 'export QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_ROOT=/tmp/queue-baseten-smoke-root; source ./queuebash.sh; _queue_ai_provider_discovery_json baseten' > /tmp/queue-baseten-explain.json
python3 - <<'PY'
import json
j=json.load(open('/tmp/queue-baseten-explain.json'))
assert j['schema']=='queuebash.ask_provider.discovery.v1'
assert j['provider']=='baseten'
assert j['requires_network'] is True
assert j['supports_json'] is True
PY

cat > /tmp/queue-baseten-fixture.json <<'JSON'
{"schema":"queuebash.ask_provider.fixture_test.v1","provider":"baseten","status":"ok","live_call_performed":false,"advisory_only":true}
JSON
python3 - <<'PY'
import json
j=json.load(open('/tmp/queue-baseten-fixture.json'))
assert j['schema']=='queuebash.ask_provider.fixture_test.v1'
assert j['provider']=='baseten'
assert j['live_call_performed'] is False
assert j['advisory_only'] is True
PY

# Missing key must fail closed without network credential leakage.
tmpdir="$(mktemp -d)"
cat > "$tmpdir/request.json" <<'JSON'
{"schema":"queuebash.ai_advisory.request.v1","provider":"baseten","question":"hello","context_allowed":"docs"}
JSON
if bin/queue-ai-ask-baseten --request-json "$tmpdir/request.json" --output-json "$tmpdir/response.json" 2>"$tmpdir/stderr"; then
  fail 'baseten helper unexpectedly succeeded without an API key'
fi
python3 - "$tmpdir/response.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['schema']=='queuebash.ai_advisory.response.v1'
assert j['provider']=='baseten'
assert j['status']=='error'
assert 'baseten_api_key_missing' in j['reason']
assert j['live_call_performed'] is False
PY
rm -rf "$tmpdir"

echo 'PASS ask_baseten_provider_smoke'
