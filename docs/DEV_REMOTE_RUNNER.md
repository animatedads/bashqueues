# Remote dev runner bridge

`bin/queue-dev-runner.py` is a temporary, authenticated, capability-scoped queue-dev control plane for an external build/test VM.

It is deliberately **not** a shell and **not** a general remote command runner. Version 0.18.27 exposes named operations only:

- `GET /healthz`
- `POST /session/create` using a one-time bootstrap code printed on the server console
- `POST /upload` or `POST /session/<session_id>/upload`
- `POST /test` or `POST /session/<session_id>/test`
- `POST /patch-function` or `POST /session/<session_id>/patch-function`
- `POST /splice` or `POST /session/<session_id>/splice`
- `POST /ps` or `POST /session/<session_id>/ps`
- `POST /kill` or `POST /session/<session_id>/kill`
- `POST /session/close` or `POST /session/<session_id>/close`

No arbitrary command, `/run`, `/exec`, `/shell`, `/cmd`, or host administration endpoint is exposed.

The bridge defaults to `127.0.0.1` so it can be reached through an SSH tunnel. Binding to a non-local address requires `--public` and prints a warning. Even then, callers must use a random session id, an auth code, a short TTL, and a confined workspace.

## Server-console token flow

The runner does not let remote clients mint their own trust root. A session can be created only with a bootstrap code that was issued on the server console. Pressing Enter in the terminal running the server prints a one-use code:

```text
BOOTSTRAP_CODE=BQBOOT_... EXPIRES_AT=... REASON=console-enter
```

A client then calls:

```bash
curl -s -X POST http://127.0.0.1:8765/session/create \
  -H 'Content-Type: application/json' \
  -d '{"bootstrap_code":"BQBOOT_..."}'
```

That returns a `session_id` and `auth_code`. Subsequent requests may authenticate either with headers:

```text
X-Session-Id: BQSID_...
Authorization: Bearer BQAUTH_...
```

or, for JSON/form direct endpoints such as `/upload`, `/ps`, `/kill`, `/test`, `/dev-test`, `/patch-function`, `/splice`, and `/session/close`, with body fields:

```json
{"session_id":"BQSID_...","auth_code":"BQAUTH_..."}
```

Multipart uploads are the exception: because the runner must not consume the multipart stream before file parsing, multipart callers must authenticate with headers.

`GET /session/create` is intentionally unavailable.

## Security contract

The runner must preserve the following constraints:

1. No arbitrary command, shell, or generic exec endpoint.
2. One isolated workspace per session under the configured work root.
3. No path traversal, absolute target paths, NUL paths, or symlink escape.
4. Upload size, request size, runtime, and returned log limits.
5. Bounded log tails with obvious secret-bearing fields redacted.
6. No storage or echoing of auth tokens, SSH private keys, OCI config, API keys, PAR URLs, or uploaded secrets into scratchpad, normal logs, repository files, or package zips.
7. Session close or expiry removes the session workspace when cleanup is requested.
8. Queue-dev operations execute as a configured execution user, default `lockeduser`, rather than as the service/control-plane user.
9. API-submitted operations must be visible on screen for the token issuer on the server terminal. The runner logs session creation, uploads, approved operation start/end, process registration, process kill, and bounded stdout/stderr tails.
10. `ps` and `kill` are runner/session-scoped only. They may report or terminate only processes the runner registered for the current session.

## Locked execution user

Production use should create a locked, non-sudo execution account and run uploaded code, `queue dev patch`, `queue dev splice`, `queue dev test`, and focused tests as that account.

The package includes:

```bash
bin/queue-dev-runner-setup-locked-user lockeduser
```

The helper uses the fixed provisioning shape:

```bash
sudo useradd --create-home --shell /usr/sbin/nologin lockeduser
sudo passwd -l lockeduser
```

It then rejects users that are members of privileged groups such as `sudo`, `wheel`, or `admin`.

The runner defaults to:

```text
--execution-user lockeduser
```

Local smoke tests can avoid root-only provisioning by passing:

```bash
--execution-user "$(id -un)" --no-create-execution-user
```

When the execution user differs from the service user, the runner uses a fixed privilege-drop path such as `sudo -n -u lockeduser env -i ...` or root-only `runuser -u lockeduser -- env -i ...`. The environment is deliberately small: `PATH`, `HOME`, `QUEUEBASH_ALLOW_NONINTERACTIVE`, `QUEUEBASH_ROOT`, and `LC_ALL`.

## Session-scoped process controls

The `ps` operation returns only the process registry for the authenticated session. It is not host `ps`.

The `kill` operation accepts a `process_id` produced by the runner, or a raw `pid` only if that PID matches the authenticated session registry. PID 1, process names, host-global process selection, and cross-session kills are rejected.

A long approved test can be started asynchronously with:

```json
{"name":"sleepy","wait":false,"timeout":30}
```

The response includes `process_id`. The same session can then call `/ps` or `/kill` for that process.

## JSON response shape

Every operation returns JSON with this base shape:

```json
{
  "schema": "queuebash.dev_remote_runner.v1",
  "status": "ok",
  "operation": "test",
  "generated_at": "2026-05-29T00:00:00Z"
}
```

Error responses retain the same schema and include `error` plus `message`.

## Intended use

Prepare the locked user on the build VM:

```bash
bin/queue-dev-runner-setup-locked-user lockeduser
```

Start locally on the build VM:

```bash
python3 bin/queue-dev-runner.py \
  --host 127.0.0.1 \
  --port 8765 \
  --work-root /tmp/bashqueues-dev-runner \
  --execution-user lockeduser \
  --create-execution-user
```

Then connect through an SSH tunnel from the reviewing machine.

## Approved operation model

`test` accepts only an allow-listed test name. `patch-function` and `splice` construct fixed `queue dev ...` invocations. They do not accept free-form command strings.

Version 0.18.27 is dev infrastructure only. It must not change `queue dev test`, `queue dev scratchpad`, job-resolution behaviour, governance provider contracts, or OCI provider contracts except for documentation references.

## Python compatibility

The runner intentionally avoids Python 3.7-only APIs such as `from __future__ import annotations` and `http.server.ThreadingHTTPServer` so it can start on older Oracle Linux hosts that provide Python 3.6.
