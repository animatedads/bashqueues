# Remote queue management listener

This package adds an optional server-side listener for the existing `queue remote` client command.  The listener is **not installed or enabled by default**.  It exposes only the read-only named operations already used by the client:

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

It does not expose `run`, `exec`, `shell`, `command`, `cmd`, `bash`, `sh`, `kill`, `cancel`, host-wide `ps`, or arbitrary filesystem access.

## Install

System installation remains opt-in:

```bash
sudo ./install-system.sh --with-remote-listener
```

The installer copies the listener, creates `/etc/bashqueues/policies.d/remote-queue/`, copies default policy files there when absent (`remote-management.env`, `clients.tsv`, and `acl.tsv`), and installs/enables `bashqueues-remote-management.service` when `systemctl` is available. The copied `clients.tsv` and `acl.tsv` remain deny-by-default templates until an administrator adds real clients, secrets, and grants.

The listener binds to `127.0.0.1:8765` by default.  Production exposure should normally be through SSH forwarding, mTLS, a VPN, or another organisation-approved transport boundary.

## Policy files

Canonical files:

```text
/etc/bashqueues/policies.d/remote-queue/remote-management.env
/etc/bashqueues/policies.d/remote-queue/clients.tsv
/etc/bashqueues/policies.d/remote-queue/acl.tsv
/etc/bashqueues/policies.d/remote-queue/secrets/*.secret
/var/log/queuebash/remote-queue-management-audit.jsonl
```

`clients.tsv` registers HMAC clients:

```text
client_id<TAB>key_id<TAB>subject<TAB>secret_file<TAB>status<TAB>comment
```

`acl.tsv` grants named operations:

```text
subject<TAB>operation<TAB>resource<TAB>decision<TAB>reason
```

No matching ACL line means deny/fail-closed.  Malformed ACL or client registry files also deny/fail-closed.

Example minimal read-only grant:

```text
queue-admin@example.invalid	health	*	allow	remote management health check
queue-admin@example.invalid	version	*	allow	remote management version check
queue-admin@example.invalid	capabilities	*	allow	remote management capabilities
queue-admin@example.invalid	queue.status	*	allow	read queue status
queue-admin@example.invalid	queue.list	*	allow	read queue list
queue-admin@example.invalid	job.explain	*	allow	read job explain
queue-admin@example.invalid	job.tail	*	allow	read bounded job tail
queue-admin@example.invalid	worker.status	*	allow	read worker status
queue-admin@example.invalid	service.ps	*	allow	read queue-owned service process view
```

## Request verification

The listener accepts `queuebash.remote_queue_request.v1`, validates request shape, rejects expired or long-TTL requests, verifies the HMAC signature from the registered client secret, records seen nonces to reduce replay, checks the remote-management ACL, executes only a fixed read-only operation mapping, bounds stdout/stderr, and writes a JSONL audit event.

Provider output is data. No returned value is evaluated as shell.
