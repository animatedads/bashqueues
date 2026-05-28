#!/usr/bin/env python3
from pathlib import Path
q = Path('queuebash.sh').read_text()
d = Path('docs/KEY_PROVIDER_CONTRACT.md').read_text()
assert 'queuebash.key_lookup_request.v1' in d
assert 'queuebash.key_lookup_response.v1' in d
assert 'public_key_ref' in q and 'public_key_ref' in d
assert 'revoked' in q and 'delegation' in q
assert 'ttl_seconds' in q and 'cache_policy' in q
assert 'fail_closed' in q
assert 'providers never return shell' in d
assert 'missing, malformed, or failed provider output fails closed' in d
print('[PASS] key provider JSON contract static checks pass')
