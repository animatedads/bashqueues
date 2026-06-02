# queuebash embedded API protocol contract

## Transport

The first transport is newline-delimited JSON over stdio.

Each request is one JSON object on one line. Each response is one JSON object on
one line. The broker must never print human progress text on stdout while in
protocol mode. Diagnostics go to stderr or audit logs.

## Request envelope

```json
{
  "schema": "queuebash.api.request.v1",
  "id": "1",
  "op": "session.list",
  "params": {},
  "scope": "qms"
}
```

Required fields:

```text
schema  queuebash.api.request.v1
id      caller supplied correlation id
op      operation name
```

Optional fields:

```text
params  operation-specific object
scope   requested application scope
```

## Response envelope

Successful response:

```json
{
  "schema": "queuebash.api.response.v1",
  "id": "1",
  "ok": true,
  "result": {
    "sessions": []
  }
}
```

Denied or failed response:

```json
{
  "schema": "queuebash.api.response.v1",
  "id": "1",
  "ok": false,
  "error": {
    "code": "operation_denied",
    "message": "operation outside application scope"
  }
}
```

The broker must preserve request ids on both success and failure.

## Error model

Standard error codes:

```text
invalid_json
invalid_request
unknown_operation
operation_denied
scope_not_found
scope_policy_invalid
not_implemented
internal_error
```

Errors must be bounded JSON responses. The broker must not hang on malformed
input, unknown operations, or denied operations.

## Initial operations

Contract-only first set:

```text
ping
version
capabilities
session.create
session.list
job.list
job.status
```

Future controlled write set:

```text
job.submit
job.hold
job.release
job.cancel
worker.once
```

Out-of-scope until separately approved:

```text
remote.admin
policy.edit
secret.read
key.management
acl.mutation
dev.patch
dev.splice
patchset.apply
```

## Example requests

Ping:

```json
{"schema":"queuebash.api.request.v1","id":"1","op":"ping","params":{}}
```

Version:

```json
{"schema":"queuebash.api.request.v1","id":"2","op":"version","params":{}}
```

Create session:

```json
{"schema":"queuebash.api.request.v1","id":"3","op":"session.create","params":{"name":"qms"}}
```

List sessions:

```json
{"schema":"queuebash.api.request.v1","id":"4","op":"session.list","params":{}}
```

Batch, later:

```json
{
  "schema": "queuebash.api.request.v1",
  "id": "5",
  "op": "batch",
  "params": {
    "requests": [
      {"op":"session.list","params":{}},
      {"op":"job.list","params":{"state":"running"}}
    ]
  }
}
```

## Session record schema

```json
{
  "name": "qms",
  "status": "active",
  "path": "/home/hc3/.queuebash/sessions/qms"
}
```

## Job summary record schema

```json
{
  "id": "20260602_...",
  "name": "render-001",
  "state": "pending",
  "class": "QMS_RENDER",
  "submitted_at": "2026-06-02T12:00:00Z"
}
```

## Security rules

The protocol is not a bypass around CLI governance. Every operation is subject
to the same policy, ACL, class, authorisation, trust-provider, remote-admin, and
dev-tool boundaries as normal queue commands.

The broker must:

```text
fail closed
redact secrets in errors and audits
bound request and response size
bound runtime per request
preserve request ids
avoid human stdout noise in protocol mode
audit writes and denials
```
