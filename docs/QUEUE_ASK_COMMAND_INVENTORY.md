# queue ask command inventory

`queue ask` builds a bounded local context bundle before invoking a live provider. The `commands` context is generated from installed command help, not from the provider's memory.

## Remote command coverage

The command inventory now includes both the main `queue help` remote summary and the remote helper's own `--help` output. This ensures `queue ask --context commands` can see:

```text
queue remote add SERVICE --url URL (--secret SECRET|--secret-file FILE|--secret-env ENV) [--json]
queue remote list
queue remote show SERVICE
queue remote SERVICE health
queue remote SERVICE queue status
queue remote SERVICE job explain JOBID
```

The provider should prefer these installed idioms and should not report `queue remote add` as missing when the local helper advertises it.

## Validation example

```bash
QUEUEBASH_AI_LIVE_ENABLED=1 queue ask --provider gemini --live \
  "explain the queue remote add command"
```

Expected grounding: the answer should mention the installed syntax for `queue remote add` and should not claim that the command is absent from the installed inventory.
