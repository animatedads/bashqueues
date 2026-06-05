# Queue plan dependency model

External plan formats frequently encode implicit dependencies. Bob24 must make them explicit in `queue.control_plan.v1`.

## Common dependencies

```text
Namespace before workload
ServiceAccount before Job/Pod
Secret reference before job template admission
ConfigMap before job template admission
PersistentVolumeClaim before filesystem-using workload
NetworkPolicy before networked workload
Gateway before route attachment
TLS secret before public gateway
IAM role before cloud job execution
Compute environment before job queue
Job queue before job definition submission
Database migration before application rollout
```

## Dependency entry

```json
{
  "from": "identity/app-runner",
  "to": "class/WEB_FRONTEND",
  "reason": "workload uses serviceAccountName"
}
```

The planner should use dependencies to produce explainable staging order and to block live apply when a required control is missing or unsafe.
