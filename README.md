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

Run four workers in the foreground:

```bash
queue run --workers 4
```

Detached workers:

```bash
queue start
queue start --workers 4
queue run --workers 4 --detach
queue workers
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


## Cancellation semantics

`queue cancel` and `queue kill` are operator actions. They move the job record into the `cancelled` state and append `CANCELLED_*` metadata, but they do **not** run `ON_FAILURE`.

The distinction is deliberate:

```text
command exits 0        -> done       -> ON_SUCCESS runs
command exits non-zero -> failed     -> ON_FAILURE runs
queue cancel           -> cancelled  -> ON_FAILURE does not run
queue kill             -> cancelled  -> ON_FAILURE does not run
```

This prevents dangerous surprises such as a killed job immediately resubmitting itself through an `ON_FAILURE` hook.

Cancellation is recorded in `events.jsonl` and in the job metadata:

```text
CANCELLED_AT=
CANCELLED_FROM=
CANCEL_SIGNAL=
```

If cancellation hooks are needed later, they should be added as a separate `ON_CANCEL` mechanism rather than overloading `ON_FAILURE`.


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


## Batch 2 / operational additions

### Version

```bash
queue version
```

### Automatic retries

```bash
queue submit fetch_payload --retries 3 --backoff 30 -- curl -O https://example.invalid/file.wav
```

Retries clone the failed attempt into a fresh pending job. The failed attempt remains in `failed` for audit.

### Resource limits with systemd-run

```bash
queue submit heavy --cpu 200 --mem 4G -- ./heavy_dsp_job.sh
```

When `systemd-run --user --pipe --wait --collect` is available, queuebash runs the payload inside a transient systemd scope with:

```text
CPUQuota=<cpu>%
MemoryMax=<mem>
```

If `systemd-run` is unavailable, the job runs normally and logs a warning.

### Queue manager completion

Inside `queuemgr`, press `TAB` to complete internal queue-manager commands and job IDs/names. This uses Bash readline and a temporary TAB binding while `queuemgr` is active.



## Detached workers

`queue run` is a foreground supervisor by default: it waits until its workers finish. For slow jobs, use detached mode:

```bash
queue start
queue start --workers 4
queue run --workers 4 --detach
```

Check recorded detached workers:

```bash
queue workers
```


## Final core conveniences

### Dynamic priority alias

`queue priority` remains the canonical command. `queue dynamic-prio` is provided as an operator-friendly alias:

```bash
queue dynamic-prio forensic_heavy 99
```

### Log safety cap

Submit with a maximum log size hint:

```bash
queue submit noisy --max-log-size 50M -- ./noisy-script.sh
```

The default is `QUEUEBASH_MAX_LOG_SIZE_BYTES` or 50MB.

### Execution summary

Completed job files append:

```text
EXEC_FINISHED_AT=
EXIT_CODE=
DURATION_SECONDS=
LOG_BYTES=
```

So `queue show <job>` gives a quick operational summary without parsing the text log.

### Watch mode

```bash
queue watch
queue watch --interval 2
```

Shows live stats, running jobs, and the top of the pending list.


## Resource limit verification

`--cpu` and `--mem` are enforced through `systemd-run --user --pipe --wait --collect` when available in the current login/session.

Check support:

```bash
queue limits
```

Example:

```bash
queue submit heavy --cpu 50 --mem 4G -- rexx waiter.rex
queue start
queue tail heavy
```

The job log should include:

```text
resource_limit_request: cpu=50 mem=4G status=systemd-run-user-service-pipe
limit_status: systemd-run-user-service-pipe
```

If the status is `requested-but-not-enforced-systemd-run-user-service-pipe-unavailable`, the limit was recorded but not enforced by the OS in that shell/session.


## Regression harness

Fast smoke test:

```bash
QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/selftest.sh
```

Full regression harness:

```bash
QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/regression.sh
```

The full regression checks stdout/stderr capture, zero and non-zero return paths, hooks, priority, dry-run, pause/unpause, delete/undelete, detached workers, cancel/kill, PID reporting, retry, resubmit, log capture, stats, events, tail, resource metadata, and watch mode.

Dedicated heavy log-volume stress test:

```bash
QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/stress_logstorm.sh 1000000
```

The ordinary regression uses a smaller logstorm by default. Override it with:

```bash
QB_REGRESSION_LINES=100000 QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/regression.sh
```


### Regression harness debugging

`tests/regression.sh` now prints diagnostics if a state transition stalls:

- full `queue list --state all`
- matching job files
- matching log tails

Hook tests use `tests/write_marker.sh` to avoid nested `bash -c` quoting ambiguity.


## Clearing cancelled jobs

At the command line:

```bash
queue --dryrun clear cancelled
queue clear cancelled
```

Inside `queuemgr`:

```text
cc    clear cancelled jobs
ccd   dryrun clear cancelled jobs
```


## Two-column queue manager help

`queuemgr` now renders its command summary in grouped two-column form to reduce screen space.

Inside `queuemgr`:

```text
help
?
```

prints the same compact summary.


## systemd-run wait/scope note

Resource-limited jobs use a transient user **service**:

```bash
systemd-run --user --pipe --wait --collect -p CPUQuota=50% -p MemoryMax=4G -- command ...
```

`--wait` is deliberately not combined with `--scope`, because systemd rejects that combination. Queue workers need `--wait` so they can collect the exit code and move the job to `done` or `failed` correctly.


## systemd resource-limit probe

Use this before trusting CPU/MEM enforcement on a machine:

```bash
queue limits --probe
queue limits --probe --cpu 50 --mem 4G
```

`queuebash` uses:

```bash
systemd-run --user --pipe --wait --collect -p CPUQuota=50% -p MemoryMax=4G -- command ...
```

`--pipe` is important: it returns the transient service stdout/stderr to the queue worker, so the normal job log still captures command output and systemd diagnostics.


## Health and interrupted recovery

`queue health` reports queue integrity and recovery issues:

```bash
queue health
queue health --fix
```

`queue health --fix` is intentionally non-interactive but loud. It prints everything it repairs, including stale `running` jobs whose recorded `RUN_PID` is no longer alive.

Safe repairs include:

- creating missing state directories
- removing dead detached worker PID files
- moving stale `running` jobs to `interrupted`
- appending `INTERRUPTED_*` metadata

`interrupted` means the worker/session died or disappeared while the job was marked running. It is distinct from `failed`, because no program exit code was observed.

Resubmission accepts both failed and interrupted jobs:

```bash
queue resubmit myjob
queue retry myjob
```

Inside `queuemgr`:

```text
h     health
hf    health --fix
```


## Three-column queue manager help

`queuemgr` now uses a compact three-column grouped command summary for standard full-screen terminals.

Additional clear shortcut:

```text
ci    clear interrupted
cid   dryrun clear interrupted
```

## Dynamic list column widths

`queue list` calculates column widths from the actual displayed rows, so long QIDs align under `JOB_ID` correctly.


## systemd working directory

Resource-limited jobs use the original submit directory when launching through `systemd-run`:

```bash
--working-directory="$PWD_AT_SUBMIT"
```

This preserves normal relative-command behaviour:

```bash
queue submit heavy --cpu 50 --mem 4G -- rexx waiter.rex
```

The transient service now resolves `waiter.rex` from the directory where the job was submitted.


## Runner policy

Queuebash now supports a runner policy:

```bash
export QUEUEBASH_RUNNER=auto
```

Allowed values:

```text
auto     prefer systemd-run when available, otherwise direct
systemd  require systemd-run support
direct   use the direct/setsid runner
```

Per job:

```bash
queue submit heavy --runner systemd --cpu 50 --mem 4G -- rexx waiter.rex
queue submit tiny --runner direct -- echo hello
```

When systemd is used, queuebash records:

```text
RUNNER=auto|systemd|direct
RUNNER_USED=systemd|direct
SYSTEMD_UNIT=<unit name when observed>
```

Inspect cgroup/unit information:

```bash
queue metrics <job>
queue unit <job>
```
