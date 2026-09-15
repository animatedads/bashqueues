# RTO ask operation boundary

`queue ask --context rto` must distinguish read/check/posture operations from desired-state change operations.

Read-only checks are not deployment plans. For questions about listing services, checking service status, checking drive space, checking drive health, or database posture, the advisory context must prefer the RTO operation/provider path:

```bash
queue rto operations service
queue rto provider select list-running-services linux linux-service-inventory
queue rto explain check services linux-service-inventory
```

For drive-space posture:

```bash
queue rto operations disk
queue rto provider select check-free-drive-space linux mail-server-01
queue rto explain check disks mail-server-01
```

Use `queue rto plan ...` only for desired-state/change activities such as deploying a VM, installing MySQL, securing MySQL, or deploying a codebase. When a plan is created, capture the returned plan id/path and reuse it for explain/preflight; do not casually use `latest` across queued steps.

RTO is not a raw remote shell. Direct provider-level commands should be shown only as target-side provider smoke tests when the operator explicitly asks for provider testing and has the required authority.
