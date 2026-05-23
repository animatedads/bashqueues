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


## Standard network and system plugins

The bundled plugin directory now includes family-aligned helper files:

```text
assets.d/net.sh
assets.d/sys.sh
```

They install to:

```text
~/.queuebash/assets.d/net.sh
~/.queuebash/assets.d/sys.sh
```

The filename must match the facility family:

```text
net:http_status -> assets.d/net.sh
sys:cpu_load    -> assets.d/sys.sh
```

### Network facilities

Published by `net.sh`:

```text
net:http_status
net:tcp_endpoint
net:interface_state
net:interface_bandwidth
```

### System facilities

Published by `sys.sh`:

```text
sys:memory_available
sys:cpu_load
sys:cpu_cores
sys:iowait
sys:process_count
```

Examples:

```bash
CLASS_SHARED_ASSETS="net:tcp_endpoint:db.internal:5432:timeout=3"
CLASS_EXCLUSIVE_ASSETS="net:interface_state:tun0"
CLASS_SHARED_ASSETS="sys:memory_available:0:min_gb=8"
CLASS_SHARED_ASSETS="sys:cpu_load:0:max_load_1m=4.0"
```


## Duplicate asset publishers

`queue assets` de-duplicates by facility name, so legacy/helper duplicates do not clutter the normal list.

To find duplicates:

```bash
queue assets duplicates
```

After the family-aligned rename, old files such as these can be removed if they only duplicate the bundled helpers:

```bash
rm ~/.queuebash/assets.d/network.sh ~/.queuebash/assets.d/system.sh
```

The active family-aligned helpers are:

```text
~/.queuebash/assets.d/net.sh
~/.queuebash/assets.d/sys.sh
```


## Replacing and rolling back asset plugins

Asset plugins can be replaced transactionally.

```bash
queue assets replace net ./net.sh
```

Replacement process:

```text
1. validate shell syntax with bash -n
2. validate published-facility contract
3. verify the plugin publishes at least one facility for the requested family
4. back up the existing ~/.queuebash/assets.d/<family>.sh
5. atomically move the replacement into place
```

Backups are stored under:

```text
~/.queuebash/assets.d/.backup/
```

Rollback:

```bash
queue assets rollback net
```

or restore a specific backup:

```bash
queue assets rollback net ~/.queuebash/assets.d/.backup/net.20260523_120000_000000000.sh
```

List backups:

```bash
queue assets backups
queue assets backups net
```

Force mode exists for emergency use, but should be avoided:

```bash
queue assets replace net ./net.sh --force
```

Force still checks shell syntax, but skips contract validation.


## Refreshing, deleting, and explaining asset plugins

Use `queue assets refresh <dir>`, `delete <family>`, `undelete <family>`, `archives [family]`, and `explain <family|family:check>` for managed plugin lifecycle.


## Git and database asset plugins

Bundled external plugins now include:

```text
assets.d/git.sh
assets.d/db.sh
```

Git facilities:

```text
git:repo_exists
git:clean_tree
git:branch
```

Database facilities:

```text
db:postgres_connect
db:mysql_connect
db:sqlite_accessible
db:redis_connect
db:mongodb_connect
```

Examples:

```bash
CLASS_SHARED_ASSETS="git:clean_tree:/home/hc3/bashqueues"
CLASS_SHARED_ASSETS="git:branch:/home/hc3/bashqueues:require_branch=main"
CLASS_SHARED_ASSETS="db:sqlite_accessible:/tmp/test.db:query=SELECT 1"
```

Database helpers depend on the relevant command-line clients being installed.


## GitHub publishing class

Bundled class:

```text
classes/GITHUB_PUBLISH.env
```

Submit publishing jobs with:

```bash
queue submit publish_to_git --class GITHUB_PUBLISH -- bash publish_to_github.sh
```

It gates dispatch using `net:http_status:https://github.com`, `git:repo_exists`, and `git:branch`, and serialises publishing jobs with `CLASS_ALLOW_PARALLEL=0`.

Class manager commands:

```bash
queue classes list
queue classes show GITHUB_PUBLISH
queue classes edit GITHUB_PUBLISH
queue classes validate
queue classes replace GITHUB_PUBLISH ./GITHUB_PUBLISH.env
queue classes refresh ./classes
queue classes rollback GITHUB_PUBLISH
queue classes delete OLD_CLASS
queue classes undelete OLD_CLASS
queue classes explain GITHUB_PUBLISH
queue classes expand
```


## Asset token parser and format plugin

Nested asset tokens now support colon-bearing targets. Parameters start at the first `key=value` segment, and parameter values may also contain colons.

```bash
CLASS_SHARED_ASSETS="net:http_status:https://github.com:timeout=5"
CLASS_SHARED_ASSETS="net:tcp_endpoint:db.internal:5432:timeout=3"
CLASS_SHARED_ASSETS="git:branch:/home/hc3/bashqueues:require_branch=main"
```

The bundled `format.sh` plugin publishes `format:json`, `format:xml`, `format:yaml`, `format:csv`, `format:archive`, and `format:sqlite`.


## Delimiter-safe class asset records

Classes can now define assets using function calls rather than delimiter-packed strings.
This is the preferred format for plugin-backed assets because each field is a Bash
argument, so targets and parameters may contain any number of `:`, `,`, `/`, `=`, or spaces.

```bash
queue_class_exclusive_asset "github_publish:slot"

queue_class_shared_asset net http_status "https://github.com" \
  timeout=5 \
  accept_status="200,201,204,301,302,304,307,308,403"

queue_class_shared_asset net tcp_endpoint "db.internal:5432" timeout=3

queue_class_shared_asset git branch "/home/hc3/bashqueues" require_branch=main
```

Legacy `CLASS_SHARED_ASSETS` and `CLASS_EXCLUSIVE_ASSETS` strings remain supported, but
new classes should use `queue_class_shared_asset` and `queue_class_exclusive_asset`.


## Record-only class assets

As of 0.10.1, legacy string asset fields are removed:

```bash
CLASS_SHARED_ASSETS="..."
CLASS_EXCLUSIVE_ASSETS="..."
CLASS_ASSETS="..."
```

Classes must use record calls:

```bash
queue_class_shared_asset net http_status "https://github.com" \
  timeout=5 \
  accept_status="200,201,204,301,302,304,307,308,403"

queue_class_shared_asset git branch "/home/hc3/bashqueues" \
  require_branch=main

queue_class_exclusive_asset net tcp_endpoint "db.internal:5432" \
  timeout=3

queue_class_exclusive_claim "github_publish:slot"
```

This removes delimiter parsing from class definitions. Targets and parameter values may contain `:`, `,`, `=`, `/`, spaces, and other shell-safe quoted content.
