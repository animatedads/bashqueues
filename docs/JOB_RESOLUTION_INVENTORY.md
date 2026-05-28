# bashqueues job-resolution inventory

Version: 0.18.20

This document inventories the job operand resolution patterns currently embedded
inside the giant `queue()` dispatcher. It is intentionally observational: this
release does not extract helpers and does not change command behaviour.

The next refactor target can use this map to design a helper such as
`_queue_resolve_job_operand TARGET MODE`, but that extraction should be a later
package with behaviour-focused tests.

## Existing primitives

Current dispatcher branches repeatedly use the following primitives:

- `_queue_find_jobs "$target"` to match an exact QID, unique QID prefix, or exact
  job name across queue states.
- `_queue_exact_name_count "$target" "${matches[@]}"` to distinguish exact job
  name group matches from ambiguous QID-prefix matches.
- `_queue_print_matches "${matches[@]}"` to explain ambiguity or invalid group
  selection.
- Direct state-bucket loops for state-scoped commands such as `unpause` and
  `undelete`.

Current matching model exposed in `queue help` remains:

- exact QID resolves to one job;
- unique QID prefix resolves to one job;
- ambiguous QID prefix is refused unless the command explicitly supports
  `--force`;
- exact job name can be a group operation for specific commands;
- job-name prefix or substring is never used for mutating commands.

## Command branch inventory

| Command branch | Resolver pattern | Classification | Prefix behaviour | Exact name behaviour | Ambiguity / force behaviour | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `deps`, `dependencies` | `_queue_find_jobs "$target"` | read-only group allowed | accepted through `_queue_find_jobs` | exact name group accepted | no explicit ambiguous-prefix guard | Shows dependency state for every match. This is read-only but currently less strict than `show/explain`. |
| `explain` | `_queue_find_jobs "$target"`; `_queue_exact_name_count` | read-only group allowed | unique prefix accepted; ambiguous prefix refused | exact name group accepted | ambiguous QID prefix refused | `--json` delegates to `_queue_status_job`, so JSON path must be inventoried with that helper separately before refactor. |
| `status job` / `_queue_status_job` | helper-owned lookup | single/helper-defined | helper-defined | helper-defined | helper-defined | `queue status job ...` does not resolve directly in `queue()`. It must be inspected separately before helper extraction. |
| `show` | `_queue_find_jobs "$target"`; `_queue_exact_name_count` | read-only group allowed | unique prefix accepted; ambiguous prefix refused | exact name group accepted | ambiguous QID prefix refused | Shows job files and logs for every exact-name match. |
| `tail`, `follow` | `_queue_find_jobs "$target"`; running-match preference | single job required with running preference | unique prefix accepted; ambiguous non-running prefix refused | exact name only accepted when it resolves to one non-running job; multiple running matches prompt selection | multiple running matches prompt; multiple non-running exact-name matches refused | This branch has special interactive selection semantics and should not be extracted blindly. |
| `stream` | `_queue_find_jobs "$target"` filtered to running | single running job required with prompt | prefix accepted when it finds running matches | exact name accepted for running matches | multiple running matches prompt selection | State-scoped and interactive; should probably use a dedicated mode. |
| `metrics`, `unit`, `metric` | `_queue_find_jobs "$target"`; `_queue_exact_name_count` | single job required | unique prefix accepted; ambiguous prefix refused | exact name group detected but then refused if more than one | ambiguous prefix refused; multiple exact-name jobs refused | Good model for single-read commands. |
| `pids`, `pid`, `ps` | `_queue_find_jobs "$target"`; `_queue_exact_name_count` | read-only group allowed | unique prefix accepted; ambiguous prefix refused | exact name group accepted | ambiguous QID prefix refused | Shows PID/process information for each match. |
| `hooks`, `hook` | `_queue_find_jobs "$target"`; `_queue_exact_name_count` | read-only group allowed | unique prefix accepted; ambiguous prefix refused | exact name group accepted | ambiguous QID prefix refused | Shows hook arrays for each match. |
| `onsuccess`, `on-success`, `onok`, `onfailure`, `on-failure`, `onfail` | `_queue_find_jobs "$target"`; `_queue_exact_name_count` | mutating group allowed by exact name | unique prefix accepted; ambiguous prefix refused | exact name group accepted | ambiguous QID prefix refused; no `--force` escape | Updates hook arrays for all exact-name matches. |
| `priority`, `prio`, `dynamic-prio` | `_queue_find_jobs "$target"`; `_queue_exact_name_count` | mutating group allowed by exact name | unique prefix accepted; ambiguous prefix refused unless `--force` | exact name group accepted | ambiguous prefix can be overridden by `--force` | `--force` permits otherwise ambiguous non-name match handling; preserve carefully. |
| `cancel`, `kill` | `_queue_find_jobs "$target"`; `_queue_exact_name_count` | mutating strict with force | unique prefix accepted; ambiguous prefix refused unless `--force` | exact name group accepted | ambiguous prefix can be overridden by `--force` | Cancels/moves records and may signal running jobs; needs high-value regression coverage. |
| `pause`, `hold`, `delete`, `del`, `rm`, `remove` | `_queue_find_jobs "$target"`; `_queue_exact_name_count` | mutating group allowed by exact name with state rules | unique prefix accepted; ambiguous prefix refused unless `--force` | exact name group accepted | ambiguous prefix can be overridden by `--force` | Refuses running jobs without `--force`; pause refuses non-pending without `--force`. |
| `unpause`, `resume`, `release` | direct loop over `paused/*.job`; QID/name/prefix match | state-scoped mutating group allowed by exact name | unique prefix accepted; ambiguous prefix refused | exact name group accepted | ambiguous prefix refused; no `--force` escape | Uses direct bucket scan rather than `_queue_find_jobs`. A generic helper must support state-scoped searches. |
| `undelete`, `undel`, `restore` | direct loop over `deleted/*.job`; QID/name/prefix match | state-scoped mutating group allowed by exact name with force | unique prefix accepted; ambiguous prefix refused unless `--force` | exact name group accepted | ambiguous prefix can be overridden by `--force` | Calls `_queue_restore_print_non_deleted_matches` when not found. Preserve that diagnostic. |
| `resubmit`, `retry` | `_queue_find_jobs "$target"`; filter to failed/interrupted/pol_blocked | state-filtered mutating clone | unique prefix accepted; ambiguous prefix refused unless `--force` | exact name group accepted after state filter | ambiguous prefix can be overridden by `--force`; non-resubmittable matches reported separately | Uses both `all_matches` and filtered `matches`; helper must not lose the “found but wrong state” diagnostic. |

## Proposed future resolver modes

A later refactor can probably reduce duplicate code with modes like:

- `read_group`: allow exact-name groups, refuse ambiguous QID prefixes.
- `read_single`: require one resolved job; refuse exact-name groups and ambiguous
  QID prefixes.
- `running_single_prompt`: prefer running jobs and prompt when multiple running
  jobs match.
- `mutating_group`: allow exact-name groups, refuse ambiguous prefixes unless the
  branch has `--force`.
- `state_scoped_group`: search only one state bucket, allowing exact-name groups.
- `state_filtered_clone`: keep both all matches and filtered matches for commands
  like `resubmit`.

The initial helper should return data rather than performing command action. A
simple shell-global contract would be acceptable for the first extraction:

```bash
QUEUE_RESOLVE_KIND=single|group|missing|ambiguous|wrong_state
QUEUE_RESOLVE_MATCHES=( ... )
QUEUE_RESOLVE_ALL_MATCHES=( ... )
QUEUE_RESOLVE_REASON=...
QUEUE_RESOLVE_EXACT_NAME_COUNT=N
```

## Refactor cautions

Do not collapse these semantics accidentally:

- `tail` and `stream` have interactive running-job selection.
- `unpause` and `undelete` scan state-specific buckets directly.
- `resubmit` needs separate “all matches” versus “eligible matches” diagnostics.
- `priority`, `cancel`, `pause/delete`, `undelete`, and `resubmit` each interpret
  `--force` differently enough to require explicit tests.
- JSON `explain/status` paths delegate to `_queue_status_job` and may not use the
  same direct branch logic.

## Suggested regression matrix for 0.18.21

Before extracting helpers, create jobs covering:

- one exact QID;
- two jobs sharing a QID prefix;
- two jobs with the same exact job name;
- one running job;
- one paused job;
- one deleted job;
- one failed/interrupted/pol_blocked job.

Then compare before/after output/exit status for:

- `queue show <qid-prefix>`;
- `queue explain <qid-prefix>`;
- `queue tail <qid-prefix> --no-follow`;
- `queue pids <qid-prefix>`;
- `queue hooks <exact-name>`;
- `queue priority <exact-name> 20 --dryrun`;
- `queue pause <qid-prefix> --dryrun`;
- `queue delete <qid-prefix> --dryrun`;
- `queue unpause <qid-prefix> --dryrun`;
- `queue undelete <qid-prefix> pending --dryrun`;
- `queue resubmit <qid-prefix> --dryrun`.
