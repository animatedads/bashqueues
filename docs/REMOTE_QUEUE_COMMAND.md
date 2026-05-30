# `queue remote` command plugin

`0.18.31` adds the first system command plugin for the remote queue service line:

```text
queue remote <service> <command structure>
```

This is a client-side command surface for signed, named remote queue service operations. It does not make the local `queue` command a cloud scheduler, and it does not expose a shell.

## Command shape

```text
queue remote list [--json]
queue remote add SERVICE --url URL (--secret SECRET|--secret-file FILE|--secret-env ENV) [--json]
queue remote show SERVICE [--json]
queue remote SERVICE health [--json]
queue remote SERVICE version [--json]
queue remote SERVICE capabilities [--json]
queue remote SERVICE queue status [--json]
queue remote SERVICE queue list [--json]
queue remote SERVICE job explain JOBID [--json]
queue remote SERVICE job tail JOBID [--json]
queue remote SERVICE worker status [--json]
queue remote SERVICE service ps [--json]
queue remote SERVICE raw OPERATION [TARGET] [--json]
```

The `raw` form is still guarded by the client allowlist unless `QUEUE_REMOTE_ALLOW_RAW_OPERATIONS=1` is explicitly set in the service configuration. It must not be used as a shell bypass.

## Creating a connection entry

Use `queue remote add` to create the local client-side service entry.  This command writes only the client configuration under `remote.d`; it does not mutate the remote server ACL, client registry, listener policy, or secret store.

Example for a local listener on `127.0.0.1:8765`:

```bash
mkdir -p "$HOME/.queuebash/secrets"
printf '%s\n' 'PUT_THE_SHARED_SECRET_HERE' > "$HOME/.queuebash/secrets/local-management.secret"
chmod 600 "$HOME/.queuebash/secrets/local-management.secret"

queue remote add local-management \
  --url http://127.0.0.1:8765 \
  --endpoint /remote-queue \
  --client-id queue-admin \
  --key-id default \
  --secret-file "$HOME/.queuebash/secrets/local-management.secret"

queue remote local-management queue list --json
```

If you want the helper to write the local secret file at the same time, pass `--secret SECRET`.  The secret value is never printed by `queue remote add` or `queue remote show`.  The same secret/key identity must already be accepted by the remote listener's server-side client registry and ACL.

Useful setup options:

```text
--config-dir DIR       Write SERVICE.env to DIR instead of $QUEUEBASH_ROOT/remote.d
--secret-dir DIR       Write generated/inline secret files to DIR instead of $QUEUEBASH_ROOT/secrets
--secret-file FILE     Reference an existing secret file
--secret-env ENV       Reference a secret-bearing environment variable
--force                Replace an existing SERVICE.env
--dry-run              Show what would be written without creating files
--json                 Emit machine-readable setup result
```

## Service configuration

A service named `oci-node-b` is loaded from `oci-node-b.env` in one of these directories:

```text
$QUEUE_REMOTE_CONFIG_DIR
$QUEUEBASH_REMOTE_CONFIG_DIR
$QUEUEBASH_ROOT/remote.d
./remote.d
/etc/queuebash/policy/remote.d
/etc/queuebash/policy/providers.d/remote.d
/etc/queuebash/policy/providers.d
```

Example:

```env
QUEUE_REMOTE_SERVICE=oci-node-b
QUEUE_REMOTE_URL=http://127.0.0.1:8443
QUEUE_REMOTE_ENDPOINT=/remote-queue
QUEUE_REMOTE_CLIENT_ID=oci-node-a
QUEUE_REMOTE_KEY_ID=node-a-readonly
QUEUE_REMOTE_SECRET_FILE=/etc/queuebash/policy/remote.d/oci-node-b.secret
QUEUE_REMOTE_REQUEST_TTL_SECONDS=60
QUEUE_REMOTE_HTTP_TIMEOUT_SECONDS=30
QUEUE_REMOTE_ALLOW_RAW_OPERATIONS=0
```

Secrets should be stored in a separate secret file or injected through a named environment variable. `queue remote show SERVICE` redacts secret-bearing fields.

## Request contract

The client emits signed requests using the two-node probe request schema:

```json
{
  "schema": "queuebash.remote_queue_request.v1",
  "client_id": "oci-node-a",
  "key_id": "node-a-readonly",
  "operation": "queue.status",
  "target": "",
  "nonce": "example",
  "issued_at": "2026-05-29T15:00:00Z",
  "expires_at": "2026-05-29T15:01:00Z",
  "signature": "hmac-sha256:example"
}
```

The signing canonical form covers schema, client id, key id, operation, target, nonce, issued time, and expiry. Provider responses are treated as data and are never evaluated as shell.

## Safety boundary

`queue remote` deliberately exposes a small read-only client surface in this package:

```text
health
version
capabilities
queue.status
queue.list
job.explain
job.tail
worker.status
service.ps
```

The client rejects obvious shell or mutation aliases such as `run`, `exec`, `shell`, `command`, `cmd`, `bash`, `sh`, `kill`, and `cancel`. Remote mutation operations must be added later as named, policy-gated capabilities with tests and audit coverage.

## Example live probe

With a compatible read-only remote provider running on Node B:

```bash
mkdir -p "$QUEUEBASH_ROOT/remote.d"
cp examples/remote.d/oci-node-b.env.example "$QUEUEBASH_ROOT/remote.d/oci-node-b.env"
printf '%s\n' "$REMOTE_QUEUE_TEST_SECRET" > /etc/queuebash/policy/remote.d/oci-node-b.secret
chmod 600 /etc/queuebash/policy/remote.d/oci-node-b.secret

queue remote list
queue remote show oci-node-b
queue remote oci-node-b health
queue remote oci-node-b queue list
queue remote oci-node-b job explain 20260527_231153_1779919913231223_011340_412076
```

