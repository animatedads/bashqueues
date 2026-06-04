# Compliance Evidence explainability

Status: fixture-first provider-family contract.

## Purpose

Compliance Evidence outputs are advisory evidence facts. Explain responses must show source=fixture, redacted=true where identities/evidence could identify people or regulated data, and provider_output_is_shell=false.

## Safety contract

- No live provider calls in default tests.
- No credentials required for fixture tests.
- Normalized JSON only.
- Provider output is data, never shell.
- No provisioning, destruction, mutation, approval, or queue dispatch refactor.
- Values that may identify people, secrets, regulated evidence, or operational topology must be redacted in fixtures and docs.

## Commands

```text
  providers.d/compliance_evidence/compliance_evidence_provider.sh detect
  providers.d/compliance_evidence/compliance_evidence_provider.sh control explain
  providers.d/compliance_evidence/compliance_evidence_provider.sh evidence_pack explain
  providers.d/compliance_evidence/compliance_evidence_provider.sh attestation explain
  providers.d/compliance_evidence/compliance_evidence_provider.sh retention explain
```

## Non-goals

- evidence-upload
- evidence-delete
- attestation-sign
- control-acceptance
- audit-close
- queue-dispatch-refactor
