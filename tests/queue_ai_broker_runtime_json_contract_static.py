#!/usr/bin/env python3
import json, pathlib, subprocess, sys
root=pathlib.Path(__file__).resolve().parents[1]
cmd=[str(root/'bin/queue-ai-broker')]

def load(args):
    out=subprocess.check_output(cmd+args, cwd=root, text=True)
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
blocked=subprocess.run(cmd+['chat','--profile','balanced','--message','blocked','--live','--json'], cwd=root, text=True, stdout=subprocess.PIPE, check=False)
assert blocked.returncode != 0
blocked_json=json.loads(blocked.stdout)
assert blocked_json['schema']=='queuebash.ai_broker.error.v1'
assert blocked_json['reason']=='live_ai_provider_not_enabled'
print('PASS queue_ai_broker_runtime_json_contract_static')
