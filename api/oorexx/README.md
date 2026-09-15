# BashQueues ooRexx API — Bob31 merged drop

This is the merged Bob31/Claude ooRexx API drop for bashqueues.

It keeps Claude's useful API structure, documentation, examples and tests, but applies the Bob31 fixes needed for the JSON-fronted command surface:

- exports `QUEUEBASH_ALLOW_NONINTERACTIVE=1` before sourcing `queuebash.sh`;
- quotes shell paths and command arguments instead of embedding unquoted values;
- parses JSON with an instantiated platform ooRexx JSON object: `json = .json~new` then `json~fromJson(text)`;
- keeps `stats`, `list`, `health`, `explain`, `cancel`, `submit` and namespace calls JSON-facing;
- makes full surface discovery lazy by default so normal client startup does not block on `queue dev functions --json`;
- excludes the alchemy/banking learning scripts from the API package.

## Requirements

- Open Object Rexx 5.x
- bashqueues with `queuebash.sh`
- platform ooRexx JSON support (`json.cls` on the ooRexx require path)

If bashqueues is not installed at a standard location, set:

```bash
export QUEUEBASH_SOURCE=/path/to/queuebash.sh
```

## Quick smoke test

Run from this directory so `::requires "BashQueues.cls"` resolves cleanly:

```bash
cd oorexxapi
rexx examples/bq_json_frontage_demo.rex
```

The first test should show `stats` parsed as JSON, including `schema`, `total`, and state counters. Discovery of the full command surface is lazy by default; set `BASHQUEUES_OOREXX_DEMO_SURFACE=1` to include the heavier `queue dev functions --json` demo.

## Common usage

```rexx
::requires "BashQueues.cls"

q = .BashQueues~user()
stats = q~stats
say stats~getTotal

jobs = q~list~json
do job over jobs
  say job~getQid job~getState job~getName
end

opts = .Directory~new
opts["priority"] = 10
job = q~submit("oorexx-api-demo", "/bin/echo hello", opts)
say job~getQid
```

## Files

| Path | Purpose |
|---|---|
| `BashQueues.cls` | ooRexx API wrapper |
| `examples/bq_json_frontage_demo.rex` | Bob31 smoke/demo script |
| `examples/list_by_state.rex` | List jobs filtered by state |
| `examples/submit_and_watch.rex` | Submit a job and poll explain JSON |
| `examples/cancel_blocked.rex` | Cancel pending/policy-blocked jobs by optional name filter |
| `tests/*.rex` | Connectivity, namespace, data and job smoke tests |
| `docs/OOREXX_API.md` | API notes |

## Diagnostics

Commands are logged to:

```text
$QUEUEBASH_ROOT/oorexx_bq.log
```

The most recent API error is available as:

```rexx
say q~lastError
```

## Bob31 third-drop examples

Additional ooRexx TUI and serialization examples were reviewed. The BashQueues API keeps the useful idioms — manager/wrapper objects, message-passing, `UNKNOWN`-based dynamic access, and snapshot/export thinking — but does not depend on the full TUI or custom serializer frameworks.

New examples:

```sh
rexx examples/bq_status_panel.rex
rexx examples/bq_snapshot_export.rex /tmp/queue_snapshot.json
```


See `BOB31_018135_CARRY_FORWARD.md` for the 0.18.135 carry-forward note.
