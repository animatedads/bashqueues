# IBM Cloud legal compliance

Status: **mapped_pending_validation**

IBM Cloud classes and the provider contracts describe compliance postures, but
primary-source validation has not been completed for most frameworks. Do not
market IBM Cloud classes as compliant without independent org-policy review,
primary-source legal validation, and explicit acceptance.

## Areas requiring mapping before acceptance

### Region and sovereignty

- GDPR/EU regions (`eu-de`, `eu-gb`, `eu-es`) are mapped but not primary-source
  validated for all data types.
- UK DPA region (`eu-gb`) is mapped; post-Brexit adequacy assumptions must be
  reviewed by legal counsel.
- Financial Services validated regions use IBM's published FS-validated region
  list, which should be reverified against the current IBM FS Cloud documentation.

### Data residency

- IBM Cloud data residency guarantees vary by service and plan tier.
- Object Storage (COS) cross-region resilience may route data outside a single
  sovereignty zone; class posture must specify single-region or cross-region.
- Database-as-a-service (Databases for PostgreSQL, etc.) backup residency must
  be documented per class.

### Retention and deletion

- Retention policy application (`ibm_finops:cost_cache_fresh` and
  `legal retention_respected`) is gated but not self-auditing.
- Deletion evidence for object storage buckets requires Key Protect or HPCS
  key-deletion confirmation; this is not checked by the current asset gates.

### Audit and logging

- IBM Activity Tracker with LogDNA is the expected audit evidence path.
- IBM Cloud Logs (next-generation) replaces LogDNA in newer accounts; class
  documentation must specify which log target is expected.
- Log retention period must be asserted in class documentation.

### Export control and ITAR

- IBM Cloud does not have a FedRAMP-equivalent export-controlled offering
  accessible to all accounts by default.
- ITAR/EAR workloads must be reviewed separately with IBM account teams.
- Classes asserting ITAR posture should carry explicit `validation_status:
  requires_org_review` until export-control review is complete.

### Shared responsibility

- IBM is responsible for infrastructure-level controls; the operator is
  responsible for application-layer data protection, key management, and
  access control.
- Class posture must not imply IBM handles application-layer compliance
  obligations.

## Validation checklist (before promoting to first_tier_contract)

- [ ] Primary-source IBM Cloud documentation review for each framework
- [ ] IBM FS Cloud validated region list reverified
- [ ] Retention and deletion evidence path confirmed per service type
- [ ] Audit log target (Activity Tracker / IBM Cloud Logs) documented
- [ ] Export-control posture reviewed with IBM account team
- [ ] Legal counsel sign-off on GDPR and UK DPA adequacy assumptions
- [ ] Shared-responsibility matrix documented
