# Compliance Evidence provider contracts

Status: fixture-first provider-family contract.

## Purpose

advisory compliance evidence coverage for control mapping, evidence pack metadata, attestation status, and retention posture without uploading, deleting, signing, or closing audits.

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
