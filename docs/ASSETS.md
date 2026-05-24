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

