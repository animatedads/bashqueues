#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL: $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -q 'queue key-provider help' queuebash.sh || fail 'queue key-provider command help missing'
grep -q '_queue_key_provider_command' queuebash.sh || fail 'key provider command function missing'
grep -q 'queuebash.key_lookup_response.v1' queuebash.sh docs/KEY_PROVIDER_CONTRACT.md || fail 'key lookup response schema missing'
grep -q 'QUEUEBASH_KEY_PROVIDER=file' examples/providers/key/file.env.example || fail 'file key provider example missing'
grep -q '/etc/queuebash/policy/keys/key_registry.tsv' examples/providers/key/file.env.example docs/KEY_PROVIDER_CONTRACT.md || fail 'canonical /etc/queuebash key registry path missing'
! grep -R '/etc/bashqueues' docs/KEY_PROVIDER_CONTRACT.md examples/providers/key/file.env.example policies.d/key/file_registry.example.tsv >/dev/null 2>&1 || fail 'stale /etc/bashqueues path in key provider files'
grep -q 'providers never return shell' docs/KEY_PROVIDER_CONTRACT.md || fail 'provider shell prohibition missing'
grep -q 'malformed registry -> error/fail_closed' docs/KEY_PROVIDER_CONTRACT.md || fail 'malformed fail-closed rule missing'
grep -q 'Vault/HSM' docs/KEY_PROVIDER_CONTRACT.md || fail 'Vault/HSM provider family missing'
grep -q 'IBM HPCS' docs/KEY_PROVIDER_CONTRACT.md || fail 'IBM HPCS provider family missing'
grep -q 'Azure Key Vault' docs/KEY_PROVIDER_CONTRACT.md || fail 'Azure Key Vault provider family missing'

echo '[PASS] key provider registry contract static checks pass'
