#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "[FAIL] $*" >&2; exit 1; }
canonical='/etc/queuebash/policies.d'
legacy='/etc/bashqueues/policies.d'

[[ -f queuebash.sh ]] || fail 'run from repository root'

docs=(
  docs/CLASS_POLICY_STATEMENT.md
  docs/CODE_SIGNING.md
  docs/ENDPOINT_GOVERNANCE.md
  docs/POLICYBLOCK_TEST.md
  docs/POLICY_BLOCKED.md
  docs/POLICY_COMMAND_BLOCKS.md
  docs/REPORTING_PLUGINS.md
  docs/ROOT_POLICY_EDITOR.md
  docs/SECURITY_POLICIES.md
  docs/QUEUE_AI_BROKER.md
  docs/QUEUE_AI_BROKER_IMPLEMENTATION.md
  docs/QUEUE_AI_BROKER_HEALTH_CACHE.md
  examples/remote.d/local-management.env.example
)
for f in "${docs[@]}"; do
  [[ -f "$f" ]] || fail "missing checked doc/example: $f"
  grep -q "$canonical" "$f" || fail "missing canonical policy root in $f"
  if grep -q "$legacy" "$f"; then
    fail "legacy policy root remains in active operator copy/paste path: $f"
  fi
done

# Migration/status docs may mention the legacy root, but must also name the canonical root.
for f in docs/POLICY_NAMESPACE.md docs/SYSTEM_INSTALL.md docs/REGULATED_SERVICE_RUNBOOK.md docs/OPERATOR_RUNBOOK.md; do
  [[ -f "$f" ]] || fail "missing namespace/status doc: $f"
  grep -q "$canonical" "$f" || fail "namespace/status doc missing canonical root: $f"
done

bash -n queuebash.sh || fail 'queuebash syntax failed'
echo '[PASS] operator policy namespace docs use canonical active root'
