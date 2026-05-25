# Asset plugins

Asset plugins publish preflight facilities used by queue classes. They live outside `queuebash.sh` so machine-specific checks can be maintained independently.

Installed helper directory:

```text
~/.queuebash/assets.d/
```

Bundled helper source directory:

```text
assets.d/
```

## Published facility contract

Each helper publishes facilities with:

```bash
queue_asset_facilities
```

Each published `family:check` must have a matching check function:

```text
family:check -> queue_asset_check_family_check
```

Example:

```text
net:allowance -> queue_asset_check_net_allowance
```

Validate helpers with:

```bash
queue assets validate
queue assets show net
queue assets explain net:allowance
```

## Canonical network allowance facility

The canonical charged network allowance facility is:

```text
net:allowance
```

Use it in classes like this:

```bash
queue_class_shared_asset net allowance "wwan0" allowance_bytes=10G direction=rx_tx
```

A testable counter-file form is available for regression tests or synthetic counters:

```bash
queue_class_shared_asset net allowance "charged" counter_file=/tmp/charged.bytes allowance_bytes=10G
```

Parameters:

```text
allowance_bytes=10G       required, supports B/K/M/G/T suffixes
direction=rx_tx           optional; rx, tx, rx_tx, or total
counter_file=/path/file   optional; read usage from this file instead of /sys/class/net
```


## Standard bundled families

```text
net     network reachability, interface, bandwidth, and allowance checks
sys     system memory, CPU, iowait, and process checks
path    filesystem/path checks
git     git working tree/repository checks
db      database checks
format  file/format checks
runnable executable/script checks
time    time-window checks
queue   bashqueues job-history checks
```

## QueueManager hints

Helpers may publish tab-separated hints with:

```bash
queue_asset_hints
```

Supported metadata keys are:

```text
target
params
example
notes
```

QueueManager uses hints to guide class creation, but helper validation and the check functions remain the source of truth.

## Enabling and disabling asset helpers

Asset helper modules under `assets.d/` can be disabled and enabled:

```bash
queue assets disable net --force
queue assets enable net
```

By default, disabling an asset helper is refused when enabled classes still reference that asset family. Use `--force` only when deliberately taking the facility out of service.



## proc asset family

`assets.d/proc.sh` publishes process-related preflight checks.

Facilities:

- `proc:running` — require at least one matching process.
- `proc:not_running` — pass only when no matching process exists; useful for duplicate-launch prevention.
- `proc:user_running` — require a matching process owned by a given Unix user.
- `proc:pid_file` — require a PID file whose PID is alive.
- `proc:max_instances` — cap matching process count.
- `proc:cpu_user` — block when matching processes exceed a CPU percentage threshold.
- `proc:mem_user` — block when matching processes exceed an RSS threshold.

Examples:

```bash
queue_class_shared_asset proc not_running "enhance" match=exact
queue_class_shared_asset proc max_instances "ffmpeg" max=2 match=substr
queue_class_shared_asset proc pid_file "/run/mydaemon.pid" stale_ok=0
```

## queue asset family

`assets.d/queue.sh` publishes queue-history checks. These are different from `proc:*`: `proc` checks the current operating-system process table, while `queue` checks bashqueues job records.

Facilities:

- `queue:command_has_run` — require a matching job command/name to have run within a time window.
- `queue:command_has_not_run` — require no matching job command/name to have run within a time window.
- `queue:job_has_run` — alias wording for job-name checks.
- `queue:job_has_not_run` — alias wording for job-name checks.

Useful parameters:

```text
match=exact|substr|regex     default substr
field=command|name|both      default both
time=24h                     supports s/m/h/d/w suffixes
states=done,failed,running   optional state filter; default checks common active/terminal states
```

Examples:

```bash
# Allow only if a matching command ran in the last 24 hours.
queue_class_shared_asset queue command_has_run "nightly_export.sh" match=substr time=24h

# Allow only if the command has not run in the last 24 hours.
queue_class_shared_asset queue command_has_not_run "nightly_export.sh" match=substr time=24h

# Job-name form.
queue_class_shared_asset queue job_has_not_run "nightly_export" field=name match=exact time=24h
```

## secaudit asset family

`assets.d/secaudit.sh` provides static security-audit gates for scripts and generated command strings. It is intended as a preflight safety net, not as a complete security boundary. Combine it with runtime sandboxing for defense in depth.

Facilities:

- `secaudit:script_safe` — scan a shell script for destructive, C2, privilege escalation, and obfuscation patterns.
- `secaudit:string_safe` — scan a literal command string.
- `secaudit:no_destructive` — block obvious `rm -rf`, `mkfs`, disk wipe, fork bomb, or critical overwrite patterns.
- `secaudit:no_network_c2` — block reverse-shell and curl-pipe-shell patterns.
- `secaudit:no_privesc` — block sudo/su/SUID/777/root-ownership patterns unless explicitly allowed.
- `secaudit:no_obfuscation` — block common eval/base64 pipe-to-shell obfuscation.

Examples:

```bash
queue_class_shared_asset secaudit script_safe "/opt/scripts/import.sh" strict=0
queue_class_shared_asset secaudit no_network_c2 "/opt/ingest/parse_payload.sh"
queue_class_shared_asset secaudit string_safe "bash publish_to_github.sh" strict=0
```

On failure the check reports the detected threat and, for files, the line number where possible.


### 0.17.12 runtime cap spelling and C2 audit notes

Runtime cap names may be written with hyphens or underscores. For example, `no_spawn_shell` is normalised to `no-spawn-shell`. Unknown runtime cap names are reported as warnings in job logs and `queue explain`, because a misspelled cap should not silently disable protection.

`secaudit:no_network_c2` now detects listener-style network payloads such as `nc -l -p PORT`, `ncat -l`, `socat TCP-LISTEN:PORT`, and Python `socket.bind(...)` patterns. This remains an early warning layer; runtime sandbox and caps remain the load-bearing enforcement.
