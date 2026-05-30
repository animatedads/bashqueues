#!/usr/bin/env python3
import json, pathlib, subprocess, sys
root = pathlib.Path(__file__).resolve().parents[1]
provider = root / 'providers.d/grid_energy/grid_energy_provider.sh'
fixture = root / 'tests/fixtures/grid_energy/allow_cheap_green.json'

def run(*args):
    return subprocess.check_output([str(provider), *args], text=True, cwd=root)

explain = json.loads(run('explain', '--json'))
assert explain['schema'] == 'queuebash.grid_energy.provider.v1'
assert explain['provider'] == 'grid_energy'
assert explain['fixture_first'] is True
assert explain['live_call_performed'] is False
assert explain['mutation_performed'] is False

decision = json.loads(run('evaluate', '--cache', str(fixture), '--market', 'uk_eso', '--zone', 'GB', '--max-price-per-kwh', '0.15', '--max-carbon-gco2-kwh', '120', '--max-age-seconds', '999999999', '--json'))
assert decision['schema'] == 'queuebash.grid_energy.decision.v1'
assert decision['decision'] == 'allow'
assert decision['live_call_performed'] is False
assert decision['mutation_performed'] is False
assert decision['advisory_only'] is True
assert decision['price_per_kwh'] <= 0.15
assert decision['carbon_gco2_kwh'] <= 120
print('PASS grid energy JSON contract')
