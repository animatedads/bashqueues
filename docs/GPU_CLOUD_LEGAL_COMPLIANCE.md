# GPU cloud legal and compliance posture

Status: **mapped pending validation**.

GPU cloud provider contracts must consider:

- data residency and sovereignty
- model/artifact retention and deletion evidence
- export-control/ITAR/EAR-style review for GPU workloads where applicable
- sensitive personal data handling
- customer-data handling and legal hold/retention requirements
- audit evidence and immutable logs
- signed URL and token redaction
- shared responsibility between provider, tenant, Kubernetes/cluster operator, and workload owner

This package does not assert legal compliance for CoreWeave, Lambda Cloud, or NVIDIA DGX Cloud. It provides fixtures, docs, and tests to help future packages map primary-source validated controls into bashqueues provider contracts.
