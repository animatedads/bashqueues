#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
# Smoke the broker helper directly. Full `queue ai` dispatch is covered by static
# checks; avoiding `_queue_init` keeps this fixture test bounded on large trees.
outdir="$(mktemp -d "${TMPDIR:-/tmp}/queue-ai-broker-smoke.XXXXXX")"
export QUEUEBASH_AI_BROKER_HEALTH_CACHE="$outdir/health-cache.json"
trap 'rm -rf "$outdir"' EXIT

bin/queue-ai-broker providers --json > "$outdir/providers.json"
bin/queue-ai-broker models --json > "$outdir/models.json"
bin/queue-ai-broker health --json > "$outdir/health.json"
bin/queue-ai-broker health --provider ollama --model llama3 --set-state available --reason "smoke fallback candidate" --json > "$outdir/health_update_ollama.json"
bin/queue-ai-broker health --provider openai_compat --model local-model --set-state timeout --reason "smoke timeout" --cooldown-seconds 60 --json > "$outdir/health_update_timeout.json"
bin/queue-ai-broker explain --profile balanced --capability chat --json > "$outdir/explain_health_timeout.json"
bin/queue-ai-broker health --provider openai_compat --model local-model --set-state available --reason "smoke restore" --json > "$outdir/health_update_restore.json"
bin/queue-ai-broker explain --profile balanced --capability chat,json --json > "$outdir/explain.json"
bin/queue-ai-broker chat --profile balanced --message "hello broker" --json > "$outdir/chat.json"
bin/queue-ai-broker json --profile json_strict --message '{"hello":"world"}' --json > "$outdir/json.json"

# Prove brokered live mode is gated, and then prove a fixture helper can be invoked
# without any real external provider, credential, or network call.
set +e
bin/queue-ai-broker chat --profile balanced --message "blocked live" --live --json > "$outdir/live_blocked.json"
blocked_rc=$?
set -e
[[ "$blocked_rc" -ne 0 ]] || { echo "FAIL: live broker call should be blocked without QUEUEBASH_AI_LIVE_ENABLED" >&2; exit 1; }
cat > "$outdir/fake-provider" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
req=""; out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --request-json) req="$2"; shift 2 ;;
    --output-json) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
python3 - "$req" "$out" <<'PY'
import json, sys
req=json.load(open(sys.argv[1]))
json.dump({
  "schema":"queuebash.ai_advisory.response.v1",
  "provider":req.get("provider"),
  "status":"ok",
  "model":req.get("model"),
  "answer_markdown":"fake brokered provider response for " + req.get("question", ""),
  "advisory_only":True,
  "live_call_performed":True,
  "usage":{"fixture_tokens":1}
}, open(sys.argv[2], "w"))
PY
SH
chmod +x "$outdir/fake-provider"
QUEUEBASH_AI_LIVE_ENABLED=1 QUEUEBASH_AI_OPENAI_COMPAT_HELPER="$outdir/fake-provider" \
  bin/queue-ai-broker chat --profile balanced --message "broker live fixture" --live --json > "$outdir/live_fixture.json"

python3 - "$outdir" <<'PY'
import json, pathlib, sys
root=pathlib.Path(sys.argv[1])
expect={
 'providers.json':'queuebash.ai_broker.providers.v1',
 'models.json':'queuebash.ai_broker.models.v1',
 'health.json':'queuebash.ai_broker.health.v1',
 'health_update_ollama.json':'queuebash.ai_broker.health_update.v1',
 'health_update_timeout.json':'queuebash.ai_broker.health_update.v1',
 'explain_health_timeout.json':'queuebash.ai_broker.explain.v1',
 'health_update_restore.json':'queuebash.ai_broker.health_update.v1',
 'explain.json':'queuebash.ai_broker.explain.v1',
 'chat.json':'queuebash.ai_broker.response.v1',
 'json.json':'queuebash.ai_broker.response.v1',
 'live_blocked.json':'queuebash.ai_broker.error.v1',
 'live_fixture.json':'queuebash.ai_broker.response.v1',
}
for name,schema in expect.items():
    data=json.loads((root/name).read_text())
    assert data.get('schema') == schema, (name, data.get('schema'))
providers=json.loads((root/'providers.json').read_text())['providers']
assert providers, 'no providers returned'
timeout_update=json.loads((root/'health_update_timeout.json').read_text())
assert timeout_update['ok'] is True
assert timeout_update['updated']['state'] == 'timeout'
assert timeout_update['updated']['cooldown_seconds'] == 60
health_timeout=json.loads((root/'explain_health_timeout.json').read_text())
assert any('health_cooldown' in r.get('reasons', []) or 'health_timeout' in r.get('reasons', []) for r in health_timeout.get('rejected', [])), health_timeout
assert health_timeout['selected']['provider'] == 'ollama', health_timeout
explain=json.loads((root/'explain.json').read_text())
assert explain['decision'] in ('allow','deny')
assert explain['decision'] == 'allow', explain
assert 'policy_links' in explain
assert explain['policy_links']['applicable'] is True
assert explain['policy_links']['combined']['regulatory']
assert explain['policy_links']['combined']['corporate']
assert explain['policy_links']['combined']['regulatory'][0]['id'] == 'UK_GDPR'
assert explain['policy_links']['combined']['regulatory'][0].get('uri') == 'policy://regulatory/uk-gdpr'
chat=json.loads((root/'chat.json').read_text())
assert chat['ok'] is True
assert chat['live_call_performed'] is False
assert chat['selected_provider']
assert chat['policy_links']['applicable'] is True
assert chat['policy_links']['combined']['audit']
js=json.loads((root/'json.json').read_text())
assert js['ok'] is True
assert js['live_call_performed'] is False
assert 'json' in js
blocked=json.loads((root/'live_blocked.json').read_text())
assert blocked['ok'] is False
assert blocked['reason'] == 'live_ai_provider_not_enabled'
live=json.loads((root/'live_fixture.json').read_text())
assert live['ok'] is True
assert live['live_call_performed'] is True
assert live['provider_execution'] == 'brokered_live_provider_call'
assert live['selected_provider'] == 'openai_compat'
assert 'fake brokered provider response' in live['answer_markdown']
PY

echo "PASS queue_ai_broker_runtime_smoke"
