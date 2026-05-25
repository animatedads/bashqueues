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

## Runtime caps

Runtime caps are enforced after a payload starts.  They are different from
asset preflight checks: a preflight decides whether a pending job may start,
while a runtime cap watches a running job and can terminate it if it breaks the
policy.

The bundled runtime cap plugin is `caps.d/runtime.sh`.

Class defaults:

```bash
CLASS_DEFAULT_RUNTIME_CAPS="no-spawn-shell,no-network-tools,only-local-sockets,only-port"
CLASS_DEFAULT_RUNTIME_CAP_INTERVAL=1
CLASS_DEFAULT_RUNTIME_CAP_PORTS="5432,8000-8099"
```

Supported runtime cap names:

- `no-spawn-shell` — detects child shells such as `sh`, `bash`, `dash`, `zsh`,
  `ksh`, `mksh` and `busybox`. The initial payload process is ignored so a
  class may still run `bash script.sh`; the cap is aimed at spawned shells.
- `no-network-tools` — detects `curl`, `wget`, `nc`, `ncat`, `netcat`, `socat`,
  `telnet`, `ssh`, `scp`, `sftp`, and `rsync`.
- `no-network-sockets` — uses `lsof -p PID -i` when `lsof` is installed to
  detect live INET sockets.
- `only-local-sockets` — uses `lsof -p PID -i` to allow only localhost-bound
  or localhost-targeted INET sockets. A listener on `*:PORT` or `0.0.0.0:PORT`
  is blocked.
- `only-port` — uses `lsof -p PID -i` to allow only ports listed in
  `CLASS_DEFAULT_RUNTIME_CAP_PORTS`. Values may be comma-separated ports and
  ranges, for example `5432,8000-8099`. For client connections the remote port
  is checked; for listeners the bound local port is checked.

On violation the worker appends runtime-cap metadata to the job record, logs a
`runtime_cap_violation` event, terminates the job process group where possible,
and marks the job failed with exit code `96`.

Runtime caps are best-effort on direct runners and process-tree based. For hard
network isolation prefer `CLASS_DEFAULT_SANDBOX_LEVEL=network-none` or
`strict`, which uses systemd/unshare namespace controls where available.


### 0.17.12 runtime cap spelling and C2 audit notes

Runtime cap names may be written with hyphens or underscores. For example, `no_spawn_shell` is normalised to `no-spawn-shell`. Unknown runtime cap names are reported as warnings in job logs and `queue explain`, because a misspelled cap should not silently disable protection.

`secaudit:no_network_c2` now detects listener-style network payloads such as `nc -l -p PORT`, `ncat -l`, `socat TCP-LISTEN:PORT`, and Python `socket.bind(...)` patterns. This remains an early warning layer; runtime sandbox and caps remain the load-bearing enforcement.
