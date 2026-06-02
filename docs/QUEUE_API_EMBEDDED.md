# queuebash embedded application session API

## Purpose

The embedded application session API formalises the "sandboxed within application"
usage model for bashqueues. It is intended for installers, GUI tools, render
managers, ooRexx/Python/Node bindings, and other applications that need queue
management capabilities without spawning a fresh `queue` process for every
operation.

This patch is contract-first. It defines the API shape, scope model, audit
requirements, and tests. It does not add a live broker implementation yet.

## Architectural rule

```text
The CLI is for humans.
The JSON API is for applications.
The embedded broker is for language bindings.
All three use the same governed queue core.
```

A language binding must not parse human terminal text. It should talk to a
stable line-oriented JSON protocol and receive structured records.

## Intended process model

```text
application / script
  -> queuebash language binding
      -> one queuebash session process
          -> many queue operations over a stable JSON protocol
```

For example, an ooRexx binding should start or attach to one broker process and
reuse it for all methods:

```rexx
qms = queuebash~new
rc = qms~session~create("qms")

do i over qms~session~list
  say i~name i~status i~path
end
```

The binding should not spawn `queuebash.sh` once for construction, again for
`session.create`, and again for `session.list`.

## Proposed command surface

The first runtime command should be:

```bash
queue api serve --stdio --scope SCOPE
```

Later additions may include:

```bash
queue api request --json REQUEST
queue api serve --socket PATH --scope SCOPE
queue api attach --session NAME
```

`--stdio` is the first implementation target because it is portable and easy for
ooRexx, Python, shell, Perl, PHP, and Node to drive.

## Broker modes

```text
direct embedded subprocess
  The language binding starts `queue api serve --stdio` once and communicates
  over stdin/stdout.

local socket/session
  The binding connects to an already-running per-user broker socket.

installer/internal mode
  Used by installers or maintenance scripts that need constrained privileged
  queue management.
```

The first implementation should support direct embedded subprocess only. The
protocol must leave room for socket/session attachment later.

## Scope categories

Application bindings should default to safe read and selected controlled write.
They must not automatically expose admin write or dev/internal operations.

```text
safe read
  ping
  version
  capabilities
  session.list
  job.list
  job.status
  job.explain
  worker.list
  class.list

controlled write
  session.create
  job.submit
  job.hold
  job.release
  job.cancel
  worker.once

admin write
  policy.edit
  remote.admin
  key.management
  acl.mutation
  secret.rotation

dev/internal
  dev.extract
  dev.patch
  dev.qbtest
  scratchpad.import
  patchset.apply
```

Admin and dev/internal operations require explicit future design and policy
approval. They are not part of the first embedded broker runtime.

## Relationship to installers

Installers already exercise a constrained internal queue model. The embedded API
makes that model explicit:

```text
queue app run installer
queue api serve --scope installer --stdio
QUEUEBASH_APP_SCOPE=installer
```

The installer gets a bounded capability bundle rather than unrestricted access.

## Audit requirements

Every embedded API request must produce audit evidence. Write operations and
denials are mandatory audit events.

Allowed request example:

```json
{
  "event": "queuebash.api.request.v1",
  "application": "qms",
  "session": "qms",
  "op": "job.submit",
  "allowed": true,
  "user": "hc3",
  "scope": "application",
  "request_id": "abc123"
}
```

Denied request example:

```json
{
  "event": "queuebash.api.denied.v1",
  "application": "qms",
  "op": "policy.edit",
  "allowed": false,
  "reason": "operation outside application scope"
}
```

Audit logs must avoid secrets and full command payloads by default. Sensitive
payloads require explicit policy gates.

## First runtime acceptance target

The first broker implementation should prove:

```text
queue api serve --stdio starts once
ping returns ok
version returns QUEUEBASH_VERSION
capabilities returns supported operations
session.create creates/attaches a named application session
session.list returns structured records
job.list and job.status are read-only
unknown operations fail closed
admin/dev operations fail closed by default
audit events are written
broker exits cleanly
```

Language bindings such as `bindings/oorexx/queuebash.cls` should be built after
this broker behaviour is stable.
