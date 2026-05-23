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


## Automatic gzip log compression

Completed job logs are compressed by default:

```bash
export QUEUEBASH_GZIP_LOGS=1
```

Disable compression:

```bash
export QUEUEBASH_GZIP_LOGS=0
```

While a job is running, the log remains plain:

```text
~/.queuebash/logs/<QID>.log
```

After completion, it becomes:

```text
~/.queuebash/logs/<QID>.log.gz
```

`queue show` and `queue tail` read both `.log` and `.log.gz` automatically.

`queue show` now tails logs by default:

```bash
queue show myjob
queue show myjob --tail 500
queue show myjob --full
```


## Compress existing completed logs

Automatic gzip runs after completed job logs are closed. To compress existing completed logs manually:

```bash
queue compress-logs
```

Alias:

```bash
queue gzip-logs
```


## Completion for log compression

The shell completion includes:

```bash
queue compress-logs
queue gzip-logs
```

Inside `queuemgr`:

```text
gz    compress completed logs
```


## Live log watchdog

Queuebash protects ordinary jobs from runaway stdout/stderr.

Default cap:

```bash
QUEUEBASH_MAX_LOG_SIZE_BYTES=52428800
```

Override per job:

```bash
queue submit noisy --max-log-size 2G -- ./thing
```

Explicitly allow huge logs:

```bash
queue submit noisy --allow-large-log -- ./thing
```

If a running job exceeds the cap, queuebash records:

```text
LOG_OVERFLOW=1
LOG_OVERFLOW_AT=
LOG_OVERFLOW_BYTES=
LOG_OVERFLOW_CAP=
```

and terminates the process or transient systemd unit.


## Runner/operator documentation

See:

```text
docs/RUNNERS.md
```

for the current execution model:

```text
direct runner  -> setsid + RUN_PGID
systemd runner -> transient service + SYSTEMD_UNIT + cgroup
```

Operator summary command:

```bash
queue explain <job>
```


## Systemd MainPID handling

For systemd-run jobs, `RUN_PID` may be the `systemd-run` launcher process rather than the long-running payload.

For active systemd jobs, queuebash now treats the transient unit as authoritative:

```text
SYSTEMD_UNIT
systemctl --user show <unit> -p MainPID
```

`queue pids`, `queue health`, `queue cancel`, `queue kill`, and the log watchdog prefer the active systemd unit/MainPID where available, then fall back to `RUN_PGID` / `RUN_PID`.


## Explain exact-name batches

`queue explain <name>` explains every job with that exact name, matching `queue show` behaviour. Use a QID when you want one specific record.

For pending jobs, `queue explain` reports:

```text
planned: <runner>
used: not-started
```

and explains that cancellation only moves the job record because no process exists yet.


## Dependencies

Queuebash supports simple success dependencies:

```bash
queue submit next_step --after-success previous_step -- ./next.sh
```

Aliases:

```bash
--after
--depends-on
```

Inspect:

```bash
queue deps <job>
queue waiting
```

See:

```text
docs/DEPENDENCIES.md
```


## After-success test script

Dedicated dependency test:

```bash
QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/after_success.sh
```

The test forces:

```bash
QUEUEBASH_RUNNER=direct
```

because it validates dependency scheduling, not user-systemd execution.


## Self-dependency validation

Dependency jobs cannot depend on themselves by exact job name:

```bash
queue submit self_dep --after-success self_dep -- echo loop
```

returns:

```text
queue submit: job cannot depend on itself: self_dep
```


## Retry dependency touch test

Dedicated integration test for retry + on-retry-failure + dependency release:

```bash
QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/retry_dependency_touch.sh
```

`--on-failure` remains the final-failure hook. Use `--on-retry-failure` when a hook should repair the environment before the retry attempt.


Note: the retry-remediation hook is recorded in the failed first attempt log, while the final producer success is recorded in the retry job log. `tests/retry_dependency_touch.sh` checks the whole producer attempt chain.


## One-shot scheduling

Submit a job to become eligible after a delay:

```bash
queue submit-in 10m publish_later -- bash publish_to_github.sh
```

Submit a job to become eligible at a specific time:

```bash
queue submit-at 23:30 night_job -- ./nightly.sh
```

Inspect scheduled pending jobs:

```bash
queue scheduled
queue explain <job>
```

See:

```text
docs/SCHEDULING.md
```


## Scheduling completion

Shell completion includes:

```bash
queue submit-in
queue submit-at
queue in
queue at
queue scheduled
queue schedule
```


## Clean log files

Preview removable completed/orphan logs:

```bash
queue clean-logs --dryrun
```

Delete matching logs:

```bash
queue clean-logs --older-than 30d --force
```

Examples:

```bash
queue clean-logs --state done --older-than 7d --force
queue clean-logs --state failed --older-than 14d --force
queue clean-logs --orphan --force
queue clean-logs --all --older-than 90d --force
```

Safe defaults:

```text
without --force, clean-logs previews only
running logs are never deleted unless --include-running is used
without --all/--state, only completed/dead/orphan states are eligible
```


## Log cleanup audit fields

When `queue clean-logs --force` removes a log belonging to a known job, the job record is appended with:

```bash
LOG_CLEANED=1
LOG_CLEANED_AT=...
LOG_CLEANED_PATH=...
LOG_CLEANED_BYTES=...
```

A `log_cleaned` event is also appended to `events.jsonl`.


## Dependency edge-case tests

Run:

```bash
QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/dependency_edge_cases.sh
```

This covers:

```text
retroactive satisfaction
failed parent blocking
duplicate-name dependency semantics
strict QID dependency semantics
circular safe-pending behaviour
fan-in dependencies
```

This is a diagnostic edge-case test, not part of the fast regression suite, because it deliberately creates blocked/cyclic pending jobs.

See:

```text
docs/DEPENDENCY_EDGE_CASES.md
```


## Health and integrity

Run:

```bash
queue health
queue health --fix
queue health --deep
```

`queue health` checks queue directories, writability, events logging, free disk/inodes, helper commands, malformed job files, stale running jobs, and dependency status.

`queue health --fix` only performs safe repairs:

```text
create missing directories
remove dead worker pid files
move definitely stale running jobs to interrupted/
```

See:

```text
docs/HEALTH.md
```


## Restore diagnostics

`queue restore` / `queue undelete` only restores jobs from `deleted/`.

If no deleted job matches, queuebash now searches the other state directories and reports where matching jobs actually are:

```text
queue undelete: no matching deleted job: publish_to_git
but matching job(s) exist outside deleted/:
  2026... done publish_to_git
```

Use:

```bash
queue list --state deleted --name publish_to_git
```

to confirm whether a job is currently restorable.


## stderr-only overflow policy

The default log overflow policy protects noisy jobs without breaking their stdout pipe:

```text
before first cap: log stdout + stderr
after first cap:  suppress stdout, continue stderr
after second cap: suppress stderr too
always:           drain streams so the child keeps running
```

Per job:

```bash
queue submit noisy --max-log-size 50M --log-overflow stderr-only -- ./noisy.sh
queue submit strict --max-log-size 50M --log-overflow kill -- ./noisy.sh
```


## systemd runner process model

For `RUNNER_USED=systemd`, `RUN_PID` is the `systemd-run` client process, not necessarily the payload PID.

`queue cancel`, `queue kill`, `queue health`, and `queue explain` now prefer `SYSTEMD_UNIT` for process accounting and termination.

See:

```text
docs/SYSTEMD_PROCESS_MODEL.md
```


## Systemd cancellation no longer falls back to PGID

For `RUNNER_USED=systemd`, `queue cancel` and `queue kill` now target the transient unit with:

```bash
systemctl --user kill --kill-whom=all --signal=<SIG> <SYSTEMD_UNIT>
```

They do not fallback to `RUN_PGID` when the unit was targeted, because `RUN_PGID` may be the queue worker process group.

Stream temp files/FIFOs are cleaned up on completion, cancellation, and health repair.


## Cancellation race handling

If an operator cancels/kills a running job while a worker is still waiting for the payload runner to return, the worker now reports:

```text
[worker N] cancelled <QID> (operator cancellation observed; payload rc=...)
```

rather than reporting the job as failed. This keeps `cancelled` and `failed` audit meanings separate.


## Log drain synchronization

Queuebash waits for stdout/stderr drainers to finish before appending the queue footer. This prevents payload output appearing after:

```text
finished:
exit_code:
```

and prevents logger-side pipe closure from causing SIGPIPE failures in short jobs.


## Tail defaults

`queue tail <job>` now shows the last 40 lines before following a running log.

```bash
queue tail longrexx --tail 10
queue tail longrexx --no-follow
queue tail longrexx --from-start
```

Set the default with:

```bash
export QUEUEBASH_TAIL_LINES=80
```

See `docs/TAIL.md`.


## Targeted log compression

Workers now compress only the log for the job they just completed. They no longer scan all completed jobs after every job.

Manual bulk compression remains available:

```bash
queue compress-logs
```

See `docs/TARGETED_COMPRESSION.md`.


## Filesystem-native IPC

`bashqueues` supports lightweight IPC:

```bash
queue_output KEY VALUE
queue submit consumer --inherit-env-from <producer-qid> -- ./consumer.sh
queue stream <running-job>
```

IPC files live under `outputs/` and `streams/`. See `docs/IPC.md`.


## Name-based IPC inheritance

`--inherit-env-from` now accepts a job name and automatically creates the after-success dependency:

```bash
queue submit producer -- bash -c 'queue_output RESULT_PATH /tmp/out.txt; echo hello > /tmp/out.txt'
queue submit consumer --inherit-env-from producer -- bash -c 'cat "$RESULT_PATH"'
queue run
```

The consumer waits for `producer` to finish successfully, then sources `outputs/<producer-qid>.env`.


## Queue classes

Queue classes provide cooperative concurrency/resource gating:

```bash
queue class init FORENSIC_DSP
queue submit enhance --class FORENSIC_DSP -- ./enhance.sh
```

Class files define sequential class execution, maximum class concurrency, shared assets, and exclusive assets.

See `docs/CLASSES.md`.


## queue_output helper command

`queue_output KEY VALUE` is installed as a per-job helper command and added to `PATH`. This keeps env-drop IPC working under both direct and systemd runners, even when `systemd-run` strips exported Bash functions.


## IPC file checksums

For auditable file hand-offs:

```bash
queue_output_file RESULT_PATH /tmp/result.txt
queue_require_file RESULT_PATH
```

Use `bash -e` or `queue_require_file RESULT_PATH || exit $?` in consumers so validation failure stops the payload.

See `docs/IPC.md`.


## Automatic pre-flight checksum validation

Consumers do not need an extra `--require-file` flag. If a producer uses:

```bash
queue_output_file RESULT_PATH /tmp/result.txt
```

then any consumer using:

```bash
queue submit consumer --inherit-env-from producer -- ./consume.sh
```

automatically validates `RESULT_PATH` before the payload starts.


## Default class and class preflight plugins

Every submitted job records a class. Jobs without `--class` use `JOB_CLASS=DEFAULT`.

Class files can call machine-specific readiness checks:

```bash
CLASS_PREFLIGHT_PLUGINS="vpn.sh"
CLASS_PREFLIGHT_FUNC="check_vpn_ready"
```

Plugins live under `~/.queuebash/class.d/`. If preflight fails, the job stays in `pending/` rather than moving to `failed/`.


## Published asset facilities

Asset plugins publish the checks they provide:

```bash
queue assets
queue assets show path
```

A nested asset such as:

```bash
CLASS_EXCLUSIVE_ASSETS="path:freespace:/mnt/audio:min_gb=100"
```

maps to `~/.queuebash/assets.d/path.sh`, published facility `path:freespace`, and function `queue_asset_check_path_freespace`.


## Asset helper contract validation

Validate asset plugins with:

```bash
queue assets validate
queue assets show path
```

For every published `family:check`, the helper must define `queue_asset_check_family_check`.


## Asset plugins are separate files

Asset checks are not embedded in `queuebash.sh`. The core loads helpers from:

```text
~/.queuebash/assets.d/
```

The bundled standard path helper is shipped as:

```text
assets.d/path.sh
```

and is copied into the queue root only when missing, so site-specific edits are preserved.


## Standard network/system asset plugins

Bundled external plugins now include:

```text
assets.d/net.sh
assets.d/sys.sh
```

List them with:

```bash
queue assets
queue assets show net
queue assets show sys
queue assets validate
```
