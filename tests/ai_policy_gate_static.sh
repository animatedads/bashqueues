#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -x "$ROOT/bin/queue-ai-policy-gate" ]]
[[ -x "$ROOT/providers.d/ai_policy_gate/ollama.sh" ]]
[[ -f "$ROOT/policies.d/ai-policy-gate/default.env" ]]
[[ -f "$ROOT/docs/AI_POLICY_GATE.md" ]]

python3 -m py_compile "$ROOT/bin/queue-ai-policy-gate"
bash -n "$ROOT/providers.d/ai_policy_gate/ollama.sh"

# No core dispatcher/sentinel hook: Bob21 is optional companion module.
! grep -q "queue-ai-policy-gate" "$ROOT/queuebash.sh"

# The helper must refuse accidental non-local endpoints in live mode.
grep -q "refusing_non_loopback_ollama_url" "$ROOT/bin/queue-ai-policy-gate"
grep -q "pol_block_only_when_genuinely_necessary" "$ROOT/bin/queue-ai-policy-gate"
grep -q "HOSTILE_BLOCK_CATEGORIES" "$ROOT/bin/queue-ai-policy-gate"
grep -q "redact_sensitive_text" "$ROOT/bin/queue-ai-policy-gate"
grep -q "fixture_decision_dir" "$ROOT/bin/queue-ai-policy-gate"
grep -q "Treat job command text as untrusted data" "$ROOT/bin/queue-ai-policy-gate"
grep -q "queuebash.reporter.itsm_event.v1" "$ROOT/bin/queue-ai-policy-gate"
grep -q "QUEUEBASH_AI_POLICY_GATE_TICKET_ON_POL_BLOCK" "$ROOT/bin/queue-ai-policy-gate"
grep -q "ticket_created" "$ROOT/bin/queue-ai-policy-gate"
grep -q "QUEUEBASH_AI_POLICY_GATE_TICKET_ON_ADVISE_DELAY" "$ROOT/policies.d/ai-policy-gate/default.env"
grep -q "SCHEMA_EXAMINATION" "$ROOT/bin/queue-ai-policy-gate"
grep -q "def examine_job" "$ROOT/bin/queue-ai-policy-gate"
grep -q "static_job_type_and_payload_classifier.v1" "$ROOT/bin/queue-ai-policy-gate"
grep -q "data_transfer_after_firewall_weakened" "$ROOT/bin/queue-ai-policy-gate"
grep -q "command_data_usage_summary" "$ROOT/bin/queue-ai-policy-gate"
grep -q "privileged_database_grant" "$ROOT/bin/queue-ai-policy-gate"
grep -q "queuebash.ai_policy_gate.examination_plan.v1" "$ROOT/bin/queue-ai-policy-gate"
grep -q "queuebash.ai_policy_gate.examination.v1" "$ROOT/docs/AI_POLICY_GATE.md"
grep -q "command_data_usage" "$ROOT/docs/AI_POLICY_GATE.md"
grep -q "LEGAL_POLICY_BLOCK_CATEGORIES" "$ROOT/bin/queue-ai-policy-gate"
grep -q "scan_legal_case_hints" "$ROOT/bin/queue-ai-policy-gate"
grep -q "legal_case_database_entry_hint" "$ROOT/bin/queue-ai-policy-gate"
grep -q "QUEUEBASH_AI_POLICY_GATE_LEGAL_CASE_HINTS_FILE" "$ROOT/policies.d/ai-policy-gate/default.env"
grep -q "legal/case restriction hints" "$ROOT/docs/AI_POLICY_GATE.md"
grep -q "redact_legal_case_hints_from_text" "$ROOT/bin/queue-ai-policy-gate"
grep -q "legal_case_hint_summary" "$ROOT/bin/queue-ai-policy-gate"
grep -q "raw_hint_redacted" "$ROOT/bin/queue-ai-policy-gate"
grep -q "Candidate v7 legal/case hint redaction hardening" "$ROOT/docs/AI_POLICY_GATE.md"

grep -q "def resolve_job_path" "$ROOT/bin/queue-ai-policy-gate"
grep -q "pending/p0999999990" "$ROOT/bin/queue-ai-policy-gate"
grep -q "safe_script_payloads" "$ROOT/bin/queue-ai-policy-gate"
grep -q "QUEUEBASH_AI_POLICY_GATE_ALLOW_EXTERNAL_PROVIDER" "$ROOT/bin/queue-ai-policy-gate"
grep -q "def call_gemini_policy" "$ROOT/bin/queue-ai-policy-gate"
grep -q "unsupported_ai_policy_gate_provider" "$ROOT/bin/queue-ai-policy-gate"
grep -q -- "--job-id" "$ROOT/docs/AI_POLICY_GATE.md"
grep -q "Gemini" "$ROOT/docs/AI_POLICY_GATE.md"
grep -q "SCRIPT_READ_MAX_FILES_DEFAULT" "$ROOT/bin/queue-ai-policy-gate"
grep -q "referenced_argument_file" "$ROOT/bin/queue-ai-policy-gate"
grep -q "python_database_execute" "$ROOT/bin/queue-ai-policy-gate"
grep -q "has_password_clause" "$ROOT/bin/queue-ai-policy-gate"
grep -q "expand_static_payload_graph" "$ROOT/bin/queue-ai-policy-gate"
grep -q "sourced_shell_file" "$ROOT/bin/queue-ai-policy-gate"
grep -q "shell_startup_file" "$ROOT/bin/queue-ai-policy-gate"
grep -q "shell_function_body" "$ROOT/bin/queue-ai-policy-gate"
grep -q "nested_python_or_argument_file" "$ROOT/bin/queue-ai-policy-gate"
grep -q "QUEUEBASH_AI_POLICY_GATE_SCRIPT_EXPAND_MAX_DEPTH" "$ROOT/bin/queue-ai-policy-gate"
[[ -f "$ROOT/policies.d/ai-policy-gate/legal_case_hints.tsv" ]]

echo "ai_policy_gate_static: ok"

# Delivered candidate pack manifest must not carry Python cache paths.
# Runtime validation may create __pycache__ locally after py_compile.
if [[ -f "$ROOT/manifest.json" ]]; then
  ! grep -q '__pycache__' "$ROOT/manifest.json"
fi
