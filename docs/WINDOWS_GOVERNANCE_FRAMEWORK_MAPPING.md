# Windows governance framework mapping for Queue

Queue now carries a local governance reference registry for Windows high-risk operations mapped to CIS Controls v8 and NIST SP 800-53 Rev. 5.

This is Queue-owned policy evidence. It does not grant authority and it does not execute operations.

Operator commands:

```bash
queue governance frameworks --json
queue governance controls cis_controls_v8 --json
queue governance controls nist_sp_800_53_rev5 --json
queue governance windows-risk --json
queue governance classify-windows 'disable defender' --json
```

Queue behaviour guidance:

* Read/check/posture operations should be audited and explained without forcing an RTO deployment plan path.
* Change/deploy/destructive operations should be parked in `waiting` until approval, maintenance-window, rollback/restore, and receipt evidence are satisfied.
* RTO can consume this via `queue rto queue-services --json` under the `governance` service.
