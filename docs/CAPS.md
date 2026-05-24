# Execution cap modules

Execution cap modules live in `caps.d/`. Bundled modules include `billing.sh` and `net_usage.sh`.

Management commands:

```bash
queue caps list
queue caps explain billing
queue caps disable billing
queue caps enable billing
queue caps refresh caps.d
```

Cross-module commands:

```bash
queue modules list
queue modules explain cap:billing
queue modules disable cap billing
queue modules enable cap billing
```

Disabled cap modules are moved to `caps.d/.disabled/` and are not sourced by the cap loader.
