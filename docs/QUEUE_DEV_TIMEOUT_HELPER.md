# queue-dev-timeout

`bin/queue-dev-timeout` is a tiny development/test helper for repeatable bounded
runs in review sandboxes and AI-worker sessions. It exists because many workers
otherwise rediscover the same pattern when a smoke test appears to hang:

```bash
queue-dev-timeout --timeout 20 --xtrace \
  --stdout /tmp/smoke.out \
  --stderr /tmp/smoke.err \
  -- bash tests/dev_qbtest_smoke.sh
```

The helper exports non-interactive defaults before running the child command:

```text
QUEUEBASH_ALLOW_NONINTERACTIVE=1
CI=1
TERM=dumb
GIT_TERMINAL_PROMPT=0
```

It then runs the command through GNU `timeout` using `TERM` first and a bounded
kill-after window. This standardizes diagnostics for Bash smoke tests and avoids
confusing interactive prompts with test failures.

This helper does not make acceptance decisions and does not mutate scratchpad
state. It is a local reviewer/worker convenience only.
