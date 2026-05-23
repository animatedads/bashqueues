# Log drain synchronization

Queuebash uses a drain-first logging model for capped logs.

## Problem fixed

Earlier FIFO/pipe handling could allow payload output to appear after the queue footer:

```text
finished: ...
exit_code: ...
payload output still arriving here
```

It could also trigger `SIGPIPE` in short jobs using `systemd-run --pipe`.

`exit_code=141` is a typical symptom:

```text
141 = 128 + 13 = SIGPIPE
```

## Correct ordering

The worker now enforces this order:

```text
1. start stdout/stderr drainers
2. start payload
3. wait for payload
4. wait for stdout/stderr drainers to reach EOF
5. remove stream FIFOs
6. append queue footer:
   finished:
   exit_code:
```

The footer is written with an explicit append after the drainers are finished, rather than through the long-lived worker stdout file descriptor. This prevents stale-offset writes and keeps the footer last.
