## 0.16.24

- Add typed Jobs panel mutation commands: `job change priority`, `job kill`, `job delete`, `job undelete`, and `job edit`.
- Bare job actions typed while the Jobs panel is active apply to the selected job, for example `kill`, `delete`, `undelete`, `change priority 5`, and `edit`.
- `job edit` implements the safe edit pattern: cancel the selected job first, then create/populate a new Task Creator draft from the job metadata.
- Keep job copy command-only; function keys do not mutate jobs.
- Add static regression coverage for job mutation command routing.

## 0.16.22

- Panel command line is now context-first on the Task Creator/job editor.
- Typing `submit` while in Task Creator now means `task submit`; it submits the current task draft instead of being treated as an unrelated panel/global command.
- The same current-task shorthand applies to `save`, `preview`, `dryrun`, `clear`, and task field edits.
- Added regression coverage for bare `submit` from the Task Creator screen.

## 0.16.21

- Reorder contextual `*` command completions so current object/action commands appear first.
- Keep `panel:*` navigation completions grouped at the bottom of the popup.
- Add static regression coverage for completion ordering.

# Changelog

## 0.16.19

- Add contextual `*` completion to the panel command line.  The completion list is aware of the current panel and command prefix.
- Queue Users command completion now offers known users plus `panel:*` jumps, so an operator can navigate without leaving command-entry mode.
- Add `panel:<name>` command routing and command-building flow, for example `panel:classes` followed by `*` for class choices/actions.
- Add class-object action routing for abbreviated commands such as `cla mycla hist`, which jumps to Classes, selects the unique class match, and shows class history/backups.
- Add static regression coverage for contextual command completions and class-object action routing.

## 0.16.18

- Add typed job fragment commands such as `job 1798231 history` and `history 1798231`; the panel switches to Jobs, selects the matching QID, moves to the History detail tab, and shows the history output.
- Remove numeric labels from top-level panel tabs. Tabs now show portable hotkeys such as `[J] Jobs`, `[T] Task Creator`, and `[M] Maintenance`.
- Keep number selection only inside searchable field popups where it selects list entries, not top-level panels.
- Add static regression coverage for typed job-history navigation and hotkey-labelled tabs.

## 0.16.17

- Leave F11 deliberately unbound because many Linux desktops and terminal emulators reserve it for full-screen.
- Keep exception operations on the typed command line with `ex`, `exception`, `ce`, and `clear-exception`.
- Update the panel footer/help/docs to show F12/Esc quit and no F11 action.
- Add regression coverage proving F11 is not advertised as an active exception key.

## 0.16.15

- Task Creator now has a `save` action that writes the current task fields into persistent `queue draft` storage without submitting.
- Add `queue draft create <name> [options] -- <command...>` for panel-created drafts.
- Successful Task Creator submit now clears the working Task Creator draft, so accidental repeat submits require deliberate re-entry or loading a draft.
- Dry-run submits retain the working draft.
- Draft submit now honours saved `NOT_BEFORE_TEXT` as well as saved epoch scheduling.
- Add regression/static coverage for Task Creator save-as-draft and submit-clear behaviour.

## 0.16.14

- Add a panel Maintenance view for fixes, log rolling, log cleaning, and queue-bucket delete/tidy-up actions.
- Maintenance actions default to creating normal queued jobs using the new `QUEUE_MAINTENANCE` class instead of running immediately in the operator shell.
- Add confirmed `direct` run-now Maintenance action for urgent recovery.
- Add editable Maintenance schedule/priority/command fields using the shared first-unique-letter/searchable-list panel behaviour.
- Add the standard `classes/QUEUE_MAINTENANCE.env` class for serialized, bounded housekeeping jobs.
- Physically remove the old legacy readline/text QueueManager REPL functions and obsolete completion helper.
- Add regression/static coverage for the Maintenance panel and legacy manager removal.

## 0.16.13

- Fix selected user queue panel launch from root: `queue mgr` no longer delegates/replaces the operator shell just because the selected queue root is owned by another user.
- Replace `exec runuser`/`exec sudo` in the root/user-queue safety delegation path with normal subprocess invocation so delegated commands return to the original shell.
- Keep the safety model: commands that evaluate queue-local code still delegate to the queue owner, but the panel launcher itself remains an operator/root UI.
- Added regression coverage for manager non-delegation and no-exec delegated user-queue commands.

## 0.16.12

- Panel Queue Users now includes an explicit clear/current selection to return to no selected queue owner.
- Task Creator submit user fields now accept `current`, `none`, `clear`, `default`, `-`, or the `<current/default>` list choice to remove delegation.
- Non-root panel sessions no longer generate `runuser` for the current user when a queue owner or submit user matches the logged-in user.
- Non-root attempts to delegate to a different Unix user now fail with a clear diagnostic instead of producing `runuser: command not found` style failures.
- Added regression coverage for panel queue-owner clearing and non-root runuser suppression.

## 0.16.11

- `queue --queue-user USER` and `queue user USER` now select the effective queue user without requiring a following command.
- Kept `queue --queue-user USER <command>` and `queue user USER <command>` as direct one-shot command forms.
- Added visible selected-queue context above job tables, so switched-user operation is obvious during `queue list`.
- Added static regression coverage for sticky queue-user selection and selected-user banner output.

## 0.16.10

- Improved Python panel field selection behaviour.
- Added shared panel choice resolver: exact match, number selection, first unique letters, and unique substring selection.
- Added `*` field entry to open a searchable scrollable chooser.
- Updated Task Creator class selection to use the shared chooser instead of a passive class popup.
- Applied choice behaviour to action prompts and enumerated fields across jobs, drafts, classes, assets, records, runners, state filters, queue clear targets, and confirmations.
- Added static regression coverage for the shared panel choice resolver and class-selection field behaviour.

## 0.16.9

- Document `net:allowance` as the canonical charged network allowance facility.
- Keep `net_usage:allowance` as deprecated compatibility only.
- Add `docs/ASSETS.md` and update README, class docs, and QueueManager docs for the canonical allowance naming.
- Fix queue manager panel launch from sourced shells by removing `exec` from the panel launcher. Closing the panel now returns to the caller shell instead of replacing it.
- Add static regression coverage for allowance naming/docs and panel launch lifecycle safety.

## 0.16.8

- Fix `queue user USER ...` and `queue --queue-user USER ...` root selection order by applying user selection before `_queue_init` and root capture.
- Fix panel footer layout so menu/help keys and status/message appear on separate lines.
- Remove accidental duplicate `queue()` selector collision if present.


## 0.16.7

- Hotfix `queue mgr` being misparsed as `queue user mgr`.
- Restore the real `queue()` dispatcher after an accidental user-selector rename collision.
- User queue selection now only triggers for exact forms: `--queue-user`, `--user-queue`, and `queue user USER ...`.
- `queue mgr` and `queue mgr panel` now launch the panel manager directly.


## 0.16.2

- Fix user-queue selector source safety.
- Normalize `_queue_select_user_queue` helper definition and remove accidental bare/truncated source-time calls.
- Add regression test that sourcing `queuebash.sh` defines the user selector without executing it.


## 0.16.1

- Add persistent draft state under `$QUEUEBASH_ROOT/drafts`.
- Add `queue draft list/show/create-from-job/submit/ready/abandon/state` commands.
- Add Drafts panel to the panel manager.
- Jobs panel copy action now also creates a persistent draft from the selected job.


## 0.16.0

- Add Jobs panel copy-to-task-draft workflow.
- Selected jobs can now populate Task Creator with name, command, class, priority, submit directory, runner/resources, retries/backoff, and schedule metadata where available.
- Add `y` shortcut on Jobs panel and `copy` job action.


## 0.15.9

- Add command-line user queue selection: `queue --queue-user USER ...`, `queue --user-queue USER ...`, and `queue user USER ...`.
- Add `queue-users` and `queue-user` diagnostics.
- Add Queue Users panel to the panel manager so root/operators can switch between user queue roots.
- Harden panel queue source probing so inaccessible candidate sources are skipped instead of crashing.


## 0.15.8

- Make `RUNNER=auto` resolve to `direct` when root is launching a payload as another Unix user via `RUN_USER`.
- Explicit `RUNNER=systemd` for root-to-foreign-user payloads now reports `systemd-foreign-user-not-used` rather than attempting a fragile user-bus launch.
- Job logs include `foreign_run_user_runner_policy: root-foreign-user-auto-direct ...` when this policy is active.


## 0.15.7

- Fix auto runner selection for `su`/`runuser` shells without a usable user systemd bus.
- `_queue_systemd_user_service_supported` now verifies the user bus socket and `systemctl --user show-environment`, not just `XDG_RUNTIME_DIR`.
- `RUNNER=auto` now falls back to direct when `systemd-run --user` would fail with user-bus connection errors.
- Job logs include `systemd_user_bus: ...` for diagnostics.


## 0.15.6

- Fix panel Task Creator delegated submit working directory.
- When `submit_user` is set and execution directory is blank, the submit command now runs from the target user's `$HOME` instead of inheriting root/operator's cwd.
- Preview now shows `runuser -u USER -- bash -lc 'cd "$HOME" && queue submit ...'` for this case.


## 0.15.5

- Add root/user-queue safety guard.
- If root points `QUEUEBASH_ROOT` at another user's queue, commands that may source/evaluate queue-local code are delegated to that queue owner by default.
- Safe file administration commands remain usable by root without sourcing queue-local class or asset code.
- Add `QUEUEBASH_ROOT_USER_QUEUE_MODE=refuse` to refuse instead of delegate, and `QUEUEBASH_ALLOW_ROOT_USER_QUEUE_EVAL=1` as an explicit escape hatch.


## 0.15.4

- Add user context model for classes and panel task submission.
- Class defaults can now declare `CLASS_DEFAULT_RUN_USER` and `CLASS_DEFAULT_SUBMIT_USER`.
- Job files receive `RUN_USER` / `SUBMIT_USER` defaults from class defaults.
- Runner command construction can switch payload execution user via `runuser`/`sudo` for direct runner, and uses systemd `--uid` for root/systemd execution.
- Panel Class Creator exposes default run/submit user fields.
- Panel Task Creator exposes submit user and previews `runuser -u USER -- bash -lc ...` for root/operator submissions.


## 0.15.3

- Fix Task Creator execution directory handling: remove unsupported `--chdir` submit option.
- Task Creator now previews `cd <dir> && queue submit ...` and actually runs submit with `cwd=<dir>`, so queuebash captures `PWD_AT_SUBMIT` correctly.


## 0.15.2

- Fix Task Creator submit command ordering to match `queue submit <name> [options] -- <command...>`.
- Normalize spaces and unsafe characters in Task Creator job names to underscores.
- Add Task Creator execution directory field, emitted as `--chdir <dir>`.
- Use `--backoff` for retry backoff to match queue submit usage.


## 0.15.1

- Add panel Task Creator.
- Task Creator supports job name, command, class selection, priority, schedule/not-before, retries, runner/resource overrides, preview, dry-run, and submit.
- Classes panel can send the selected class to Task Creator with `use-for-task`.


## 0.15.0

- Add panel Class Creator.
- Class Creator supports class metadata/defaults, preview, bash syntax validation, save to queue classes, and editable record-format restrictions.
- Restriction Builder can now append shared/exclusive asset records or exclusive claims directly to the Class Creator draft.


## 0.14.9

- Make `queue explain <qid>` always include an `Exception overlays` section.
- Show each overlay with ignored key, reason, creator, created timestamp, and rough age.
- Reuse one renderer for QID exception diagnostics so explain output is the primary audit surface.


## 0.14.8

- Fix panel modal windows to clear their full rectangle before drawing.
- Make command-output popups scrollable with arrow/PgUp/PgDn/Home/End and close via q/Esc/Enter.
- Force a full screen redraw after modal close so underlying panels repaint cleanly.


## 0.14.7

- Expand panel manager into an operator console.
- Add dry-run toggle, filters, queue clear actions, job actions, class/asset actions, and right-hand job detail tabs.
- Exception workflow now shows the job class policy before adding a QID overlay.


## 0.14.6

- Fix panel manager population when launched directly: it now exports `QUEUEBASH_ALLOW_NONINTERACTIVE=1` and verifies that the selected `queuebash.sh` actually defines `queue` before using it.
- Show `NO QUEUE SOURCE` and candidate source paths in-panel when no usable queue source is found.
- Panel loaders now display queue command errors instead of empty lists.


## 0.14.5

- Rename the curses UI to the full-screen panel manager.
- Replace user-facing commands/docs/header with `queue mgr panel` and `queue panel`.
- Rename the manager script to `queuemgr_panel.py`.


## 0.14.4

- Fix `queue panel` top-level dispatch.
- Make `queuemgr_panel.py` auto-discover and source adjacent `queuebash.sh` when launched directly with `python3`.
- Show queue command errors inside the panels instead of silently displaying empty lists.


## 0.14.3

- Add `queuemgr_panel.py`, a curses-backed full-screen panel manager with side-by-side panels, scrolling details, jobs/classes/assets/exceptions panels, and a restriction-builder panel.
- Expose as `queue mgr panel` and `queue panel`.
- The panel manager invokes existing `queue ...` commands so the shell core remains the source of truth.


## 0.14.2

- Improve QID exception audit logging: `exception_applied` events now include the matched exception key, reason, creator, and timestamp.
- Update bundled `OVERNIGHT_WINDOW` comment to reference QID exception overlays rather than exception classes.


## 0.14.1

- Remove `exception classes` class entirely.
- QID exception overlays are now the only supported override model for class restrictions.
- Update time-window tests/docs so overrides use `queue exception add <qid> time:window --reason ...` rather than an exception class.


## 0.14.0

- Add QID exception overlays for explicitly ignoring selected class asset restrictions.
- New commands: `queue exception add|list|clear|clear-all`.
- Class preflight skips only explicitly listed family/facility/asset keys for that job ID and logs `exception_added` / `exception_applied` events.
- `queue explain` shows exception overlays for the job.
- Exception classes were removed in 0.14.1; preferred override is now a QID overlay.


## 0.13.9

- Add `time:window` asset plugin for dispatch-time restrictions.
- Add bundled `OVERNIGHT_WINDOW` class: weekdays 18:00-05:00, weekends always allowed.
- Add bundled `exception classes` class as explicit operator override; it deliberately omits the time restriction.
- Time-window checks support test injection with `QUEUEBASH_TIME_NOW_EPOCH` or `now_epoch=` for deterministic tests.


## 0.13.8

- Add charged network-usage plugin support.
- Add asset plugin `net_usage:allowance` to block class dispatch when a charged interface/counter exceeds allowance.
- Add cap plugin `caps.d/net_usage.sh` as policy marker for per-job network usage accounting.
- Add runtime `NET_USAGE_*` accounting fields and `mark-failed` policy for jobs exceeding per-job network byte limits.


## 0.13.6

- Add zero-dependency curses-ish QueueManager class wizard using `tput` and raw arrow-key input.
- Wizard browses published asset facilities, displays helper hints, adds shared/exclusive assets and exclusive claims, previews record-format class files, and saves/validates classes.
- Expose as `queue mgr class-wizard CLASS` and `queue mgr class-builder CLASS`.


## 0.13.5

- Export job command context while sourcing class files for job preflight.
- Classes can reference `${QUEUEBASH_COMMAND_0}`, `${QUEUEBASH_COMMAND_ARG_1}`, and `${QUEUEBASH_COMMAND_ARG_1_ABSPATH}` in record-format assets.
- `REXX_RUNAWAY` now checks the actual submitted REXX script argument instead of hardcoded `waiter.rex`.


## 0.13.4

- Add `CLASS_DEFAULT_WORKING_DIR` class default, copied into `PWD_AT_SUBMIT` at submit/resubmit time.
- This allows classes such as `REXX_RUNAWAY` to force a stable execution directory even when submitted from another directory.
- QueueManager class creation supports `--default-working-dir`.
- Bundled `REXX_RUNAWAY` now defaults to `${QUEUEBASH_REXX_CWD:-/home/hc3/bashqueues}` and checks an absolute `waiter.rex` path.


## 0.13.3

- Add a compatibility adapter for older installed asset helpers that still use `token, target, params`.
- Keep the documented target-first contract for new helpers.
- Update bundled `path.sh` to target-first so `path:freespace` receives the directory as target and `min_mb=...` as a parameter.


## 0.13.2

- Fix asset preflight helper invocation so check functions receive the target as `$1`, not the full asset token.
- This corrects blockers like `runnable:interpreter` receiving `runnable:interpreter:rexx` instead of `rexx`.
- Record-format class assets now call helpers with the documented argv contract: target first, then key=value params.


## 0.13.1

- Harden asset/class refresh dispatch.
- Add unambiguous top-level `queue asset-refresh <directory>` and `queue class-refresh <directory>` aliases.
- QueueManager Assets menu now calls `queue asset-refresh` directly so plugin refresh cannot route through class refresh.
- Add regression coverage proving `queue assets refresh` and QueueManager-equivalent asset refresh do not call class refresh.


## 0.13.0

- Fix `queue assets refresh <directory>` dispatch so it calls asset plugin refresh, not class refresh.
- Repair corrupted `queue assets refresh: directory not found` error text caused by help-string injection.
- Ensure bundled `runnable:path_safe` is published by refreshed runnable asset helpers.
- Update bundled `REXX_RUNAWAY` path_safe check to use an absolute target based on `QUEUEBASH_REXX_CWD`.


## 0.12.9

- Add `queue history <job-id|name>` to show lifecycle events, exit codes, logs, resubmit links, and class/cap details for a job chain.
- Add a compact History section to `queue explain` with a pointer to full history.
- QueueManager exposes `hist <id|name>` alongside `ex <id|name>`.


## 0.12.8

- Resubmitted jobs now adopt the current class definition at resubmit time.
- `_queue_clone_job_to_pending` writes an intent-only job record and reapplies current class defaults to the new QID.
- Stale runtime fields and old class-derived fields are stripped from resubmitted jobs.


## 0.12.7

- Add/standardize `queue classes refresh <directory>` to install or replace class definitions from `.env` files.
- Class refresh validates refreshed class files and records timestamped backup metadata.
- QueueManager now exposes class refresh from the Classes menu and as `queue mgr class-refresh <directory>`.


## 0.12.6

- Add bundled `runnable:path_safe` asset facility to detect scripts with unsafe relative path assumptions.
- Add helper-published hints for `runnable:path_safe`.
- Update bundled `REXX_RUNAWAY` class to include a path-safety check for `waiter.rex`.
- Improve command discoverability for asset hints and QueueManager in help output.


## 0.12.5

- Fix class-default loader so execution/cost cap defaults are emitted with other class defaults.
- `queue classes explain` now shows `CPU_SECONDS`, `BILLING_UNIT_SECONDS`, `BILLING_CYCLES`, `BILLING_GRACE_SECONDS`, and `BILLING_POLICY` when defined.
- New jobs now receive billing/cap defaults through the same submit-time copy path as runner/log defaults.


## 0.12.4

- Add execution caps helpers for wall timeout, billing-cycle timeout, and CPU-seconds metadata.
- Add class defaults for `CLASS_DEFAULT_CPU_SECONDS`, `CLASS_DEFAULT_WALL_SECONDS`, `CLASS_DEFAULT_BILLING_CYCLES`, `CLASS_DEFAULT_BILLING_UNIT_SECONDS`, `CLASS_DEFAULT_BILLING_GRACE_SECONDS`, and `CLASS_DEFAULT_BILLING_POLICY`.
- Effective timeout now uses shortest-cap-wins between explicit `TIMEOUT` and billing-cycle derived timeout.
- `queue explain` displays an Execution caps section with cap calculation.
- QueueManager can set billing/cap defaults with `--default-billing-*` and `--default-cpu-seconds` options.


## 0.12.3

- Enforce class/job `TIMEOUT` and `KILL_AFTER` defaults in the actual payload argv builder.
- Payloads now launch through `timeout --signal=TERM --kill-after=<KILL_AFTER> <TIMEOUT> ...` when `TIMEOUT` is set.
- Timeout wrapping works under systemd and direct/setsid runners.
- Logs now include `timeout_request:` when a timeout wrapper is active.


## 0.12.2

- Fix the actual systemd-run NUL argv builder that still appended `%` to `CPU_LIMIT`, producing invalid `CPUQuota=50%%` when class defaults used `50%`.
- The systemd runner now passes `CPUQuota=$(_queue_normalize_systemd_cpu_quota "$cpu")` in the launch argv path.
- Extend regression coverage to scan the real builder for `CPUQuota=${cpu}%` and `CPUQuota=$cpu%` patterns.


## 0.12.1

- Fix systemd CPUQuota argv construction for class defaults such as `CLASS_DEFAULT_CPU_LIMIT=50%`.
- `CPUQuota=50%` is now passed as a single literal percent instead of the invalid `CPUQuota=50%%`.
- Add CPU quota normalization so both `50` and `50%` class defaults become valid systemd CPUQuota values.


## 0.12.0

- Add class default job settings copied into submitted job records.
- QueueManager class creation can set default runner, CPU/memory limits, max log size, log policy, timeout metadata, kill-after metadata, log tag, output dir, and env prefix.
- `queue class explain` shows class defaults; `queue explain` shows defaults inherited by a job.
- Add bundled `REXX_RUNAWAY` class template for controlled runaway ooRexx/REXX jobs.


## 0.11.4

- Add compatibility fallback for asset hints: helpers without `queue_asset_hints` now synthesize minimal hints from `queue_asset_facilities`.
- Fix QueueManager double-printing `No published helper hint` for unknown facilities.
- `queue asset-hints` now remains useful against older installed local helpers until they are refreshed.
- Invalid helpers are skipped for hint listing but still fail `queue assets validate`.


## 0.11.3

- Move QueueManager asset hints out of hard-coded manager logic and into asset helpers.
- Add optional `queue_asset_hints` helper contract returning TSV hint metadata.
- Add core `queue asset-hint <facility>` and `queue asset-hints` commands.
- Populate helper-published hints for existing net, git, path, sys, db, format, runnable, and crypto families when present.
- QueueManager now reads hints from helpers and falls back only to generic guidance.


## 0.11.2

- Add QueueManager asset hinting for common facilities.
- Add `queue mgr hints`, `queue mgr hint <facility>`, and `queue mgr picker`.
- Add hint display during interactive class creation.
- Extend Asset Manager menu with hint and hint-list options.
- Add regression tests for hint commands and manager-created classes using hinted parameters.


## 0.11.1

- Make bare `queuemgr` route to the new lazy-loaded `queue mgr` module.
- Rename the old standalone manager REPL to `_queue_legacy_queuemgr`.
- Add explicit `queue legacy-manager` / `queue legacy-queuemgr` entry points for the old REPL during development.
- Add regression tests for manager aliases.


## 0.11.0

- Split QueueManager into lazily sourced `queuemgr.sh`.
- Add `queue mgr`, `queue manager`, `queue qm`, and `queue queuemgr` entry points.
- Add AS/400-style text menus for jobs, classes, assets, workers, health, and trace operations.
- Add scriptable `queue mgr class-create` for record-format class creation.
- Add `docs/QUEUEMGR.md` and regression tests for lazy loading and class generation.


## 0.10.6

- Fix `_queue_next_job` stdout contamination from asset/class plugin output.
- `_queue_next_job` now captures `_queue_class_available` output and sends it to dispatch trace instead of returning it to the worker.
- This preserves the contract that `_queue_next_job` stdout is only the selected job path.
- Add regression test proving plugin success output cannot contaminate the selected job path.


## 0.10.5

- Add explicit diagnostics for pending->running move failures.
- Worker now captures `mv` stderr and traces src/dst existence, directory writability, and duplicate QID records.
- Add `queue duplicate-qids` / `queue dups` diagnostic command.
- Add a short sleep after move failure to prevent tight spin loops on filesystem collisions.


## 0.10.4

- Fix `_queue_next_job` regression from the dispatch trace patch where a malformed no-file guard caused candidates to be skipped unconditionally.
- Add candidate-level dispatch trace messages: candidate, retry/schedule/dependency/class skips, selected job, move pending->running, and claim acquisition.
- Add regression test proving traced dispatch selects and runs a pending job.


## 0.10.3

- Add optional worker dispatch tracing with `QUEUEBASH_TRACE_DISPATCH=1`.
- Add `queue dispatch-trace [N]` / `queue trace-dispatch [N]`.
- Extend pending-job explain with a claim/lock snapshot when the job is runnable.
- Helps diagnose the case where `queue explain` says runnable but `queue run` does not reach `[worker N] running ...`.


## 0.10.2

- Add pending-job dispatch diagnosis to `queue explain`.
- Explain now reports dependencies, schedule/not-before blocking, class file resolution, class/resource gate result, and captured asset/preflight output.
- Add regression tests for dependency and class asset blocker explanations.


## 0.10.1

- Remove legacy class asset string support during development.
- `CLASS_SHARED_ASSETS`, `CLASS_EXCLUSIVE_ASSETS`, and `CLASS_ASSETS` are now validation errors.
- Classes must use record APIs: `queue_class_shared_asset`, `queue_class_exclusive_asset`, and `queue_class_exclusive_claim`.
- Update default class template and bundled `GITHUB_PUBLISH` to record-only format.
- Add regression tests confirming legacy format is rejected and record format works.


## 0.10.0

- Add delimiter-safe class asset record format via `queue_class_shared_asset` and `queue_class_exclusive_asset`.
- New format preserves arbitrary `:`, `,`, `/`, `=`, and spaces because fields are Bash arguments, not packed tokens.
- Legacy `CLASS_SHARED_ASSETS` and `CLASS_EXCLUSIVE_ASSETS` remain supported.
- Update `GITHUB_PUBLISH.env` to use the new record format for `https://github.com` and comma-separated status lists.
- Add regression tests for colon/comma-heavy assets and class claims.


## 0.9.9

- Fix nested asset parser so colon-bearing targets are preserved until the first `key=value` parameter.
- Parameter values may also contain colons, e.g. `want=https://github.com`.
- Fixes tokens such as `net:http_status:https://github.com:timeout=5` and `net:tcp_endpoint:host:5432:timeout=3`.
- Add bundled external `assets.d/format.sh` plugin for JSON, XML, YAML, CSV, archive, and SQLite validation.
- Add regression tests for colon-bearing asset targets and format validators.


## 0.9.8

- Add bundled `classes/GITHUB_PUBLISH.env` for GitHub publishing jobs.
- Add bundled class installer that copies source-tree classes into `~/.queuebash/classes/` without overwriting local edits.
- Extend `queue classes` with edit, validate, replace, refresh, rollback, backups, delete/archive, undelete/unarchive, archives, explain, and expand.
- Update publish/install scripts to include bundled classes.
- Add `tests/classes_github_publish.sh` and `tests/classes_manager_lifecycle.sh`.


## 0.9.7

- Add bundled external asset plugins `assets.d/git.sh` and `assets.d/db.sh`.
- Git plugin publishes `git:repo_exists`, `git:clean_tree`, and `git:branch`.
- Database plugin publishes `db:postgres_connect`, `db:mysql_connect`, `db:sqlite_accessible`, `db:redis_connect`, and `db:mongodb_connect`.
- Make class file lookup case-friendly so `queue classes show default` resolves `DEFAULT.env`.
- Add `queue assets expand` and extend asset completion support.
- Harden asset undelete against stale empty directories at plugin paths.
- Add `tests/classes_git_db_assets.sh` and `tests/classes_default_case_lookup.sh`.


## 0.9.6

- Add `queue assets refresh`, archival `delete`, `undelete`, `archives`, and `explain`.
- Delete refuses while classes reference the asset family.
- Add `tests/classes_asset_refresh_delete_explain.sh`.


## 0.9.5

- Add transactional asset plugin replacement: `queue assets replace <family> <plugin.sh> [--force]`.
- Add rollback support: `queue assets rollback <family> [backup-file]`.
- Add backup listing: `queue assets backups [family]`.
- Replacement validates shell syntax, helper contract, and that the plugin publishes the requested family before replacing.
- Existing plugins are backed up under `~/.queuebash/assets.d/.backup/` and replacements are installed with atomic rename.
- Add `tests/classes_asset_replace_rollback.sh`.


## 0.9.4

- De-duplicate `queue assets` output by published facility name.
- Add `queue assets duplicates` / `queue assets dupes` to report duplicate facility publishers.
- Helps clean up legacy `network.sh`/`system.sh` helpers after the family-aligned rename to `net.sh`/`sys.sh`.


## 0.9.3

- Add bundled external asset plugins `assets.d/net.sh` and `assets.d/sys.sh`.
- Network plugin publishes `net:http_status`, `net:tcp_endpoint`, `net:interface_state`, and `net:interface_bandwidth`.
- System plugin publishes `sys:memory_available`, `sys:cpu_load`, `sys:cpu_cores`, `sys:iowait`, and `sys:process_count`.
- Keep helper filenames aligned with facility families: `net:* -> net.sh`, `sys:* -> sys.sh`.
- Add regression test for external standard plugin contract publication and installation.


## 0.9.2

- Move the standard `path` asset helper out of `queuebash.sh` into `assets.d/path.sh`.
- Core now only creates plugin directories, installs bundled plugins when missing, loads plugins, and validates plugin contracts.
- Bundled plugins are copied into `~/.queuebash/assets.d/` without overwriting local/site-edited plugins.
- Update publish/install scripts to include `assets.d/`.
- Add `tests/classes_external_asset_plugins.sh`.


## 0.9.1

- Enforce asset helper published-facility contracts.
- For every published `family:check`, helper must define `queue_asset_check_<family>_<check>`.
- Add `queue assets validate`.
- `queue assets show <family>` now displays published facilities and contract check results.
- Invalid helper contracts block nested asset dispatch and leave jobs pending.
- Add `tests/classes_asset_contract.sh`.


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
