# 0.18.69 BOB_MERGER remote connection entry command merge

Merged the remote connection entry command patchset onto the accepted 0.18.68 remote-admin dual-control base.

## Source

- Base: `bashqueues_0.18.68_BOB_MERGER_remote_admin_dual_control_acl_plan_approval_full_delivery.zip`
- Patch: `bashqueues_0.18.67_remote_connection_entry_command_patchset.zip`

## Merger decision

The incoming `0.18.67` patch identity is treated as a branch payload. Because the current merger head is already `0.18.68` and the patch adds real command surface, this full delivery uses `QUEUEBASH_VERSION=0.18.69`.

## Added behaviour

- `queue remote add SERVICE --url URL (--secret SECRET | --secret-file FILE | --secret-env ENV)`
- Client-side `remote.d` service entry creation
- Optional local secret file creation when `--secret` is supplied
- `--config-dir`, `--secret-dir`, `--ttl-seconds`, `--timeout-seconds`, `--allow-raw`, `--force`, `--dry-run`, and `--json`
- Secret-bearing values remain redacted by show/add output

## Boundary preserved

- Does not mutate server-side remote-admin ACL/client registry/listener policy
- Does not expose `run`, `shell`, `exec`, or `cmd`
- Preserves remote-admin transaction and dual-control work from 0.18.68
- Preserves embedded QBTEST function coverage
