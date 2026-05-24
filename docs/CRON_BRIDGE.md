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
queue cron tick --dryrun
queue cron edit hc3
queue cron remove hc3
```

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
