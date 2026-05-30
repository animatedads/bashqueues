# GCP legal and compliance posture

This document records the legal/compliance shape expected of GCP provider contracts. It does not assert that a GCP class is compliant. All mappings are proposed until validated against primary sources and accepted.

## Required posture areas

```text
region and sovereignty allowlists
data classification labels
retention and deletion evidence
audit log availability
artifact/log redaction
signed URL sensitivity
cross-border review flags
FinOps/cost labels
export-control / ITAR class posture where relevant
shared-responsibility notes
```

## Evidence boundaries

The provider may emit resource identifiers, region, project id, labels, policy references and redacted evidence. It must not store secrets, signed URLs, OAuth tokens, private keys, personal data samples, or full sensitive metadata in scratchpad text, registry JSON, or normal logs.

## Compliance status language

Use:

```text
mapped
proposed
pending validation
accepted by reviewer
```

Do not use:

```text
certified
compliant
FedRAMP-aligned
GDPR-compliant
ITAR-compliant
```

unless the claim is separately validated and accepted.
