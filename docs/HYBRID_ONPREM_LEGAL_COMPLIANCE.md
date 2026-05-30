# Hybrid/on-prem legal and compliance posture

Status: mapped pending validation.

Hybrid/on-prem estates often sit inside organisation-controlled datacentres, managed private clouds, or regulated regional platforms. That does not automatically satisfy legal, export-control, retention, deletion, or audit requirements.

The contract therefore records posture rather than asserting compliance:

- legal framework mapping such as GDPR, UK DPA, customer-specific retention, or export-control review
- datacenter/site/cluster/namespace boundaries
- data residency and replication posture
- audit trail availability
- retention and deletion evidence
- break-glass and privileged-access review posture
- artifact/log redaction rules

No class or provider in this package should be described as compliant or first-tier solely because it has fixtures. Primary-source/customer-policy validation and platform-specific tests are required before acceptance as compliance criteria.
