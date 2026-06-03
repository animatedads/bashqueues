#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

doc="docs/SECRETS_PROVIDER_ROADMAP.md"
[[ -f "$doc" ]] || { echo "missing $doc" >&2; exit 1; }

grep -q 'bashqueues must not become the secret store' "$doc"
grep -q 'governed secret access broker' "$doc"
grep -q 'QUEUEBASH_SECRET_<NAME>_FILE=' "$doc"
grep -q 'The result must never include the secret value' "$doc"
grep -q 'Do not solve Secret Zero' "$doc"
grep -q 'Break-glass must be supported only' "$doc"
grep -q 'This roadmap is not an implementation' "$doc"

# The original Bob14 roadmap handoff must not become a secret store or asset-side
# delivery hook. A later Bob17 contract/fixture provider may exist, but it must be
# documented as a governed broker contract and assets.d/secrets.sh must remain absent.
if [[ -e providers.d/secrets/secrets_provider.sh ]]; then
  grep -q 'Implemented follow-up contract' "$doc" || { echo "secrets provider exists without follow-up roadmap note" >&2; exit 1; }
  grep -q 'bashqueues must not become the secret store' "$doc" || { echo "secret-store boundary missing" >&2; exit 1; }
fi
[[ ! -e assets.d/secrets.sh ]] || { echo "unexpected secrets asset added" >&2; exit 1; }

echo "PASS secrets_provider_roadmap_static"
