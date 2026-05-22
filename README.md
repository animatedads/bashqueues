# bashqueues

Queues for Bash, because good job management means everything should use Queues.

`queuebash` is a native Bash task queue with filesystem-backed state, job priorities, parallel workers, dry-run safety, resubmission, hooks, PID tracking, process cancellation, log tailing, and JSONL event audit logs.

It is designed to be inspectable and recoverable using normal shell tools. The queue lives in `~/.queuebash` by default.

## Features

- Pure Bash, no daemon, no database.
- Filesystem state machine:
  - `pending`
  - `running`
  - `paused`
  - `done`
  - `failed`
  - `cancelled`
  - `deleted`
- Priorities: higher number runs first.
- Multi-worker execution.
- `--dryrun` for destructive or mutating actions.
- Exact job-name group operations.
- Success/failure hooks.
- Failed-job resubmission.
- Runtime `RUN_PID`, `RUN_PGID`, and `RUN_STARTED_AT` tracking.
- `queue cancel` / `queue kill`.
- `queue tail`.
- `queue stats`.
- JSONL event audit log at `~/.queuebash/events.jsonl`.
- Helper loop functions:
  - `overfiles`
  - `overdir`

## Install

Clone the repository, then source `queuebash.sh` from your shell startup file:

```bash
git clone https://github.com/animatedads/bashqueues.git
cd bashqueues
./install.sh
source ~/.bashrc
```

Manual install:

```bash
mkdir -p ~/.local/share/bashqueues
cp queuebash.sh ~/.local/share/bashqueues/queuebash.sh
printf '\n# bashqueues\nsource "$HOME/.local/share/bashqueues/queuebash.sh"\n' >> ~/.bashrc
source ~/.bashrc
```

## Quick start

Submit a job:

```bash
queue submit hello -- echo "hello from queuebash"
```

List jobs:

```bash
queue list
queue ls
```

Run one worker:

```bash
queue run
```

Run four workers:

```bash
queue run --workers 4
```

Dry-run the next queue run:

```bash
queue --dryrun run --workers 4
```

## Priorities

```bash
queue submit urgent --priority 100 -- ./important_job.sh
queue submit normal --priority 10 -- ./ordinary_job.sh
queue priority urgent 50
```

Exact job names are treated as groups where appropriate:

```bash
queue priority ingest_tblisi 100
queue pause ingest_tblisi
queue delete ingest_tblisi
```

Job-name prefix matching is deliberately not used for mutating commands.

## Hooks

```bash
queue submit download \
  --on-success echo complete \
  --on-failure echo failed \
  -- curl -O https://example.invalid/file.wav
```

Add or amend hooks after submission:

```bash
queue onsuccess download -- echo complete
queue onfailure download -- echo failed
queue hooks download
```

For shell syntax, use `bash -c`:

```bash
queue onsuccess myjob -- bash -c 'echo complete && date'
```

## Pause, unpause, delete, undelete

```bash
queue pause myjob
queue unpause myjob

queue delete myjob
queue undelete myjob

queue clear deleted
```

Deleted jobs are moved to `deleted` and can be restored. `clear deleted` permanently removes deleted job records.

## Cancel and kill

For running jobs:

```bash
queue pids myjob
queue --dryrun cancel myjob
queue cancel myjob
queue kill myjob
```

`cancel` defaults to `TERM`. `kill` defaults to `KILL`. Both move the job record to the `cancelled` state.

```bash
queue cancel myjob --signal INT
queue kill myjob --signal KILL
```

## Logs and events

Tail a job log:

```bash
queue tail myjob
```

Show recent JSONL audit events:

```bash
queue events --tail 20
```

Stats:

```bash
queue stats
queue stats --today
queue stats --name ingest_tblisi
```

The master event log is:

```text
~/.queuebash/events.jsonl
```

Example with `jq`:

```bash
jq 'select(.event=="failed")' ~/.queuebash/events.jsonl
```

## Failed job resubmission

Resubmission clones failed jobs into new `pending` jobs while retaining the failed original and log.

```bash
queue resubmit failer
queue retry failer
queue --dryrun resubmit failer
```

The cloned job records:

```text
RESUBMITTED_FROM=<old job id>
RESUBMITTED_AT=<timestamp>
```

## Queue manager

Interactive queue manager:

```bash
queuemgr
```

Useful commands inside `queuemgr`:

```text
r             run one worker
rd            dryrun one worker
r4            run four workers
rd4           dryrun four workers
s <id|name>   show job/log
t <id|name>   tail job log
pid <id|name> show PID/process tree
p <id|name> <priority>
pause <id|name>
unpd <id|name>
d <id|name>
dd <id|name>
rs <id|name>
rsd <id|name>
stat
ev
q
```

## `overfiles` and `overdir`

Run a command over matching files:

```bash
overfiles "../*.zip" unzip "{1}"
overfiles --dryrun "../*.zip" unzip "{1}"
```

Unzip each ZIP into its own directory:

```bash
overfiles "../*.zip" \
  bash -c 'mkdir -p "${1%.zip}" && unzip -o "$1" -d "${1%.zip}"' _ "{1}"
```

Run a command over directories:

```bash
overdir "~/Downloads/import/*" \
  python forensic_helper.py --ingest "{1}" --raw-amp-db 12 --enhanced-amp-db 12 --yaml tblisi.yaml
```

## Queue storage

Default queue root:

```text
~/.queuebash/
```

Override it:

```bash
export QUEUEBASH_ROOT=/var/tmp/myqueue
```

## Safety notes

`queuebash` is intended for user-level job management. It is deliberately simple and inspectable. It does not replace systemd, Slurm, Kubernetes, or a distributed queue.

For dangerous actions, use dry run first:

```bash
queue --dryrun delete myjob
queue --dryrun cancel myjob
queue --dryrun clear deleted
```

## License

GPL-3.0.
