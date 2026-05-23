# Changelog

## 0.9.0

- Add nested asset-implied preflight checks with published plugin facilities.
- Add `~/.queuebash/assets.d/` asset plugins and standard `path.sh` helper.
- Asset plugins publish capabilities using `queue_asset_facilities`.
- Add `queue assets` / `queue facilities` and `queue assets show <family>`.
- Add standard facilities: `path:exists`, `path:mount`, and `path:freespace`.
- A nested token like `path:freespace:/path:min_gb=100` maps to `queue_asset_check_path_freespace` only if the plugin publishes `path:freespace`.
- Failed implied asset preflight leaves jobs in `pending/` and logs `resource_blocked`.
- Add `tests/classes_asset_facilities.sh`.


## 0.8.9

- Every job now has a class; jobs without `--class` use `JOB_CLASS=DEFAULT`.
- Automatically create `~/.queuebash/classes/DEFAULT.env`.
- Add dynamic class preflight hooks: `CLASS_PREFLIGHT_PLUGINS`, `CLASS_PREFLIGHT_FUNC(S)`, and `CLASS_PREFLIGHT_CMD(S)`.
- Preflight failure leaves the job in `pending/` and logs `resource_blocked`, rather than failing the job.
- Add `~/.queuebash/class.d/` for machine-specific class plugin helpers.
- Add `tests/classes_default_preflight.sh`.


## 0.8.8

- Add automatic pre-flight checksum validation for inherited `queue_output_file` hand-offs.
- Consumers no longer need a `--require-file` option.
- If inherited env contains `KEY`, `KEY_SHA256`, and `KEY_BYTES`, the worker validates `KEY` before launching the payload.
- If validation fails, the consumer moves to `failed/` and the payload is not executed.
- Add `tests/ipc_auto_preflight_checksum.sh`.


## Publish script test/docs packaging

- Update `publish_to_github.sh` to copy the full `tests/` directory, `docs/`, `CHANGELOG.md`, and `COPYING_NOTE.md`.
- Preserve executable bits on test scripts.
- Run quick non-destructive regression tests before publishing when present.
- Commit all docs/tests instead of only `tests/selftest.sh`.


## 0.8.7

- Add `queue_output_file KEY PATH` helper for auditable file hand-offs.
- Add `queue_require_file KEY` helper for consumer-side validation.
- Env-drop file hand-offs now include `KEY_SHA256`, `KEY_BYTES`, and `KEY_MTIME` metadata.
- Document fail-fast usage with `bash -e` or `queue_require_file KEY || exit $?`.
- Add `tests/ipc_checksum.sh`.


## 0.8.6

- Fix systemd-run consumers not receiving inherited env-drop variables such as `RESULT_PATH` and `CHECKSUM`.
- Record inherited env-drop keys in `QUEUEBASH_INHERITED_ENV_KEYS`.
- Pass inherited keys explicitly to `systemd-run` using `--setenv=<KEY>=<VALUE>`.
- Add inherited env source/key metadata to logs.
- Add `tests/ipc_systemd_inherited_envkeys.sh`.


## 0.8.5

- Fix repeated-name IPC inheritance by binding `--inherit-env-from <name>` to an exact QID at submit time when possible.
- The bound QID is stored in both `INHERIT_ENV_FROM` and the implied `DEPENDS_AFTER_SUCCESS`.
- Prefer a unique pending/running/paused producer over historical done jobs.
- Add `tests/ipc_submit_bind_qid.sh`.


## 0.8.4

- Fix env-drop inheritance by producer name in the live worker path.
- Replace brittle grep/xargs parsing of `INHERIT_ENV_FROM` and `JOB_NAME` with safe sourcing of queue-generated job metadata.
- Add regression test matching `queue submit consumer --inherit-env-from producer` followed by `queue run`.


## 0.8.3

- Fix `queue_output: command not found` under `systemd-run`.
- Install `queue_output` as a per-job external helper command under `helpers/<QID>/bin` and prepend it to `PATH`.
- Pass `PATH` and queue IPC environment variables explicitly to `systemd-run` via `--setenv`.
- Add stale IPC helper cleanup.
- Add `tests/queue_output_helper.sh`.


## 0.8.2

- Add queue classes with cooperative filesystem claims.
- Add `queue submit --class <CLASS>`.
- Add class constraints: `CLASS_ALLOW_PARALLEL`, `CLASS_EXCLUSIVE`, `CLASS_MAX_CONCURRENT`, `CLASS_SHARED_ASSETS`, and `CLASS_EXCLUSIVE_ASSETS`.
- Add exclusive/shared asset claims under `claims/assets/` and class claims under `claims/classes/`.
- Add `queue class list|show|init` and `queue claims`.
- Add `docs/CLASSES.md` and `tests/classes.sh`.


## 0.8.1

- `queue submit --inherit-env-from <name|qid>` now automatically adds an after-success dependency.
- Env-drop inheritance can now be submitted by producer job name before the producer has completed.
- At dispatch time, the worker resolves the successful producer name to the completed producer QID and sources `outputs/<QID>.env`.
- Ambiguous completed producer names require using a QID.
- Add `tests/ipc_name_dependency.sh`.


## 0.8.0

- Add filesystem-native IPC layer.
- Add `queue_output KEY VALUE` for payload env-drop outputs under `outputs/<QID>.env`.
- Add `queue submit --inherit-env-from <QID>` for downstream jobs.
- Add `streams/<QID>.fifo` creation/cleanup and `queue stream <QID>` live FIFO tap.
- Add `docs/IPC.md` and `tests/ipc_env_drop.sh`.


## 0.7.13

- Replace worker-side bulk log compression with targeted compression of only the job just completed.
- Keep `queue compress-logs` as the explicit bulk compression command.
- Compress after success/failure/retry hooks are appended.
- Add `docs/TARGETED_COMPRESSION.md` and `tests/targeted_compression.sh`.


## 0.7.12

- Change `queue tail` default for running jobs to show the last 40 lines and then follow.
- Add `queue tail --tail N` / `-n N`, `--no-follow`, and `--from-start`.
- Add `docs/TAIL.md` and `tests/tail_options.sh`.


## 0.7.11

- Fix log drain synchronization so stdout/stderr drainers are waited before writing `finished` / `exit_code` footer.
- Replace `cat fifo | logger` with direct FIFO input to logger so the waited PID is the logger itself.
- Append post-run worker records explicitly in streaming mode to avoid stale file-offset writes.
- Add `docs/LOG_DRAIN_SYNCHRONIZATION.md` and `tests/log_drain_sync.sh`.


## 0.7.10

- Fix worker/operator cancellation race: if a job record has already moved to `cancelled/`, the worker reports cancelled instead of failed after the payload exits non-zero.
- Add `worker_observed_cancelled` event.
- Update cancellation model wording for systemd jobs.
- Add `docs/CANCELLATION_RACES.md` and `tests/cancel_worker_race.sh`.


## 0.7.9

- Fix systemd cancellation fallback: do not signal RUN_PGID after targeting SYSTEMD_UNIT.
- Use `systemctl --user kill --kill-whom=all --signal=<SIG>` for systemd jobs.
- Clean stream temp FIFOs/suppression markers on job completion, cancellation, and health repair.
- Add `tests/systemd_no_pgid_fallback.sh`.


## 0.7.8

- Fix systemd runner process accounting: `RUN_PID` is treated as the `systemd-run` client, not the payload PID.
- `queue health` now marks running jobs stale when their recorded `SYSTEMD_UNIT` is inactive/dead, even if `RUN_PID` is still alive.
- `queue cancel` / `queue kill` now prefer `systemctl --user kill --signal=<SIG> <SYSTEMD_UNIT>` before PGID/PID fallback.
- `queue explain` labels systemd `RUN_PID` as client and warns on stale-running unit state.
- Add `docs/SYSTEMD_PROCESS_MODEL.md` and `tests/systemd_process_model.sh`.


## 0.7.7

- Change default log overflow behaviour to `stderr-only`.
- At the first log cap, stdout is suppressed while stderr continues until the next cutoff.
- Streams are drained instead of closed so noisy jobs do not crash with broken output streams.
- Add `--log-overflow stderr-only|kill|allow`.
- Add `tests/log_overflow_stderr_only.sh`.


## 0.7.6

- Improve `queue restore` / `queue undelete` diagnostics when no matching deleted job exists.
- If a target exists in another state, report the matching QID/state/name and remind that restore only operates on `deleted/` jobs.


## 0.7.5

- Add health-integrity report via `queue health [--fix] [--deep]`.
- Check root/state directory writability, events.jsonl, free disk and inodes, helper commands, malformed job files, stale running jobs, dependency warnings, and basic cycle hints.
- Add `docs/HEALTH.md` and `tests/health_integrity.sh`.


## 0.7.4

- Add `tests/dependency_edge_cases.sh` covering retroactive satisfaction, failed-parent blocking, duplicate-name semantics, strict QID dependencies, circular pending behaviour, and fan-in.
- Add `docs/DEPENDENCY_EDGE_CASES.md`.


## 0.7.3

- `queue clean-logs --force` now appends log cleanup audit metadata to the matching job record.
- Add `LOG_CLEANED`, `LOG_CLEANED_AT`, `LOG_CLEANED_PATH`, and `LOG_CLEANED_BYTES` fields.
- Emit `log_cleaned` events to `events.jsonl`.


## 0.7.2

- Add `queue clean-logs` for safe log cleanup.
- Add age/state filters, orphan cleanup, dry-run preview, and force deletion.
- Add `docs/LOGS.md` documenting combined stdout/stderr, compression, and log cleanup.


## 0.7.1

- Add scheduling commands to shell completion: `submit-in`, `submit-at`, `in`, `at`, `scheduled`, and `schedule`.


## 0.7.0

- Add one-shot scheduling: `queue submit-in <delay>` and `queue submit-at <time>`.
- Add `NOT_BEFORE_EPOCH` / `SCHEDULE_LABEL` job metadata.
- Workers skip pending jobs whose schedule is not due.
- Add `queue scheduled` / `queue schedule` and `docs/SCHEDULING.md`.


## 0.6.3

- Add `--on-retry-failure` / `--on-attempt-failure` hook for remediation before retry scheduling.
- Add `tests/retry_dependency_touch.sh` integration test for retry + remediation hook + after-success dependency release.


## 0.6.2

- Reject exact-name self-dependencies at submit time.
- Add self-dependency validation to `tests/after_success.sh`.
- Document safe failure semantics and dependency cycle behaviour.


## 0.6.1

- Fix multi-token `DEPENDS_AFTER_SUCCESS` storage and reading.
- Add dedicated `tests/after_success.sh` dependency regression test.
- Force `QUEUEBASH_RUNNER=direct` inside the general regression harness to avoid user-systemd EXEC/session noise when testing generic queue semantics.


## 0.6.0

- Add success dependencies: `--after-success`, `--after`, and `--depends-on`.
- Workers skip pending jobs whose dependencies are not satisfied.
- Add `queue deps` and `queue waiting`.
- Add `docs/DEPENDENCIES.md`.


## 0.5.1

- `queue explain <exact-name>` now explains all matching jobs instead of refusing multiple exact-name matches.
- Pending/paused jobs show `used: not-started`, planned runner, and correct no-process cancellation semantics.


## 0.5.0

- Treat active systemd units as authoritative for running jobs.
- `queue pids` now reports systemd `MainPID` for systemd-run jobs.
- `queue health` no longer marks running systemd jobs stale just because `RUN_PID` has exited.
- Cancellation/log watchdog helpers now prefer systemd unit/MainPID where available.


## 0.4.9

- Add `queue explain <job>` operator summary.
- Add `docs/RUNNERS.md` documenting direct vs systemd runners, containment, metrics, logs, and log caps.
- Add `ex` shortcut inside `queuemgr`.


## 0.4.8

- Add live log watchdog for `MAX_LOG_SIZE_BYTES`.
- Add `--allow-large-log` / `--no-log-cap` submit option.
- Log-overflow jobs are terminated and marked with `LOG_OVERFLOW=*` metadata.


## 0.4.7

- Add `compress-logs` and `gzip-logs` to shell completion.
- Add `gz` shortcut to `queuemgr` for completed-log compression.


## 0.4.6

- Move completed-log gzip compression to a post-job cleanup pass after log file descriptors are closed.
- Add `queue compress-logs` / `queue gzip-logs` for existing done/failed logs.


## 0.4.5

- Gzip completed job logs by default (`QUEUEBASH_GZIP_LOGS=1`).
- Add `.log.gz` support to `queue show` and `queue tail`.
- Make `queue show` display only the last 120 log lines by default; add `--full` and `--tail N`.


## 0.4.4

- Add runner policy: `QUEUEBASH_RUNNER=auto|systemd|direct` and per-job `--runner`.
- Prefer systemd in auto mode when available.
- Record `RUNNER_USED` and observed `SYSTEMD_UNIT`.
- Add `queue metrics` / `queue unit` for systemd unit/cgroup inspection.


## 0.4.3

- Fix resource-limited `systemd-run` jobs to use `--working-directory=$PWD_AT_SUBMIT`.
- Relative commands now resolve from the original submit directory for `--cpu` / `--mem` jobs.


## 0.4.2

- Fix `queue list` table layout for long QIDs by calculating column widths dynamically.


## 0.4.1

- Render `queuemgr` help in a compact three-column grouped layout.
- Add `ci` / `cid` shortcuts for clearing interrupted jobs.


## 0.4.0

- Add `interrupted` state.
- Add `queue health` and `queue health --fix`.
- Detect stale running jobs with dead `RUN_PID` and move them to `interrupted` on fix.
- Remove stale detached worker PID files on health fix.
- Allow resubmit/retry from `failed` or `interrupted` jobs.
- Add `queuemgr` shortcuts: `h` and `hf`.


## 0.3.8

- Use `systemd-run --user --pipe --wait --collect` for resource-limited jobs.
- Add `queue limits --probe` to test user-systemd resource enforcement directly.
- Log the exact launch argv for resource-limited jobs.


## 0.3.7

- Fix systemd resource-limit execution path.
- Use `systemd-run --user --wait --collect` transient services instead of invalid `--wait --scope` combination.


## 0.3.6

- Render `queuemgr` command help in compact two-column grouped form.
- Reuse the same compact help for `help` and `?` inside `queuemgr`.


## 0.3.5

- Add `queuemgr` shortcuts for clearing cancelled jobs: `cc` and `ccd`.
- Ensure completion/help includes `cancelled` for `queue clear`.


## 0.3.4

- Harden regression harness state waits and diagnostics.
- Replace nested shell hook tests with `tests/write_marker.sh`.


## 0.3.3

- Add comprehensive regression harness.
- Add stdout/stderr, rc 0, rc non-zero, hooks, cancellation, retry, resubmit, and logstorm test helpers.
- Add dedicated million-line logstorm stress test.


## 0.3.2

- Document and enforce cancellation semantics.
- `queue cancel` and `queue kill` move jobs to `cancelled` without running `ON_FAILURE`.
- Cancellation events now explicitly record `hook=none`.


## 0.1.0

Initial public queuebash release:

- filesystem-backed Bash job queue
- pending/running/paused/done/failed/cancelled/deleted states
- priorities
- dry-run safety
- hooks
- resubmit/retry
- PID/PGID tracking
- cancel/kill
- tail/stats/events
- overfiles/overdir helpers
