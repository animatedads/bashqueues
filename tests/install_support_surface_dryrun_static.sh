#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

bash -n install-system.sh

plan="$(bash install-system.sh --dryrun)"
grep -q '^  support dirs:  ' <<<"$plan"

for dir in providers.d policies.d tests resources.d schemas docs assets.d bin classes fixtures contracts; do
  [[ -d "$dir" ]] || continue
  grep -q "\b$dir\b" <<<"$plan"
  grep -q "\b$dir\b" install-system.sh
done

grep -q 'providers.d/remote_admin/remote_admin_policy.sh' install-system.sh
test -x providers.d/remote_admin/remote_admin_policy.sh
