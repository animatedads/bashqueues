# Time-limited exception overlays

Asset exception overlays can now carry an expiry time. Existing four-column exception records remain valid and are treated as `expires=never`.

```bash
queue exception add <QID> time:window --reason "approved daytime run" --expires +2h
queue exception add <QID> snmp:truth_ok --reason "NMS maintenance" --expires 2026-06-01
queue exception list <QID>
```

Supported expiry forms are:

- `never`
- relative durations such as `+30m`, `+2h`, `+7d`
- absolute values accepted by `date -d`

Expired exceptions are ignored during preflight. They remain visible for audit until cleared.
