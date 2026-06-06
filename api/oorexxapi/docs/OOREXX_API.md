# BashQueues ooRexx API Reference

## Architecture

The API has six cooperating classes:

| Class | Role |
|---|---|
| `ScriptFronted` | Runs `bash -c`, exports environment, sources `queuebash.sh`, captures stdout/stderr, parses JSON. |
| `BQSurface` | Builds an introspected command map from `queue dev functions --json`. |
| `BQNamespace` | Chainable command path builder, for example `q~dev~scratchpad~list~json`. |
| `BQData` | Wraps a JSON Directory and exposes `getX`, `setX`, `hasX`, `fields`, `raw`. |
| `BQCollection` | Iterable collection of `BQData` objects with `count`, `filter`, and `makeArray`. |
| `BashQueues` | Main client and convenience methods. |

## Configuration

`BashQueues~user()` defaults to `$QUEUEBASH_ROOT` or `~/.queuebash`.

If `queuebash.sh` is not installed globally, set:

```bash
export QUEUEBASH_SOURCE=/path/to/queuebash.sh
```

You can also pass the source file explicitly:

```rexx
q = .BashQueues~user("/home/me/.queuebash", "queue", "/home/me/bashqueues/queuebash.sh")
```

## Named methods

```rexx
q = .BashQueues~user()

stats  = q~stats                 /* queue stats --json */
jobs   = q~list~json             /* queue list --json */
health = q~health                /* queue health --json */
job    = q~submit("name", "/bin/echo hi")
info   = q~explain(job~getQid)   /* queue explain QID --json */
res    = q~cancel(job~getQid)    /* queue cancel QID --json */
```

`q~version` returns text because version is a simple human-readable string.

## Namespace chains

Any queue command can be expressed as a method chain. Underscores become spaces.

```rexx
functions = q~dev~functions~json
lessons   = q~dev~ai~session~lessons~json
text      = q~dev~functions~text
```

Arguments passed to a namespace are shell-quoted and executed with `--json`:

```rexx
res = q~cancel("QID")
```

Use `~exec(extraArgs)` when you already have a complete argument string.

## BQData

`BQData` maps JSON fields to methods:

```rexx
say job~getQid
say job~getState
say job~hasExitCode
raw = job~raw
fields = job~fields
```

CamelCase is also converted to snake_case, so `getJobId` tries `jobid` and `job_id`.

## BQCollection

```rexx
jobs = q~list~json
say jobs~count

do job over jobs
  say job~getQid job~getState job~getName
end

pending = jobs~filter("state", "pending")
say pending~count
```

## Error handling

JSON and command failures return `.nil`; inspect the last error:

```rexx
stats = q~stats
if stats == .nil then say q~lastError
```

The command log is written to `$QUEUEBASH_ROOT/oorexx_bq.log` unless `q~_logFile = ""`.

## Notes on this drop

This package intentionally excludes the alchemy/banking learning examples. Those scripts informed ooRexx style, but they are not part of the BashQueues API.
