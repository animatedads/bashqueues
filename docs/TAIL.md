# queue tail

`queue tail` is designed for live noisy jobs.

## Defaults

```bash
queue tail <job>
```

For running jobs:

```text
show last 40 physical log lines, then follow
```

For completed or compressed logs:

```text
show last 40 physical log lines and return
```

Set a different default with:

```bash
export QUEUEBASH_TAIL_LINES=80
```

## Options

```bash
queue tail <job> --tail 10
queue tail <job> -n 10
queue tail <job> --no-follow
queue tail <job> --from-start
```

## Examples

Show a small live view:

```bash
queue tail longrexx --tail 10
```

Show current tail and return:

```bash
queue tail longrexx --tail 20 --no-follow
```

Show from the start:

```bash
queue tail longrexx --from-start
```
