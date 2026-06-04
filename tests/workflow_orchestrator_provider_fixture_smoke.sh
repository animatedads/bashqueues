#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/workflow_orchestrator/workflow_orchestrator_provider.sh"
QUEUEBASH_WORKFLOW_ORCHESTRATOR_FIXTURE_DIR="$PWD/tests/fixtures/workflow_orchestrator" "$helper" detect > /tmp/workflow_orchestrator_detect.json
python3 -m json.tool /tmp/workflow_orchestrator_detect.json >/dev/null
QUEUEBASH_WORKFLOW_ORCHESTRATOR_FIXTURE_DIR="$PWD/tests/fixtures/workflow_orchestrator" "$helper" workflow explain > /tmp/workflow_orchestrator_workflow.json
python3 -m json.tool /tmp/workflow_orchestrator_workflow.json >/dev/null
QUEUEBASH_WORKFLOW_ORCHESTRATOR_FIXTURE_DIR="$PWD/tests/fixtures/workflow_orchestrator" "$helper" schedule explain > /tmp/workflow_orchestrator_schedule.json
python3 -m json.tool /tmp/workflow_orchestrator_schedule.json >/dev/null
QUEUEBASH_WORKFLOW_ORCHESTRATOR_FIXTURE_DIR="$PWD/tests/fixtures/workflow_orchestrator" "$helper" dependency explain > /tmp/workflow_orchestrator_dependency.json
python3 -m json.tool /tmp/workflow_orchestrator_dependency.json >/dev/null
QUEUEBASH_WORKFLOW_ORCHESTRATOR_FIXTURE_DIR="$PWD/tests/fixtures/workflow_orchestrator" "$helper" governance explain > /tmp/workflow_orchestrator_governance.json
python3 -m json.tool /tmp/workflow_orchestrator_governance.json >/dev/null
printf 'PASS workflow_orchestrator_provider_fixture_smoke
'
