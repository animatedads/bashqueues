# bashqueues cron bridge

The cron bridge lets cron-shaped schedules submit jobs into bashqueues instead of
running commands directly. This prevents the usual cron stampede problem: each
unique cron command receives a generated `cron_<hash>` class with
`CLASS_MAX_CONCURRENT=1`, so a slow previous run causes the next firing to queue
rather than overlap.

## Design

The bridge is queue-first:

1. A systemd timer runs once per minute.
2. `bashqueues-cron-ticker.py` reads user crontabs from `/var/spool/bashqueues_cron`
   and system-style files from `/etc/bashqueues_cron.d`.
3. Matching entries are submitted as normal `queue submit` jobs under the target
   user's queue root.
4. The actual cron command runs inside a bashqueues worker, not inside the ticker.

The bridge does not replace `/usr/bin/crontab` by default. Use
`bashqueues-crontab` for bashqueues-managed crontabs.

## Files

```text
/var/spool/bashqueues_cron/<user>     user crontabs, six fields
/etc/bashqueues_cron.d/<file>         system crontabs, seven fields including user
/var/lib/bashqueues/cron/             per-minute de-duplication markers
```

## User crontab format

```text
# min hour dom month dow command
*/5 * * * * /home/hc3/bin/poll.sh
0 2 * * mon-fri /home/hc3/bin/nightly.sh
```

## System crontab format

```text
# min hour dom month dow user command
0 2 * * * hc3 /home/hc3/bin/nightly.sh
```

## Commands

```bash
bashqueues-crontab -e
bashqueues-crontab -l
bashqueues-crontab -r

queue cron root
queue cron list
queue cron explain [user|--all|system]
queue cron class [USER] ENTRY CLASS
queue cron class [USER] ENTRY --clear
queue cron show hc3
queue cron preview --now 2026-05-24T20:00:00
queue cron tick --dryrun
queue cron edit hc3
queue cron remove hc3
```


## Per-entry class routing

Cron entries can be routed to a named bashqueues class with a local comment directive
immediately above the entry:

```cron
#class GITHUB_PUBLISH
15 14 * * * /home/hc3/bashqueues/publish_to_github.sh
```

This is easier for operators to read than generated `cron_<hash>` class names.  The
ticker submits the entry with `--class GITHUB_PUBLISH` and does not overwrite that
class.

Use the helper command to add, replace, or clear the directive without hand-editing:

```bash
queue cron class 1 GITHUB_PUBLISH
queue cron class 1 --clear
sudo queue user testu cron class 1 TESTU_BATCH
```

`queue cron explain` shows both the explicit class and the generated fallback class.
The older assignment form remains supported for compatibility:

```cron
BASHQUEUES_CLASS=GITHUB_PUBLISH
15 14 * * * /home/hc3/bashqueues/publish_to_github.sh
```

A local command-bound authorisation can similarly be declared with `#authorisation CODE`
when a cron entry must use a class below the active crontab minimum.

## Installation

```bash
sudo ./install-cron-bridge.sh
```

The installer copies:

```text
/usr/local/libexec/bashqueues/bashqueues-cron-ticker.py
/usr/local/bin/bashqueues-crontab
/usr/local/share/bashqueues/queuebash.sh
/etc/systemd/system/bashqueues-cron.service
/etc/systemd/system/bashqueues-cron.timer
```

Then it enables `bashqueues-cron.timer`.

## Safety notes

The ticker is not a worker. It only creates queue jobs.

Every generated cron class contains:

```bash
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=1
CLASS_DEFAULT_RUNNER=auto
```

The state directory prevents duplicate submissions if the timer fires more than
once in the same minute.

## Why not override crontab?

Replacing `/usr/bin/crontab` or shadowing it globally is surprising and unsafe.
This bridge ships `bashqueues-crontab` as an explicit command. Operators can add
aliases or PATH policy later if they want compatibility shims.


## Cron compatibility notes

Generated cron classes are scoped by both Unix user and command so separate users do not share the same `cron_<hash>` class file. The ticker only rewrites generated class files when the content is absent or changed.

Supported macro forms are `@hourly`, `@daily`, `@midnight`, `@weekly`, `@monthly`, `@yearly`, and `@annually`. `@reboot` is intentionally not supported by the minute ticker and is reported as a warning.

The state directory stores per-minute de-duplication markers. Markers older than `${QUEUEBASH_CRON_STATE_MAX_AGE_DAYS:-7}` days are removed after each non-dry-run tick.

Cron jobs are submitted as `bash -lc COMMAND` queue jobs. The login-shell behaviour is deliberate for compatibility with traditional cron environments, but it can add startup overhead compared with direct execution.

## Cron class routing with BASHQUEUES_CLASS

The cron bridge understands a bashqueues-specific crontab variable:

```cron
BASHQUEUES_CLASS=cron_standard
*/5 * * * * /opt/jobs/poll-local-service.sh

BASHQUEUES_CLASS=cron_permissive
0 2 * * * /opt/jobs/trusted-external-sync.sh

BASHQUEUES_CLASS=
0 * * * * /opt/jobs/local-cache-clear.sh
```

`BASHQUEUES_CLASS` behaves like normal cron environment state: it applies to
subsequent entries until changed or cleared. When it is set, the ticker submits
using the named class and does not create or overwrite that class. When it is
unset, the ticker creates a generated `cron_<hash>` class scoped to the user and
command.

Generated cron classes are deliberately conservative:

```bash
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=1
CLASS_DEFAULT_RUNNER=auto
CLASS_DEFAULT_SANDBOX_LEVEL=strict
CLASS_DEFAULT_RUNTIME_CAPS=no-spawn-shell,no-network-tools,only-local-sockets
CLASS_DEFAULT_RUNTIME_CAP_INTERVAL=1
```

This keeps ordinary scheduled tasks from stampeding or unexpectedly using broad
network/process behaviour. Operators can pre-create named classes for workflows
that intentionally require broader access.
