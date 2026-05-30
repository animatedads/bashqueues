# queue dev test qbtest add/extract

0.18.72 adds two developer helpers for embedded QBTEST function-test maintenance.

```bash
queue dev test qbtest extract --file queuebash.sh --function _queue_now --json
queue dev test qbtest add --file queuebash.sh --function _queue_now --name queue-now-format --b64 BASE64
```

`extract` returns the decoded QBTEST block for a function. `add` inserts a QBTEST block immediately after the named function and supports `--force` for replacement. These commands are developer tooling only and do not change runtime queue dispatch, provider behaviour, provisioning, or live API posture.
