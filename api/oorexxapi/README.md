# BashQueues ooRexx API — Bob31 merged drop

This is the merged Bob31/Claude ooRexx API drop for bashqueues.

It keeps Claude's useful API structure, documentation, examples and tests, but applies the Bob31 fixes needed for the JSON-fronted command surface:

- exports `QUEUEBASH_ALLOW_NONINTERACTIVE=1` before sourcing `queuebash.sh`;
- quotes shell paths and command arguments instead of embedding unquoted values;
- parses JSON with an instantiated ooRexx `json.cls` object: `json = .json~new` then `json~fromJson(text)`;
- keeps `stats`, `list`, `health`, `explain`, `cancel`, `submit` and namespace calls JSON-facing;
- excludes the alchemy/banking learning scripts from the API package.

## Requirements

- Open Object Rexx 5.x
- bashqueues with `queuebash.sh`
- `json.cls`

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

The first test should show `stats` parsed as JSON, including `schema`, `total`, and state counters.

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
