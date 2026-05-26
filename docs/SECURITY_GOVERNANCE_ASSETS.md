# Security governance assets

This release adds small governance assets for classification-aware classes and
mandatory policy profiles.

## `audit:stream_verified`

Checks that queue/audit event logging is writable and, for higher
classifications, that a remote audit sink is configured. Parameters include:

- `require_auditd=0|1|auto`
- `require_remote=0|1|auto`
- `stream_file=/path/to/events.jsonl`
- `remote_conf=/etc/audit/auditd.conf`

## `crypto:volume_encrypted`

Checks that a target path appears to be backed by encrypted storage. It accepts
an explicit admin marker for lab/test environments:

```bash
queue_class_shared_asset crypto volume_encrypted "/data/work" allow_marker="/data/work/.queuebash-encrypted"
```

## `net:egress_policy`

Checks the worker's declared egress posture, using `QUEUEBASH_EGRESS_POLICY` or
`/etc/bashqueues/egress-policy.env` by default.

Accepted postures:

- `public-ok`
- `private-only`
- `deny-all` / `airgap`

## Security levels policy

`policies.d/security/levels.env` provides reusable level-to-asset mappings for
`OFFICIAL`, `SENSITIVE`, `CONFIDENTIAL`, `SECRET`, `HIPAA`, and `PROTECTED`.
These can be copied into `CLASS_POLICY_MANDATORY_ASSETS` or used by admin tooling.
