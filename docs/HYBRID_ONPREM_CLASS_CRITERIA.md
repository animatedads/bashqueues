# Hybrid/on-prem class criteria

Hybrid/on-prem classes describe governance and placement posture for private cloud and platform estates. They do not imply live provisioning.

Candidate rails:

- identity: service account, project/tenant/namespace binding, RBAC role, audit subject
- region/site: datacenter, availability zone, cluster, namespace, sovereign/legal site tags
- virtualization/platform: hypervisor, cloud project, OpenShift cluster/namespace, image/template posture
- storage/artifacts: datastore, volume class, object artifact sink, signed URL/redaction rules where relevant
- network: VLAN/portgroup/security group/namespace egress posture
- legal/compliance: retention, deletion, evidence, GDPR/UK-DPA/export-control review
- FinOps/capacity: quota, chargeback, cost centre, GPU/CPU/memory/storage ceilings

Classes in this package are examples only and remain mapped pending validation.
