#!/usr/bin/env python3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
text=(root/'queuebash.sh').read_text()
for needle in [
    'queuebash.profile_signature_verification.v1',
    'key_provider_consulted',
    'key_provider_lookups',
    'key_provider_trust_not_satisfied',
    'cryptographic_verification_performed',
    'cryptographic_verification_status',
    'profile.sign',
    'file_verifier',
]:
    assert needle in text, needle
assert 'cryptographic_verification_performed": False' in text or 'cryptographic_verification_performed": false' in text
print('PASS profile multisignature file verifier json contract static')
