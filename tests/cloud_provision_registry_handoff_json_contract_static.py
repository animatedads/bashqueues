#!/usr/bin/env python3
import json
import subprocess

provider = 'providers.d/cloud_provision/cloud_provision.sh'
explain = json.loads(subprocess.check_output([provider, 'handoff-explain', 'aws-ec2-gdpr', '--json'], text=True))
assert explain['schema'] == 'queuebash.cloud_provision.handoff_explain.v1'
assert explain['decision'] in ('allow', 'review')
assert explain['registry_write'] is False
assert explain['mutated'] is False
assert explain['live'] is False
assert explain['state'] == 'planned'
assert isinstance(explain['gates'], list) and explain['gates']

deny = subprocess.run([provider, 'handoff-explain', 'bad-missing-region', '--json'], text=True, stdout=subprocess.PIPE, check=False)
payload = json.loads(deny.stdout)
assert payload['schema'] == 'queuebash.cloud_provision.handoff_explain.v1'
assert payload['decision'] == 'deny'
assert payload['fail_closed'] is True

print('PASS cloud_provision_registry_handoff_json_contract_static')
