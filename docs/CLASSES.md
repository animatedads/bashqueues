# Queue classes and resource claims

Queue classes define cooperative scheduling constraints.

## Submit

```bash
queue submit ingest_day --class FORENSIC_DSP -- python ingest.py
```

## Class files

Class files live under:

```text
~/.queuebash/classes/<CLASS>.env
```

Example:

```bash
# Only one job of this class may run at once.
CLASS_ALLOW_PARALLEL=0

# Optional concurrency cap. 0 means unlimited.
CLASS_MAX_CONCURRENT=1

# Shared assets can run together unless an exclusive claim exists.
CLASS_SHARED_ASSETS="audio_disk"

# Exclusive assets block all other users of the same asset.
CLASS_EXCLUSIVE_ASSETS="camera_A"
```

Synonyms:

```bash
CLASS_EXCLUSIVE=1       # same effect as CLASS_ALLOW_PARALLEL=0
CLASS_ASSETS="name"     # alias for CLASS_SHARED_ASSETS
```

## Semantics

Class exclusivity controls jobs of the same class only.

Exclusive assets are stronger: an exclusive asset claim blocks all other jobs claiming that asset, whether shared or exclusive.

Commands:

```bash
queue class init FORENSIC_DSP
queue class list
queue class show FORENSIC_DSP
queue claims
```

Claims are inspectable directories:

```text
~/.queuebash/claims/classes/
~/.queuebash/claims/assets/
```


## Default class and dynamic preflight

Every job has a class. If a job is submitted without `--class`, it uses:

```bash
QUEUEBASH_DEFAULT_CLASS=DEFAULT
```

and the job file records:

```bash
JOB_CLASS=DEFAULT
```

The default class file is created automatically:

```text
~/.queuebash/classes/DEFAULT.env
```

### Plugin preflight

Class files can define machine-specific preflight checks without changing queuebash core code:

```bash
CLASS_PREFLIGHT_PLUGINS="vpn.sh"
CLASS_PREFLIGHT_FUNC="check_vpn_ready"

# Or external commands:
CLASS_PREFLIGHT_CMD="/usr/local/bin/check_vpn"
```

Plugins are loaded from either an explicit path or:

```text
~/.queuebash/class.d/<plugin>
```

Preflight function names are intentionally defined by the class file. The class file decides which checks to call.

### Pending, not failed

If class preflight fails, the job remains in `pending/`. This means the machine is not ready yet; it is not a program failure.


## Published asset facilities

Asset plugins publish the facilities they provide. This lets the queue manager show and validate asset capabilities instead of guessing from filenames.

Plugin file:

```text
~/.queuebash/assets.d/path.sh
```

Publisher function:

```bash
queue_asset_facilities() {
  cat <<'FACILITIES'
path:exists     Checks that a filesystem path exists
path:mount      Checks that a path is currently a mountpoint
path:freespace  Checks min_gb/min_mb/min_kb free space
FACILITIES
}
```

Nested asset token form:

```text
family:check:target:param=value:param=value
```

Example:

```bash
CLASS_EXCLUSIVE_ASSETS="path:freespace:/mnt/audio:min_gb=100"
```

This resolves to:

```text
helper:   ~/.queuebash/assets.d/path.sh
facility: path:freespace
function: queue_asset_check_path_freespace
```

List published facilities:

```bash
queue assets
queue assets show path
```

A helper must publish the facility before queuebash invokes it. A nested token with no helper remains a plain claim token; a helper with an unpublished facility is treated as blocked/misconfigured.

A `path:freespace` target must be a directory; non-directories block dispatch and leave the job pending.


## Asset helper contract validation

Asset helpers must meet a published-facility contract.

For every published facility:

```text
family:check
```

the helper must define:

```bash
queue_asset_check_<family>_<check>
```

Validate helpers:

```bash
queue assets validate
queue assets show path
```

If a helper exists but fails its contract, nested assets from that helper are treated as blocked/misconfigured and the job remains pending.


## Core does not contain asset plugin bodies

`queuebash.sh` only contains the plugin loader, contract validator, and dispatch logic.

Actual asset checks live as separate plugin files:

```text
assets.d/path.sh                 # bundled source plugin
~/.queuebash/assets.d/path.sh    # installed/site editable copy
```

Users should add or edit plugins under:

```text
~/.queuebash/assets.d/
```

not by editing `queuebash.sh`.

Bundled plugins are copied into the queue root only if the destination file does not already exist, so local machine-specific edits are preserved.
