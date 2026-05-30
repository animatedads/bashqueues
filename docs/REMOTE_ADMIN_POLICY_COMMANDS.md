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
networked remote administration transport
```

The command is a local, typed, ACL-gated policy administration helper. A future remote-management service may expose selected operations only through its own authentication, ACL, and audit layer.

## 0.18.60 remote-admin plan/apply/rollback contract

`queue remote-admin` now has a transaction-shaped administration path for policy changes.  This is still not a generic editor: plans contain typed operations only, and `apply` re-checks ACL authority before mutating any policy file.

Supported transaction commands:

```bash
queue remote-admin --actor ACTOR plan create --out plan.json \
  --config-set KEY=VALUE \
  --client-add CLIENT_ID:key_id=KEY:subject=SUBJECT \
  --acl-grant SUBJECT:OPERATION:RESOURCE[:REASON] \
  --json

queue remote-admin --actor ACTOR plan show plan.json --json
queue remote-admin --actor ACTOR apply plan.json --json
queue remote-admin --actor ACTOR rollback list --json
queue remote-admin --actor ACTOR rollback show ROLLBACK_ID --json
queue remote-admin --actor ACTOR rollback apply ROLLBACK_ID --json
```

ACL gates:

```text
remote-admin.plan.read
remote-admin.plan.write
remote-admin.plan.apply
remote-admin.rollback.read
remote-admin.rollback.apply
```

`apply` also checks the underlying operation authority for every item in the plan.  A plan containing `acl.grant`, `acl.deny`, or `acl.revoke` therefore requires both `remote-admin.plan.apply` and `remote-admin.acl.write`.  This preserves the crown-jewel rule: the authority that applies a transaction is not automatically the authority to edit the ACL.

Rollback records are stored under the policy directory as local JSON snapshots of the managed policy files.  They are intended as operational recovery evidence for typed policy edits, not as a general backup system.

Secrets remain outside transaction plans.  Secret set/rotate/verify continue to be stdin-only so secret material is not written into plan files, audit notes, shell history, or patch artifacts.

## 0.18.66 dual-control for ACL-write plans

Plans that contain `acl.grant`, `acl.deny`, or `acl.revoke` are now treated as dual-control plans. They may be created by an operator with `remote-admin.plan.write`, but they cannot be applied until a distinct approver with `remote-admin.plan.approve` has approved the plan.

Approval command:

```bash
queue remote-admin --actor security-admin@example.invalid plan approve plan.json \
  --reason "approved ACL change under CHG-12349" \
  --ticket CHG-12349 \
  --json
```

The approval is written back to the plan file unless `--out FILE` is supplied:

```bash
queue remote-admin --actor security-admin@example.invalid plan approve plan.json \
  --out approved-plan.json \
  --json
```

Additional ACL gate:

```text
remote-admin.plan.approve
```

Rules:

```text
non-ACL plans do not require dual-control approval
ACL-write plans require at least one approval by an actor distinct from the plan creator
apply still re-checks remote-admin.plan.apply
apply still re-checks remote-admin.acl.write for each ACL mutation
remote-admin.acl.write remains the crown-jewel permission
secret operations remain excluded from transaction plans
```

This is a file-backed approval evidence contract, not cryptographic signing. Production deployments should protect plan files through filesystem permissions and may later add command-bound signatures or external approval providers.
