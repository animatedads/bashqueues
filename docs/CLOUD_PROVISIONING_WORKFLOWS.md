# Cloud provisioning workflows

## Contract-only workflow

```text
select named template
  -> plan
  -> validate policy gates
  -> explain decision
  -> dry-run evidence
  -> no mutation
```

Example:

```bash
providers.d/cloud_provision/cloud_provision.sh plan aws-ec2-gdpr --json
providers.d/cloud_provision/cloud_provision.sh explain aws-ec2-gdpr --json
providers.d/cloud_provision/cloud_provision.sh dry-run aws-ec2-gdpr --json
```

## Future registry handoff workflow

A later package may add:

```text
plan allow/review
  -> approval/change-ticket gate
  -> cloud_resource planned record
  -> lifecycle helper dry-run
  -> explicit live apply gate
  -> provider helper action
  -> cloud_resource reconcile
  -> claimable resource
```

The handoff boundary matters: the lifecycle helper may move a named service, but
`cloud_resource` remains the booking desk used by classes/assets.

## Customer database example

A UK branch asking to deploy customer data to a US cloud region must be treated
as cross-border customer-data work. A plan should not imply that technical region
gating is enough. It should separate:

```text
authority and change ticket
customer-data classification
legal/data-transfer basis
retention and legal hold
region and sovereignty gates
cloud_resource availability/claim facts
audit evidence
queue explain before execution
```
