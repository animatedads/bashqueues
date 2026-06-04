#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/workflow_orchestrator/workflow_orchestrator_provider.sh"
[[ -x "$helper" ]]
[[ -f "docs/WORKFLOW_ORCHESTRATOR_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/WORKFLOW_ORCHESTRATOR_EXPLAINABILITY.md" ]]
[[ -f "docs/WORKFLOW_ORCHESTRATOR_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/workflow_orchestrator/default-policy.example.json" ]]
# The helper must remain fact-only and must not advertise common escape tools.
# Do not forbid the literal word "shell" because provider_output_is_shell=false is a required JSON field.
if grep -E "\b(sudo|curl|wget|ssh|scp|nc|eval)\b" "$helper" >/dev/null; then
  echo "unexpected executable/remote-tool wording in $helper" >&2
  exit 1
fi
printf 'PASS workflow_orchestrator_provider_contracts_static
'
