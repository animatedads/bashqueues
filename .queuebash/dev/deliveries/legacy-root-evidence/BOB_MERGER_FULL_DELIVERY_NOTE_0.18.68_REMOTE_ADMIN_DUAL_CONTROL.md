# 0.18.68 BOB_MERGER remote-admin dual-control ACL plan approval

Merged Bob10's 0.18.66 branch payload onto the accepted 0.18.67 provider parity report base.

The incoming patchset was treated as branch identity, not as the final release identity. The merged runtime version is `QUEUEBASH_VERSION="0.18.68"`.

Preserved / added:

- `queue remote-admin plan approve PLAN_FILE [--out FILE]`
- `remote-admin.plan.approve` ACL gate
- distinct approver requirement for transaction plans containing `acl.grant`, `acl.deny`, or `acl.revoke`
- apply-time dual-control validation before per-operation ACL checks
- continued `remote-admin.acl.write` requirement for ACL mutations
- secrets remain excluded from transaction plans
- no generic editor, arbitrary shell, secret disclosure, queue dispatch refactor, or live remote mutation path

Merge route:

- source `queuebash.sh` first
- inspect patchset with `queue dev patchset inspect --json`
- patchset precondition failed as expected because the patch was based on 0.18.65 and current head was 0.18.67
- manually reconciled independent remote-admin helper/docs/tests while preserving provider parity report and 105 embedded QBTEST coverage
