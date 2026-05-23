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


## Replace and rollback asset plugins

Install an updated plugin safely:

```bash
queue assets replace net ./net.sh
```

Rollback the last replacement:

```bash
queue assets rollback net
```

List backups:

```bash
queue assets backups
queue assets backups net
```


## Refresh, delete, and explain asset plugins

```bash
queue assets refresh ./assets.d
queue assets delete net
queue assets undelete net
queue assets explain net:tcp_endpoint
```


## Git and database asset plugins

Bundled external plugins include:

```text
assets.d/git.sh
assets.d/db.sh
```

Examples:

```bash
CLASS_SHARED_ASSETS="git:branch:/home/hc3/bashqueues:require_branch=main"
CLASS_SHARED_ASSETS="db:sqlite_accessible:/tmp/test.db:query=SELECT 1"
```

Inspect asset subcommands and families:

```bash
queue assets expand
```


## GitHub publishing class

```bash
queue submit publish_to_git --class GITHUB_PUBLISH -- bash publish_to_github.sh
queue classes show GITHUB_PUBLISH
queue classes edit GITHUB_PUBLISH
queue classes explain GITHUB_PUBLISH
```


## Format validation assets

```bash
CLASS_SHARED_ASSETS="format:json:/tmp/payload.json"
CLASS_SHARED_ASSETS="format:csv:/tmp/data.csv:strict_columns=1"
CLASS_SHARED_ASSETS="format:archive:/tmp/download.tar.gz"
CLASS_SHARED_ASSETS="format:sqlite:/tmp/state.db"
```

Colon-bearing targets are supported:

```bash
CLASS_SHARED_ASSETS="net:http_status:https://github.com:timeout=5"
CLASS_SHARED_ASSETS="net:tcp_endpoint:db.internal:5432:timeout=3"
```


## Delimiter-safe class asset records

Preferred class syntax:

```bash
queue_class_shared_asset net http_status "https://github.com" \
  timeout=5 \
  accept_status="200,201,204,301,302,304,307,308,403"

queue_class_shared_asset net tcp_endpoint "db.internal:5432" timeout=3
```

This avoids delimiter bugs entirely because `:`, `,`, and `=` are preserved inside real Bash arguments.


## Record-only class assets

Class assets are record-only:

```bash
queue_class_shared_asset net http_status "https://github.com" timeout=5
queue_class_shared_asset git branch "/home/hc3/bashqueues" require_branch=main
queue_class_exclusive_claim "github_publish:slot"
```

Legacy `CLASS_SHARED_ASSETS`, `CLASS_EXCLUSIVE_ASSETS`, and `CLASS_ASSETS` are intentionally unsupported during development.


## Dispatch decision in explain

For pending jobs, `queue explain <job>` reports why the worker is not running the job yet:

```text
Dispatch decision
  dependencies
  schedule/not-before state
  class file
  class/resource gate status
  plugin/preflight output
```

This is the first diagnostic command to run when a job is pending but not moving.


## Dispatch trace

If `queue explain <job>` says a pending job is runnable but `queue run` does not print `[worker N] running ...`, enable dispatch tracing:

```bash
QUEUEBASH_TRACE_DISPATCH=1 queue run
queue dispatch-trace
```

The trace records worker entry, `_queue_next_job` entry, candidate selection, and run transition points.


## Candidate-level dispatch trace

`QUEUEBASH_TRACE_DISPATCH=1 queue run` now records each pending candidate and why it was skipped or selected:

```text
candidate <job>
skip <job> dependencies-not-satisfied
skip <job> class-or-resource-blocked
selected <job>
move pending->running ok <job>
claim acquire ok <job>
about to run <job>
```


## Next-job stdout purity

`_queue_next_job` has a strict contract: stdout is either one selected pending job path or empty.

Asset and class plugin output is captured and written to dispatch trace as:

```text
class output <qid>: asset_check_ok: ...
```

This prevents plugin messages from contaminating the path passed to `mv pending -> running`.


## QueueManager split

QueueManager is now a lazily sourced module:

```text
queuemgr.sh
```

Launch it with:

```bash
queue mgr
queue manager
queue qm
```

Scriptable record-format class creation:

```bash
queue mgr class-create GITHUB_PUBLISH_TEST \
  --no-parallel \
  --max-concurrent 1 \
  --exclusive-claim github_publish:slot \
  --shared-asset net http_status "https://github.com" timeout=5 \
  --shared-asset git repo_exists "/home/hc3/bashqueues" \
  --shared-asset git branch "/home/hc3/bashqueues" require_branch=main
```

The manager generates record-format classes only.


## Standalone queuemgr compatibility

The bare command:

```bash
queuemgr
```

now routes to the new lazy-loaded QueueManager, equivalent to:

```bash
queue mgr
```

The old built-in REPL is kept only for development diagnostics:

```bash
queue legacy-manager
queue legacy-queuemgr
```


## QueueManager asset hints

QueueManager has built-in hints for common asset facilities:

```bash
queue mgr hints
queue mgr hint net:http_status
queue mgr hint git:branch
queue mgr picker
```

During interactive class creation, type `?` at the asset-family prompt to list installed assets and hinted facilities.


## Plugin-published asset hints

Asset helpers may publish UI/editor hints with:

```bash
queue_asset_hints
```

The function emits TSV records:

```text
family:check<TAB>target=...<TAB>params=...<TAB>example=...<TAB>notes=...
```

QueueManager uses these hints for:

```bash
queue mgr hints
queue mgr hint net:http_status
queue mgr picker
```


## Hint compatibility fallback

`queue asset-hints` prefers helper-published `queue_asset_hints` metadata. If an installed helper predates the hint contract, bashqueues synthesizes a minimal hint from `queue_asset_facilities` so QueueManager can still display available facilities.

To get richer target/parameter hints, refresh or replace the asset helper with a version that defines `queue_asset_hints`.


## Class default job settings

Classes may define defaults copied into each job record at submit time:

```bash
CLASS_DEFAULT_RUNNER=systemd
CLASS_DEFAULT_CPU_LIMIT=50%
CLASS_DEFAULT_MEM_LIMIT=512M
CLASS_DEFAULT_MAX_LOG_SIZE_BYTES=1048576
CLASS_DEFAULT_LOG_OVERFLOW_POLICY=stderr-only
CLASS_DEFAULT_TIMEOUT=30s
CLASS_DEFAULT_KILL_AFTER=5s
CLASS_DEFAULT_LOG_TAG='${JOB_NAME}.${JOB_ID}'
CLASS_DEFAULT_OUTPUT_DIR='${QUEUEBASH_ROOT}/class_outputs/${JOB_NAME}/${JOB_ID}'
CLASS_DEFAULT_ENV_PREFIX='${JOB_NAME}_${JOB_ID}'
```

Templates are expanded using the final `JOB_ID`, `JOB_NAME`, and `QUEUEBASH_ROOT`.

QueueManager can set these with `queue mgr class-create --default-*`.


## CPUQuota class defaults

For systemd-backed jobs, class defaults may use either form:

```bash
CLASS_DEFAULT_CPU_LIMIT=50
CLASS_DEFAULT_CPU_LIMIT=50%
```

Both are normalized to the valid systemd property:

```text
CPUQuota=50%
```

The value is passed as an argv element and is not printf-escaped.


## Timeout enforcement

If a job record contains:

```bash
TIMEOUT=30s
KILL_AFTER=5s
```

the payload is wrapped as:

```bash
timeout --signal=TERM --kill-after=5s 30s <command...>
```

For systemd-backed jobs, this appears after the systemd `--` separator:

```text
systemd-run ... -- timeout --signal=TERM --kill-after=5s 30s rexx waiter.rex
```


## Execution caps and billing cycles

Classes can express cost/operational caps:

```bash
CLASS_DEFAULT_TIMEOUT=30s
CLASS_DEFAULT_KILL_AFTER=5s
CLASS_DEFAULT_CPU_SECONDS=20
CLASS_DEFAULT_BILLING_UNIT_SECONDS=60
CLASS_DEFAULT_BILLING_CYCLES=1
CLASS_DEFAULT_BILLING_GRACE_SECONDS=5
CLASS_DEFAULT_BILLING_POLICY=shortest-cap-wins
```

Billing timeout is calculated as:

```text
billing_timeout = billing_unit_seconds * billing_cycles - billing_grace_seconds
```

The effective timeout is the shortest valid cap between explicit `TIMEOUT` and the billing-cycle timeout.

`CPU_SECONDS` is currently metadata shown by `queue explain`; live CPU accounting enforcement is intended for a later systemd-monitor patch.


## runnable:path_safe

`runnable:path_safe` is a preflight asset for scripts that may depend on a specific current working directory or unsafe relative paths.

Example:

```bash
queue_class_shared_asset runnable path_safe "waiter.rex" \
  allow_relative=1 \
  require_cwd="/home/hc3/bashqueues"
```

Parameters:

```text
require_shebang=1     require the script to start with #!
allow_relative=1      allow relative path assumptions
require_cwd=/path     require a working directory to exist
scan_depth=200        number of lines to scan
```


## Class refresh

Refresh class definitions from a directory of `.env` files:

```bash
queue classes refresh ./classes
queue mgr class-refresh ./classes
```

Existing class definitions are backed up under:

```text
~/.queuebash/classes/.backup/
```

Refresh is intended for loading bundled class definitions such as `REXX_RUNAWAY.env` into a user's queue root.


## Resubmit adopts current class

When a failed/cancelled/deleted job is resubmitted, bashqueues preserves the job intent but re-applies the current class definition to the new QID. This means changed class defaults such as timeout, billing caps, CPU/memory limits, and log caps are adopted by resubmitted jobs.


## Job history

Show lifecycle events, dispatch attempts, resubmit links, exit codes, and logs:

```bash
queue history <job-id|name>
```

`queue explain <job>` includes a compact History section and points to the full command.


## Asset refresh dispatcher fix

`queue assets refresh ./assets.d` refreshes asset helpers from a directory of `.sh` plugin files. It must route to the asset plugin refresher, not class refresh.

Use after installing patched bundled helpers:

```bash
queue assets refresh ./assets.d
queue assets validate
queue assets explain runnable:path_safe
queue asset-hint runnable:path_safe
```


## Unambiguous refresh aliases

For scriptable use and QueueManager internals, bashqueues provides direct refresh aliases:

```bash
queue asset-refresh ./assets.d
queue class-refresh ./classes
```

The older grouped commands remain valid:

```bash
queue assets refresh ./assets.d
queue classes refresh ./classes
```


## Asset helper argv contract

Asset check helpers receive the asset target as `$1`, followed by optional `key=value` parameters:

```bash
queue_asset_check_runnable_interpreter "rexx"
queue_asset_check_runnable_path_safe "/home/hc3/bashqueues/waiter.rex" allow_relative=1
```

They do not receive the full asset token as `$1`.


## Class default working directory

A class can force the execution working directory for submitted/resubmitted jobs:

```bash
CLASS_DEFAULT_WORKING_DIR=/home/hc3/bashqueues
```

This is copied into the job record as:

```bash
PWD_AT_SUBMIT=/home/hc3/bashqueues
```

and is useful for jobs whose command uses relative paths, for example:

```bash
queue submit rexx_waiter_caps --class REXX_RUNAWAY -- rexx waiter.rex
```

even when the submit command is typed from another directory.


## Class job command context

When a class is sourced for a specific job preflight, bashqueues exports command context variables that class records can use:

```bash
QUEUEBASH_JOB_WORKDIR
QUEUEBASH_COMMAND_0
QUEUEBASH_COMMAND_ARG_1
QUEUEBASH_COMMAND_ARG_1_ABSPATH
```

Use `${QUEUEBASH_COMMAND_ARG_1_ABSPATH:-fallback}` in class files so class-default inspection still works before a concrete job is loaded.


## Class wizard

QueueManager includes a zero-dependency terminal class builder:

```bash
queue mgr class-wizard CLASS
queue mgr class-builder CLASS
```

It uses `tput` and raw keyboard input where available, falling back to normal prompts otherwise. The wizard browses published asset facilities, shows helper-published hints, adds record-format shared/exclusive assets, previews the class, and saves it to `~/.queuebash/classes/CLASS.env`.


## Network usage caps

Charged data links can be handled with plugins.

Class/preflight gate:

```bash
queue_class_shared_asset net_usage allowance "wwan0" allowance_bytes=10G direction=rx_tx
```

Testable counter-file form:

```bash
queue_class_shared_asset net_usage allowance "charged" counter_file=/tmp/charged.bytes allowance_bytes=10G
```

Per-job runtime accounting:

```bash
CLASS_DEFAULT_NET_USAGE_INTERFACE=wwan0
CLASS_DEFAULT_NET_USAGE_DIRECTION=rx_tx
CLASS_DEFAULT_NET_USAGE_LIMIT_BYTES=500M
CLASS_DEFAULT_NET_USAGE_POLICY=mark-failed
```

Jobs record `NET_USAGE_START_BYTES`, `NET_USAGE_END_BYTES`, `NET_USAGE_USED_BYTES`, and `NET_USAGE_EXCEEDED`. `mark-failed` converts a successful payload into exit code `87` when the usage limit is exceeded.


## Time-window class restrictions

Use the `time:window` asset to prevent dispatch outside allowed periods:

```bash
queue_class_shared_asset time window "overnight-window" \
  weekdays=mon-fri \
  weekday_windows=18:00-05:00 \
  weekends=sat-sun \
  weekend_windows=always
```

Bundled class:

```text
OVERNIGHT_WINDOW
```

`OVERNIGHT_WINDOW` blocks weekday daytime dispatch. To override the restriction for a specific job, keep the job in `OVERNIGHT_WINDOW` and add a QID exception overlay:

```bash
queue exception add <qid> time:window --reason "operator-approved daytime run"
```


## QID exception overlays

Class restrictions should normally stay inside the class. To override a restriction for one job, add an exception overlay to the QID:

```bash
queue exception add <qid> time:window --reason "operator-approved daytime run"
queue exception list <qid>
queue exception clear <qid> time:window
```

The exception key may be:

```text
family              e.g. time
facility            e.g. time:window
full asset token    e.g. time:window:overnight-window
```

During class preflight, only the matching asset gates are skipped. Each creation and application is logged as an event, and `queue explain <qid>` shows the active overlays.

This is preferred over changing the job to a separate exception class because it keeps the original policy class visible while documenting exactly which restrictions were ignored.


## full-screen panel manager

A curses-backed manager is available for panel-oriented workflows:

```bash
queue mgr panel
queue panel
```

Panels:

```text
Jobs
Classes
Assets
Exceptions
Restriction Builder
```

The screen uses side-by-side panels with scrolling list/detail areas. The restriction builder shows valid asset facilities, helper hints, and selectable queue/class variables such as `${QUEUEBASH_COMMAND_ARG_1_ABSPATH}` and `${QUEUEBASH_JOB_WORKDIR}`.

The manager is intentionally separate from `queuebash.sh`; it invokes existing `queue ...` commands so the queue core remains the source of truth.

If launched directly with `python3 queuemgr_panel.py`, the manager auto-discovers an adjacent `queuebash.sh` and sources it before running `queue ...` commands.

The panel manager header shows the resolved `queuebash.sh` source. If it displays `NO QUEUE SOURCE`, launch from the source tree or set `QUEUEBASH_SOURCE=/path/to/queuebash.sh`.


## Panel manager operator console

The panel manager supports operator workflows:

```text
d       toggle dry-run mode
f       filter current panel
[ / ]   switch right-hand job tabs
e       add QID exception overlay after showing the job class
c       clear QID exception overlay
x       context action
C       clear queue buckets
```

Job detail tabs:

```text
Explain
Class
Exceptions
History
Log
```

Class and asset panels expose actions for explain, validate, refresh, delete/archive, and rollback where the corresponding `queue ...` command exists.


### Scrollable command output

Panel manager command-output windows are scrollable:

```text
Up/Down       line scroll
PgUp/PgDn     page scroll
Home/End      start/end
q/Esc/Enter   close
```

Modal windows clear their full rectangle before drawing and redraw the panel screen when closed.


## Exception overlays in explain

`queue explain <qid>` always includes an exception overlay section:

```text
Exception overlays
  none
```

or:

```text
Exception overlays
  ignore:            time:window
    reason:          operator approved daytime run
    by:              hc3
    created:         2026-05-23T18:09:31+01:00 (age 42s)
```

This makes the QID explanation the primary audit surface for any restriction bypass.


## Panel Class Creator

The panel manager includes a Class Creator panel.

Workflow:

```text
1. Open: queue panel
2. Go to Class Creator
3. Set name/purpose/defaults
4. Go to Restriction Builder
5. Select a facility and add a shared/exclusive restriction to the draft
6. Return to Class Creator
7. Preview, validate, save
```

Generated classes use record-format functions only:

```bash
queue_class_shared_asset time window "overnight-window" weekdays=mon-fri weekday_windows=18:00-05:00
queue_class_exclusive_claim "runtime:nightly:slot"
```

No legacy `CLASS_SHARED_ASSETS` or colon/comma token parsing is generated.


## Panel Task Creator

The panel manager includes a Task Creator panel.

Workflow:

```text
1. Open: queue panel
2. Go to Task Creator
3. Set name and command
4. Select class from installed classes
5. Set priority and optional schedule/not-before
6. Preview or dry-run
7. Submit
```

The generated command uses the existing queue submit interface:

```bash
cd /home/hc3/bashqueues && queue submit nightly --priority 10 --class OVERNIGHT_WINDOW --not-before "2026-05-23T22:00:00+01:00" -- bash job.sh
```

The Classes panel can also set the selected class into Task Creator using the `use-for-task` action.


### Task Creator job names and execution directory

Task Creator normalizes job names before submit. Spaces and unsafe characters become underscores:

```text
publish git -> publish_git
```

Generated submit commands put the job name before options and can include an execution directory:

```bash
cd /home/hc3/bashqueues && queue submit publish_git --priority 10 --class GITHUB_PUBLISH -- bash publish_to_github.sh
```


### Task Creator execution directory is not a submit option

`queue submit` captures the submit directory from the process current working directory. Task Creator therefore previews:

```bash
cd /home/hc3/bashqueues && queue submit publish_git --class GITHUB_PUBLISH -- bash publish_to_github.sh
```

and internally runs `queue submit` with that working directory. It does not emit `--chdir`.


## User context and root/operator use

Classes may declare default user context:

```bash
CLASS_DEFAULT_RUN_USER=appuser
CLASS_DEFAULT_SUBMIT_USER=appuser
```

`CLASS_DEFAULT_RUN_USER` is applied to the job as `RUN_USER`, meaning the payload should execute as that Unix account. When root runs the queue worker, queuebash attempts to switch user with `runuser`/`sudo` for direct execution, or systemd `--uid` where systemd execution is available.

`CLASS_DEFAULT_SUBMIT_USER` is recorded as `SUBMIT_USER` for audit/intent. The panel Task Creator also has a `submit user` field. When set, it runs the submit command as that user, for example:

```bash
runuser -u appuser -- bash -lc 'cd /home/appuser/project && queue submit nightly --class APP_NIGHTLY -- bash job.sh'
```

This is intended for root/operator workflows where one account can manage jobs for multiple user queue roots.


## Root administering user queues safely

Root can administer another user's queue files, but root must not evaluate queue-local code from that user.

Safe root-side operations include file/record administration such as list, cancel/delete, and exception overlay edits.

Commands that may source/evaluate queue-local code are delegated to the queue owner when `QUEUEBASH_ROOT` is owned by a non-root user. This includes:

```text
queue run
queue submit
queue explain
queue classes explain/validate/refresh/replace/rollback/edit
queue assets explain/validate/refresh/replace/rollback/expand
queue panel
```

The delegation path is:

```bash
runuser -u <queue-owner> -- bash -lc 'export QUEUEBASH_ROOT=...; source queuebash.sh; queue ...'
```

Set this to refuse rather than delegate:

```bash
export QUEUEBASH_ROOT_USER_QUEUE_MODE=refuse
```

There is an explicit escape hatch for trusted maintenance only:

```bash
export QUEUEBASH_ALLOW_ROOT_USER_QUEUE_EVAL=1
```

The default rule is: if code needs to be evaluated, it runs as the owner of the queue, not as root.


### Delegated submit working directory

When the panel Task Creator submits as another user and no execution directory is set, it submits from that user's home directory instead of inheriting the operator's current directory:

```bash
runuser -u testu -- bash -lc 'cd "$HOME" && queue submit run_as_testu -- bash -c "echo testu"'
```

This prevents a job in `testu`'s queue from recording an inaccessible root/operator submit directory such as `/home/hc3/bashqueues`.

If a specific execution directory is required, set it explicitly in Task Creator.


## User systemd bus fallback

`RUNNER=auto` prefers systemd only when the user's systemd bus is actually usable. In `su`/`runuser` shells, `XDG_RUNTIME_DIR` may exist but the user bus may still be inaccessible.

Queuebash now checks:

```text
systemd-run exists
systemctl exists
XDG_RUNTIME_DIR is set
XDG_RUNTIME_DIR/bus is a socket
systemctl --user show-environment succeeds
```

If those checks fail, `RUNNER=auto` falls back to the direct runner instead of attempting `systemd-run --user`.

Job logs include:

```text
systemd_user_bus: user-bus-ok
systemd_user_bus: user-bus-unusable
systemd_user_bus: user-bus-missing
```


## Root running payloads as another user

When root runs a queued payload for another Unix user, `RUNNER=auto` resolves to the direct runner.

This avoids depending on another user's `systemd --user` bus. The direct runner uses the root-controlled user switch path, for example `runuser`, and is the predictable cross-user fallback.

Policy:

```text
root running root payload       -> normal auto behaviour
user running own payload        -> systemd if user bus works, otherwise direct
root running RUN_USER=someuser  -> direct
```

The job log records the policy when active:

```text
foreign_run_user_runner_policy: root-foreign-user-auto-direct run_user=someuser
```
