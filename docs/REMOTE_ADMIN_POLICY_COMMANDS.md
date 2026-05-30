# Remote admin policy commands

`0.18.58 BOB10` adds a contract-first `queue remote-admin` command surface for administering the remote queue management policy files through typed operations.

It deliberately does **not** add a generic root file editor. The command knows the expected policy file shapes and must fail closed when the caller does not have a matching remote-admin ACL grant.

## Managed files

Default live paths:

```text
/etc/bashqueues/policies.d/remote-queue/remote-management.env
/etc/bashqueues/policies.d/remote-queue/clients.tsv
/etc/bashqueues/policies.d/remote-queue/acl.tsv
/etc/bashqueues/policies.d/remote-queue/secrets/*.secret
/var/log/queuebash/remote-queue-management-audit.jsonl
```

Tests and staging can use `--root DIR`, which maps policy files under:

```text
DIR/policies.d/remote-queue/
DIR/var/log/queuebash/remote-queue-management-audit.jsonl
```

## Security model

Every operation resolves to a named ACL operation before it can read or write policy state. Examples:

```text
remote-admin.validate
remote-admin.config.read
remote-admin.config.write
remote-admin.client.read
remote-admin.client.write
remote-admin.acl.read
remote-admin.acl.write
remote-admin.secret.read-metadata
remote-admin.secret.write
remote-admin.secret.rotate
remote-admin.audit.read
remote-admin.audit.append
remote-admin.audit.verify
```

`remote-admin.acl.write` is the crown-jewel permission because it can grant further authority. It is intentionally separate from the other write permissions and should later be eligible for dual-control or break-glass policy.

No ACL pass means no read/write path.

## Command examples

Validate policy state:

```bash
queue remote-admin --actor admin@example.invalid validate --json
```

Config read/write:

```bash
queue remote-admin --actor admin@example.invalid config show --json
queue remote-admin --actor admin@example.invalid config set QUEUE_REMOTE_MANAGEMENT_LOOPBACK_ONLY 1 \
  --reason "keep listener loopback bound" \
  --ticket CHG-12345 \
  --json
```

Client registry:

```bash
queue remote-admin --actor admin@example.invalid client add london-admin \
  key_id=london-2026q2 \
  subject=queue-admin-london@example.invalid \
  status=active \
  --reason "remote admin onboarding" \
  --ticket CHG-12346 \
  --json
```

ACL grant/revoke:

```bash
queue remote-admin --actor security-admin@example.invalid acl grant london-admin \
  remote.queue.status '*' "read-only queue status" \
  --ticket CHG-12347 \
  --json

queue remote-admin --actor security-admin@example.invalid acl revoke london-admin \
  remote.queue.status '*' \
  --reason "remove temporary grant" \
  --ticket CHG-12348 \
  --json
```

Secret set/rotate/verify from stdin. Secret values are never printed back:

```bash
printf '%s' "$REMOTE_CLIENT_SECRET" | \
queue remote-admin --actor secret-admin@example.invalid secret set london-admin --json

printf '%s' "$REMOTE_CLIENT_SECRET" | \
queue remote-admin --actor secret-admin@example.invalid secret verify london-admin --json
```

Audit:

```bash
queue remote-admin --actor auditor@example.invalid audit tail --json
queue remote-admin --actor auditor@example.invalid audit verify --json
```

## Non-goals

This package does not implement:

```text
remote shell
arbitrary file editing
cloud provisioning
queue dispatch changes
secret disclosure
dual-control approval workflow
networked remote administration transport
```

The command is a local, typed, ACL-gated policy administration helper. A future remote-management service may expose selected operations only through its own authentication, ACL, and audit layer.
