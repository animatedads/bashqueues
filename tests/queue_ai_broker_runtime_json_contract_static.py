#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys, tempfile
root=pathlib.Path(__file__).resolve().parents[1]
cmd=[str(root/'bin/queue-ai-broker')]
_tmp=tempfile.TemporaryDirectory(prefix="queue-ai-broker-json-contract.")
env=os.environ.copy()
env["QUEUEBASH_AI_BROKER_HEALTH_CACHE"] = str(pathlib.Path(_tmp.name)/"health-cache.json")

def load(args):
    out=subprocess.check_output(cmd+args, cwd=root, text=True, env=env)
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
blocked=subprocess.run(cmd+['chat','--profile','balanced','--message','blocked','--live','--json'], cwd=root, text=True, stdout=subprocess.PIPE, check=False, env=env)
assert blocked.returncode != 0
blocked_json=json.loads(blocked.stdout)
assert blocked_json['schema']=='queuebash.ai_broker.error.v1'
assert blocked_json['reason']=='live_ai_provider_not_enabled'
print('PASS queue_ai_broker_runtime_json_contract_static')
