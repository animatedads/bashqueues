#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys, tempfile
root=pathlib.Path(__file__).resolve().parents[1]
cmd=[str(root/'bin/queue-ai-broker')]
_tmp=tempfile.TemporaryDirectory(prefix="queue-ai-broker-json-contract.")
env=os.environ.copy()
env["QUEUEBASH_AI_BROKER_HEALTH_CACHE"] = str(pathlib.Path(_tmp.name)/"health-cache.json")
env["QUEUEBASH_AI_BROKER_HEALTH_EVENTS"] = str(pathlib.Path(_tmp.name)/"health-events.jsonl")

def load(args, env_override=None):
    out=subprocess.check_output(cmd+args, cwd=root, text=True, env=env_override or env, timeout=30)
    return json.loads(out)

providers=load(['providers','--json'])
assert providers['schema']=='queuebash.ai_broker.providers.v1'
assert isinstance(providers.get('providers'), list) and providers['providers']
models=load(['models','--json'])
assert models['schema']=='queuebash.ai_broker.models.v1'
assert isinstance(models.get('models'), list) and models['models']
health=load(['health','--json'])
assert health['schema']=='queuebash.ai_broker.health.v1'
explain=load(['explain','--profile','balanced','--capability','chat,json','--json'])
assert explain['schema']=='queuebash.ai_broker.explain.v1'
assert explain['decision']=='allow'
assert explain['selected']['provider']
assert 'policy_links' in explain
assert explain['policy_links']['applicable'] is True
assert explain['policy_links']['combined']['regulatory']
assert explain['policy_links']['combined']['corporate']
assert explain['policy_links']['combined']['regulatory'][0]['id'] == 'UK_GDPR'
assert explain['policy_links']['combined']['regulatory'][0].get('uri') == 'policy://regulatory/uk-gdpr'
chat=load(['chat','--profile','balanced','--message','hello','--json'])
assert chat['schema']=='queuebash.ai_broker.response.v1'
assert chat['ok'] is True
assert chat['live_call_performed'] is False
assert chat['provider_execution']=='broker_selection_only_no_live_call'
assert chat['policy_links']['applicable'] is True
assert chat['policy_links']['combined']['audit']
ollama=load(['health','--provider','ollama','--model','llama3','--set-state','available','--reason','contract fallback candidate','--json'])
assert ollama['schema']=='queuebash.ai_broker.health_update.v1'
update=load(['health','--provider','openai_compat','--model','local-model','--set-state','timeout','--reason','contract timeout','--cooldown-seconds','60','--json'])
assert update['schema']=='queuebash.ai_broker.health_update.v1'
assert update['ok'] is True
assert update['updated']['state']=='timeout'
explain_timeout=load(['explain','--profile','balanced','--capability','chat','--json'])
assert any('health_cooldown' in r.get('reasons', []) or 'health_timeout' in r.get('reasons', []) for r in explain_timeout.get('rejected', [])), explain_timeout
assert explain_timeout['selected']['provider'] == 'ollama'
restore=load(['health','--provider','openai_compat','--model','local-model','--set-state','available','--reason','contract restore','--json'])
assert restore['schema']=='queuebash.ai_broker.health_update.v1'
clear_one=load(['health','--provider','openai_compat','--model','local-model','--clear','--json'])
assert clear_one['schema']=='queuebash.ai_broker.health_clear.v1'
assert clear_one['ok'] is True
assert clear_one['removed_count'] == 1, clear_one
expired=load(['health','--provider','openai_compat','--model','local-model','--set-state','timeout','--reason','expired cooldown contract','--cooldown-seconds','1','--json'])
assert expired['schema']=='queuebash.ai_broker.health_update.v1'
cache_path=pathlib.Path(env['QUEUEBASH_AI_BROKER_HEALTH_CACHE'])
cache_data=json.loads(cache_path.read_text())
for item in cache_data.get('entries', []):
    if item.get('provider') == 'openai_compat' and item.get('model') == 'local-model':
        item['cooldown_until_epoch'] = 1
        item['cooldown_until'] = '1970-01-01T00:00:01Z'
cache_path.write_text(json.dumps(cache_data))
pruned=load(['health','--prune-expired','--json'])
assert pruned['schema']=='queuebash.ai_broker.health_prune.v1'
assert pruned['pruned_count'] >= 1, pruned
clear_all=load(['health','--clear-all','--json'])
assert clear_all['schema']=='queuebash.ai_broker.health_clear.v1'
assert clear_all['ok'] is True
events=load(['health','--events','--limit','25','--json'])
assert events['schema']=='queuebash.ai_broker.health_events.v1'
assert events['ok'] is True
assert events['event_count'] >= 4, events
assert any(e.get('schema') == 'queuebash.ai_broker.health_event.v1' for e in events.get('events', [])), events
assert any(e.get('action') == 'update' for e in events.get('events', [])), events
pruned_events=load(['health','--prune-events','--max-events','5','--json'])
assert pruned_events['schema']=='queuebash.ai_broker.health_events_prune.v1'
assert pruned_events['ok'] is True
assert pruned_events['after_count'] <= 5, pruned_events
prune_marker=load(['health','--events','--action','prune_events','--summary','--json'])
assert prune_marker['schema']=='queuebash.ai_broker.health_events.v1'
assert prune_marker['summary']['by_action'].get('prune_events', 0) >= 1, prune_marker
filtered_events=load(['health','--events','--provider','openai_compat','--action','update','--summary','--limit','25','--json'])
assert filtered_events['schema']=='queuebash.ai_broker.health_events.v1'
assert filtered_events['filters']['provider'] == 'openai_compat', filtered_events
assert filtered_events['filters']['action'] == 'update', filtered_events
assert filtered_events['summary']['event_count'] == filtered_events['event_count'], filtered_events
assert filtered_events['summary']['by_action'].get('update', 0) >= 1, filtered_events
assert all(e.get('provider') == 'openai_compat' and e.get('action') == 'update' for e in filtered_events.get('events', [])), filtered_events
blocked=subprocess.run(cmd+['chat','--profile','balanced','--message','blocked','--live','--json'], cwd=root, text=True, stdout=subprocess.PIPE, check=False, env=env, timeout=30)
assert blocked.returncode != 0
blocked_json=json.loads(blocked.stdout)
assert blocked_json['schema']=='queuebash.ai_broker.error.v1'
assert blocked_json['reason']=='live_ai_provider_not_enabled'

# Live failure feedback must record a local health-cache update and fall back to the next candidate.
feedback_root = pathlib.Path(_tmp.name) / "feedback"
feedback_root.mkdir(parents=True, exist_ok=True)
failing = feedback_root / "failing-provider"
failing.write_text("""#!/usr/bin/env bash
set -euo pipefail
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --output-json) out="$2"; shift 2 ;;
    --request-json) shift 2 ;;
    *) shift ;;
  esac
done
printf '{"schema":"queuebash.ai_advisory.response.v1","ok":false,"status":"error","reason":"fixture rate limit 429"}\n' > "$out"
exit 9
""", encoding="utf-8")
failing.chmod(0o755)
ok = feedback_root / "ok-provider"
ok.write_text("""#!/usr/bin/env bash
set -euo pipefail
req=""; out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --request-json) req="$2"; shift 2 ;;
    --output-json) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
python3 - "$req" "$out" <<'PYS'
import json, sys
req=json.load(open(sys.argv[1]))
json.dump({"schema":"queuebash.ai_advisory.response.v1","ok":True,"status":"ok","answer_markdown":"ok fallback","provider":req.get("provider"),"model":req.get("model")}, open(sys.argv[2], "w"))
PYS
""", encoding="utf-8")
ok.chmod(0o755)
env_fb = dict(env)
env_fb.update({
    "QUEUEBASH_AI_BROKER_HEALTH_CACHE": str(feedback_root / "health-cache.json"),
    "QUEUEBASH_AI_BROKER_HEALTH_EVENTS": str(feedback_root / "health-events.jsonl"),
    "QUEUEBASH_AI_LIVE_ENABLED": "1",
    "QUEUEBASH_AI_OPENAI_COMPAT_HELPER": str(failing),
    "QUEUEBASH_AI_OLLAMA_HELPER": str(ok),
    "QUEUEBASH_AI_BROKER_HEALTH_FAILURE_COOLDOWN_SECONDS": "30",
})
subprocess.check_call([cmd[0], 'health', '--provider', 'openai_compat', '--model', 'local-model', '--set-state', 'available', '--json'], env=env_fb, stdout=subprocess.DEVNULL, timeout=30)
subprocess.check_call([cmd[0], 'health', '--provider', 'ollama', '--model', 'llama3', '--set-state', 'available', '--json'], env=env_fb, stdout=subprocess.DEVNULL, timeout=30)
live_fallback_feedback = load(['chat', '--profile', 'balanced', '--message', 'fallback feedback', '--live', '--json'], env_fb)
assert live_fallback_feedback['schema'] == 'queuebash.ai_broker.response.v1'
assert live_fallback_feedback['fallback']['used'] is True, live_fallback_feedback
assert live_fallback_feedback['selected_provider'] == 'ollama', live_fallback_feedback
assert any(x.get('schema') == 'queuebash.ai_broker.health_feedback.v1' for x in live_fallback_feedback.get('health_feedback', [])), live_fallback_feedback
assert any(x.get('updated', {}).get('state') == 'rate_limited' for x in live_fallback_feedback.get('health_feedback', [])), live_fallback_feedback
feedback_events = load(['health','--events','--limit','25','--json'], env_fb)
assert feedback_events['schema'] == 'queuebash.ai_broker.health_events.v1'
assert any(e.get('action') == 'feedback' and e.get('state') == 'rate_limited' for e in feedback_events.get('events', [])), feedback_events
feedback_filtered = load(['health','--events','--provider','openai_compat','--action','feedback','--state','rate_limited','--summary','--json'], env_fb)
assert feedback_filtered['event_count'] >= 1, feedback_filtered
assert feedback_filtered['summary']['by_state'].get('rate_limited', 0) >= 1, feedback_filtered
assert all(e.get('provider') == 'openai_compat' and e.get('action') == 'feedback' and e.get('state') == 'rate_limited' for e in feedback_filtered.get('events', [])), feedback_filtered
print('PASS queue_ai_broker_runtime_json_contract_static')
