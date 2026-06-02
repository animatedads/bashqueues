# Queue command contract: human and JSON surfaces

Version: 0.18.87 first cleanup wave

## Purpose

Every non-interactive queue command must be usable by both humans and programs.
The default output remains human-centric. A `--json` or `-j` option must provide a
machine-centric response that callers can parse without scraping terminal text.

## Required behaviour

1. Human output is the default.
2. `--json` output is parseable JSON on stdout only.
3. Diagnostics, warnings, and progress messages go to stderr in JSON mode.
4. Errors in JSON mode use `queuebash.error.v1` or a command-specific structured error object with `ok:false`/`status:"error"` and an exit code.
5. Mutating commands return a structured result object in JSON mode.
6. Streaming commands either use JSONL or expose metadata-only JSON for non-follow mode; they must not pretend a live stream is a single JSON object.
7. `--help` remains human output. A future `--help --json` may expose command metadata, but a command must not emit half-human help in JSON mode.
8. Legacy command aliases remain supported while canonical domain/verb syntax is introduced gradually.

## Canonical syntax direction

The preferred command grammar is:

```text
queue <domain> <verb> [object] [options]
```

Legacy command forms remain compatibility aliases. Do not remove familiar forms such as `queue list`, `queue show`, `queue explain`, `queue pause`, or `queue resume` while the canonical domain/verb surface is being normalised.

## Baseline schemas

Successful list operations should include a schema string and array payload:

```json
{
  "schema": "queuebash.<domain>.list.v1",
  "items": []
}
```

Successful mutating operations should use a command-result style envelope:

```json
{
  "schema": "queuebash.command_result.v1",
  "ok": true,
  "command": "draft.state",
  "changed": true
}
```

JSON-mode failures should use:

```json
{
  "schema": "queuebash.error.v1",
  "ok": false,
  "command": "draft.show",
  "error": {
    "code": "not_found",
    "message": "draft not found",
    "rc": 1
  }
}
```

## Wave-1 schemas

```text
queuebash.env.list.v1
queuebash.version.v1
queuebash.selected_user.v1
queuebash.queue_users.v1
queuebash.draft.list.v1
queuebash.draft.show.v1
queuebash.draft.create.v1
queuebash.draft.state.v1
queuebash.acl.help.v1
queuebash.acl.operations.v1
```

## Wave-1 scope

This first cleanup wave fixes known defects and high-value JSON gaps:

- `queue env list --json` emits valid JSON.
- `queue draft list/show/create/create-from-job/state/ready/abandon` support `--json`.
- `queue acl help --json` and `queue acl operations --json` provide structured command metadata.
- `queue version --json`, `queue queue-user --json`, and `queue queue-users --json` provide stable informational JSON.

Future waves should extend the same rules to job inspection, history, workers, stats, events, limits, metrics, pids, hooks, and mutating command result envelopes.
