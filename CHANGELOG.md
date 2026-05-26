
## 0.17.69 - Code signing audit and installer hardening

- Added `queue code audit` / `queue code components` / `queue code inventory` to display every signed component, category, signer fingerprint, signature path, and verification status for audit.
- Added JSON audit output for programmatic compliance checks.
- Fixed installer code-signing policy generation so trusted public key SHA256 values are always written inside `QUEUEBASH_CODE_TRUSTED_PUBLIC_KEY_SHA256S="..."`.
- Changed the system installer so `publish_to_github.sh` is not copied into `/usr/local/share/bashqueues`, and stale installed copies are removed.
- Confirmed `assets.d/net_usage.sh` remains absent; `net:allowance` remains canonical in `assets.d/net.sh`.

## 0.17.68 - Code and plugin signing

- Added code/plugin signature manifest support under `.queuebash-signatures/`.
- Added `queue code sign`, `queue code verify`, `queue code trust`, and `queue plugins verify`.
- Added overrideable policy controls: `QUEUEBASH_CODE_SIGNATURE_MODE`, `QUEUEBASH_PLUGIN_SIGNATURE_MODE`, and trusted public key SHA256 lists.
- Asset, cap, and reporter plugin sourcing now consults code/plugin signature policy before executing plugin code.
- Added installer integration to verify installed code and, when a root key is available, sign the installed tree and trust the root public key.
- Added code-signing documentation and regression tests.
- Confirmed `assets.d/net_usage.sh` remains absent; `net:allowance` remains canonical in `assets.d/net.sh`.

## 0.17.67 - Mandatory policy assets

- Added `CLASS_POLICY_MANDATORY_ASSETS` for non-bypassable asset checks required by class-statement policy.
- Mandatory policy assets are merged across active class-statement policies and evaluated after class assets without consulting queue exception overlays.
- Added tests for mandatory policy asset pass/block behaviour.

## 0.17.67 - Class library and cron selector

- Added common job class library: ALERT_NOTIFICATION, BACKUP_JOB, BATCH_PROCESSING, DB_MIGRATION, DEADLINE_CRITICAL, DEPLOY_RELEASE, FILE_TRANSFER, INTERACTIVE_PRIORITY, LOG_HOUSEKEEPING, REPORT_GENERATION, and SENSITIVE_DATA_EXPORT.
- Added optional cron class selector plugin: bin/bashqueues-cron-class-selector.py.
- The cron ticker now asks the selector for a class when no #class/BASHQUEUES_CLASS directive is present, but still falls back to the generated strict safe cron class if the selector is absent, uncertain, or below the configured cron policy minimum.
- Added static and smoke coverage for the class library and selector.
- Confirmed assets.d/net_usage.sh remains absent; net:allowance remains canonical in assets.d/net.sh.

## 0.17.63 - queue dev execution flow graph

## 0.17.65 - Microsoft reporting plugin

- Added `reporters.d/ms.sh` for explicit opt-in Microsoft Notify event reporting.
- Added reporting policy examples for Fabric/Sentinel/Log Analytics-style ingestion endpoints.
- Added static and smoke coverage for Microsoft reporter discovery and dispatch.
- Kept `assets.d/net_usage.sh` absent; `net:allowance` remains canonical in `assets.d/net.sh`.

- Added `queue dev flow` / `queue dev graph` / `queue dev paths` for static function-call and branch-path analysis.
- Flow output is JSON-first and reports function nodes, call edges, branch nodes, terminal return/exit nodes, and per-function callees.
- Heredoc bodies are masked during flow analysis so embedded Python or other languages do not create false Bash branch noise.
- Added regression tests for execution-flow JSON and heredoc masking.

## 0.17.64 - Reporting plugin event observer

- Added queue reporting plugins under `reporters.d/` with metadata-only discovery.
- Added `queue reporters list [--json]`.
- Added bundled SNMP INFORM reporter, disabled unless explicitly enabled/configured by reporting policy.
- Added reporting policy template under `policies.d/reporting/default.env`.
- Kept `assets.d/net_usage.sh` absent; `net:allowance` remains canonical in `assets.d/net.sh`.


## 0.17.62 - queue dev hardening

- Added `flock`-based serialization for mutating `queue dev` operations: `patch`, `comment`, `strip`, and `rollback`.
- Made Bash `queue dev patch` use verified backups, syntax-checked temp files, and atomic `mv` replacement.
- Added bounded backup pruning via `QUEUEBASH_DEV_MAX_BACKUPS` with a default of 20 backups per target file.
- Hardened Python `queuemgr_panel.py --dev patch` with `fcntl.flock`, verified backups, AST validation, atomic `os.replace`, and backup pruning.
- Added static and smoke tests for dev locking, atomic replacement, and backup lifecycle behaviour.

## 0.17.61 - queue dev symbol analysis

- Added `queue dev symbols` for Bash symbol analysis over files or loaded functions.
- Reports function ranges, variable definitions/references, constants, string literals, and scope classification in JSON.
- Added `python3 queuemgr_panel.py --dev symbols [TARGET]` using Python AST analysis.
- Added static and smoke tests for Bash/Python symbol introspection.

## 0.17.58 - VM and container asset suite


## 0.17.60 - queue dev memory/context/rollback

- Added `queue dev comment` for function-level AI patch comments and optional changelog sync.
- Added `queue dev diff` for function-scoped comparison against recent semantic patch backups.
- Added `queue dev strip` / `queue dev rollback` for function-scoped restoration from patch backups.
- Added `queuemgr_panel.py --dev` locate/extract/functions/patch interface using Python inspect/AST.
- Added static and smoke tests for the developer metaprogramming lifecycle.

## 0.17.59 - Developer metaprogramming helpers

- Added `queue dev` introspection commands for dogfood/AI-assisted maintenance.
- Added `queue dev locate FUNCTION --json` using Bash extdebug metadata.
- Added `queue dev extract FUNCTION --json` using Bash function reconstruction.
- Added `queue dev functions --json [prefix]` and `queue dev scope --json`.
- Added `queue dev patch --file FILE --function FUNCTION --source SOURCE --json`, with backup and `bash -n` safety validation before replacement.
- Added developer introspection static/smoke tests.


- Added Docker/Podman asset plugin: `assets.d/docker.sh`.
- Added Kubernetes asset plugin: `assets.d/k8s.sh`.
- Added libvirt/KVM asset plugin: `assets.d/vm.sh`.
- Added LXC/LXD asset plugin: `assets.d/lxc.sh`.
- Added VMware vSphere/govc asset plugin: `assets.d/vsphere.sh`.
- Added Vagrant asset plugin: `assets.d/vagrant.sh`.
- Added static coverage tests for all VM/container asset families.
- Confirmed asset discovery remains metadata-only for `queue assets list --json`; the new plugins publish facilities/hints without executing probes.
- Confirmed `assets.d/net_usage.sh` remains absent.

## 0.17.57 - Microsoft enterprise asset suite

- Added first-class Microsoft-domain asset plugins: msad, entra, msfs, mscloud, exchange, teams, msdns, msca, winrm, azure, and vault.
- Side-effecting Microsoft probes are explicit opt-in: Teams webhook posting requires allow_post=1 and Exchange test mail requires allow_send=1.
- Added Microsoft asset discovery/static checks so `queue assets list --json` exposes the new facilities without executing network probes.
- Added MSDOMAIN class template documentation for AD/Entra/Graph/Azure/WinRM-style workloads.

## 0.17.55 - Programmatic JSON surfaces for dogfood automation

## 0.17.56 - Asset listing noninteractive guard

- Hardened `queue assets list` and `queue assets list --json` so discovery prefilters files before sourcing them.
- Non-asset helper scripts under a damaged or hand-edited `assets.d` are now reported as `not_asset_plugin` and are not sourced.
- Asset discovery now runs with stdin detached and `QUEUEBASH_ASSET_DISCOVERY=1` to prevent operator prompts during metadata listing.
- Added static and smoke tests for noninteractive asset facility listing.


- Added `--json` output for `queue submit`, returning the submitted QID, state, class, command line, job file, queue root, and priority without parsing human text.
- Added `queue list --json` for machine-readable job inventory across queue states.
- Added JSON inventory output for `queue classes list --json`, `queue assets list --json`, and `queue caps list --json`.
- Added JSON audit output for `queue authorisation list --json` and `queue keys list --json`.
- Added `queue explain <job> --json` as a compact machine-readable alias over the status object, while retaining the full human forensic explain by default.
- Added `tests/json_programmatic_surfaces_static.sh` and `tests/json_programmatic_surfaces_smoke.sh` for the new JSON operator/automation surfaces.

## 0.17.54 - Canonical pol_blocked state and compact job status

- Standardised the policy-block terminal directory/state on `pol_blocked`; `pol_block` is no longer the filesystem target.
- `queue authorise` now finds jobs in `pol_blocked`, while the old `policy_blocked` directory remains a hidden compatibility fallback for old queue roots.
- Removed the old policy-block state spellings from normal user-facing state lists, completions, and help text.
- Added `queue status <qid-or-exact-job-name> [--json] [--tail N]` for compact automated processing of QID, submission line, command, state, class, PID data, timing, return code, job file, log path, and log tail.
- Detached workers started by `queue run --detach` now write to per-worker logs under `logs/` instead of inheriting the launcher stdout/stderr.
- Added `tests/status_job_static.sh` and `tests/status_job_smoke.sh`.

## 0.17.53 - Merged class-statement policy gate

- The execution policy gate now loads and merges every discovered `class-statement` policy returned by `queue policy list`, instead of only sourcing the active/default statement.
- Cumulative class-statement controls such as `CLASS_POLICY_BLOCK_CLASS_NAMES`, command block lists, weak-policy lists, selectable sandbox/seccomp lists, and authorisation requirements are merged so one policy file cannot erase another file's emergency block.
- `queue policy explain` with no arguments now shows the effective merged class-statement policy, including the files loaded and the effective block/authorisation values.
- Added `tests/class_statement_merge_static.sh`, including a runtime regression where a cron-generated class blocked from `policyblock-test.env` is moved to `pol_blocked` without running the payload.

## 0.17.52 - Panel tab wrapping and cron health commands

- Queue Manager top-level tabs now wrap over two rows, keeping all hotkey-labelled views visible on normal terminals as the UI grows.
- Added `queue cron status` to show ticker/spool/state paths, user/system crontab counts, latest dispatch marker, and relevant systemd unit states.
- Added `queue cron test` as a status-plus-dry-run tick check for cron bridge diagnostics.
- Converted stale static-test version pins to version-shape assertions so routine version bumps stop causing noisy test churn.
- Reworked `sandbox_unset_submit_static.sh` to use line-number analysis instead of broad awk pattern ranges.

## 0.17.51 - Cron class directives and test maintenance

- Added local crontab class directives using `#class CLASS`, so operators can route a specific cron entry to an existing bashqueues class without hand-editing generated class hashes.
- Added `queue cron class [USER] ENTRY CLASS|--clear` to insert, replace, or clear the `#class` directive immediately above a cron entry.
- `queue cron explain` now reports explicit `#class` and `#authorisation` directives, the generated fallback class, and the resulting submit command.
- The cron ticker now honours `#class`, `#authorisation`, and `#authorization` comment directives as local, readable alternatives to `BASHQUEUES_CLASS=` metadata.
- Fixed `queue explain` security-guidance log scanning so compressed/binary log tails do not emit `ignored null byte in input` warnings.
- Refreshed stale static-test version pins and updated the Global Resources panel function assertion after the panel action rename.

## 0.17.49 - Cron explain and selected-user cron list scoping

- Added `queue cron explain [user|--all|system]` to translate bashqueues crontab entries into readable schedule, command, generated class, command hash, and queue submission details.
- `@reboot` is now called out explicitly as unsupported in cron explain output because bashqueues cron is timer/queue based.
- `queue --queue-user USER cron list` and `queue user USER cron list` now scope the user crontab section to that selected user unless `--all` is requested.
- Added static and smoke coverage for cron explain output and selected-user list scoping.

## 0.17.48 - Cron edit spool permission fix

- Fixed `queue cron edit` so it no longer prints a successful update after failing to write the crontab file.
- Normal users may only edit their own bashqueues crontab; root may edit another user's crontab.
- `queue cron edit` now reports actionable permission hints when `/var/spool/bashqueues_cron` is not writable.
- The system installer now creates/fixes `/var/spool/bashqueues_cron` as mode `1777`, so users can create their own bashqueues crontab files without being able to replace another user's file.

## 0.17.47 - Installer noninteractive queue sourcing fix

- Fixed `install-system.sh` so its dogfood install queue sets `QUEUEBASH_ALLOW_NONINTERACTIVE=1` before sourcing `queuebash.sh`.
- Fixed the generated `/usr/local/bin/queue` wrapper so non-interactive `queue ...` commands source the installed shell library correctly.
- Added regression coverage for both paths.

## 0.17.46 - System installer with optional cron and root signing key setup

- Added `install-system.sh`, a root-only system installer that dogfoods bashqueues by running its privileged installation steps through an isolated temporary queue.
- Installs the shared system copy, `/etc/profile.d/bashqueues.sh`, a non-interactive `/usr/local/bin/queue` wrapper, shared policies under `/etc/bashqueues/policies.d`, and bundled support files without overwriting site policy edits.
- Added `--with-cron` to install and enable the cron bridge timer without replacing `/usr/bin/crontab`.
- Added root authorisation key setup: if root has no signing key, the installer generates one and installs the root public key into `/etc/bashqueues/policies.d/class-statement/default.env` unless already configured.
- Added `docs/SYSTEM_INSTALL.md` and static coverage for the system installer.

## 0.17.45 - Panel policy/global editors and daemon worker guard

- Added `queue daemon` as a control-thread alias for `queue sentinel --min-workers 1`; it performs cheap sentinel checks and whirls up at least one detached payload worker when a due, dependency-ready pending job exists.
- Added `--min-workers N` to `queue sentinel` / `queue scheduler`.
- Added friendly policy explain/show shorthand: `queue policy explain`, `queue policy show policyblock-test`, and `queue policy explain class-statement policyblock-test`.
- Queue Manager tabs are reordered around common day-to-day work and now include an interactive Policies panel.
- Queue Manager Global Resources panel now has an action menu for claims, cleanup, dry-run cleanup, and force-release by claim/QID.
- Fixed typed command entry so the first printable character is not swallowed when it opens the command prompt.
- Added regression/static tests for these fixes.

## 0.17.44 - Root-aware policy editor and explicit weak-policy tracking

- `queue policies edit` is now root-aware: root edits shared/site policy files under `/etc/bashqueues/policies.d` by default, while normal users edit queue-local policies.
- Added `--shared` / `--personal` scope flags for `queue policies edit`, `queue policies create`, and `queue policies path`.
- Added `queue policies path KIND NAME` to show the exact target path before editing.
- Submit now records whether sandbox/seccomp were explicitly selected. A plain default `off` no longer requires a reason merely because the active policy treats explicit `--sandbox off` as weak.
- Added regression tests for root-aware policy editing and implicit-default submit behaviour.

## 0.17.43 - Noninteractive submit default reason for policy-aware selftests

- Added `QUEUEBASH_SUBMIT_REASON_DEFAULT` as an audited default reason for noninteractive scripts that call `queue submit` without an explicit `--reason`.
- The value is only used as reason text; it does not satisfy authorisation-only policy modes and does not bypass signed command authorisation requirements.
- Updated `publish_to_github.sh` and `tests/selftest.sh` so cloned temporary selftest queues do not fail under a site policy that requires reasons for weak/default sandbox choices.
- Added regression tests for default-reason recording and authorisation-only refusal.

## 0.17.51 - Policy re-evaluate, expiring exceptions, and queue backup

- Added `queue reevaluate` to recheck existing `pol_blocked` jobs after policy changes or on-file authorisations.
- Added `--expires` / `--expires-at` to `queue exception add`; expired asset exceptions are ignored but retained for audit.
- Added `queue backup create` and `queue backup restore` for filesystem queue snapshots.
- Added docs for pol_blocked re-evaluation, time-limited exceptions, and queue backup/restore.

## 0.17.41 - Queue sentinel control-plane loop

- Added `queue sentinel` / `queue scheduler` as the cheap daemon-mode control thread.
- The sentinel does not launch payloads and does not run normal asset preflight.
- It removes dead detached-worker PID files, detects definitely stale running jobs, applies the early policy gate to pending jobs, and evaluates only `deadline:monitor` / `deadline:panic` control-plane assets for due dependency-ready jobs.
- This lets deadline escalation and bounded extra-worker creation happen even when all payload workers are busy.
- Added regression tests for sentinel policy blocking and deadline escalation.

## 0.17.40 - Deadline extra worker escalation

- `deadline:monitor` and `deadline:panic` can now start a bounded extra detached worker after priority escalation when explicitly enabled by class policy or asset parameters.
- Added `CLASS_DEADLINE_ALLOW_EXTRA_WORKER`, `CLASS_DEADLINE_EXTRA_WORKER_SLACK`, and `CLASS_DEADLINE_MAX_EXTRA_WORKERS`.
- Extra workers are started only when the recorded worker set appears saturated, and are capped per queue to avoid runaway worker creation.
- Deadline worker escalation is recorded in the job file and emitted as an asset check message for auditability.

## 0.17.38 - Central SNMP map aliases


## 0.17.39

- Added `assets.d/deadline.sh` dynamic deadline asset.
- Added `deadline:monitor` for deterministic slack calculation and priority escalation.
- Added `deadline:panic` for class-declared fallback asset exceptions once the point of no return is crossed.
- Added `docs/DEADLINE_ASSET.md`.

- Added central SNMP map support for `assets.d/snmp.sh` so class files can reference aliases such as `SAN_CPU` rather than opaque numeric OIDs.
- SNMP maps are loaded from `/etc/bashqueues/snmp-map.env`, `/etc/bashqueues/snmp.d/default.env`, queue-local `policies.d/snmp-map/default.env`, and the bundled fallback map.
- Explicit class parameters override map defaults, allowing one-off thresholds without editing the central map.
- Added `policies.d/snmp-map/default.env` and regression coverage for map alias resolution.

## 0.17.37 - SNMP asset and NMS notification helper

- Added `assets.d/snmp.sh` with `snmp:int_below`, `snmp:int_above`, `snmp:truth_ok`, and `snmp:string_match` facilities.
- SNMP numeric facilities use `snmpget -Oqv`, validate integer SMI values before shell arithmetic, and fail closed on missing tools, errors, or unexpected types.
- Added `bin/queue_snmp_inform.sh` for strictly typed SNMP INFORM notifications to a site NMS.
- Added `docs/SNMP_INTEGRATION.md` and regression tests.

## 0.17.36 - Queue Manager Delete clears inactive editor fields

- Queue Manager Task Creator and Class Creator now support Delete on the selected inactive field.
- Delete clears optional fields without opening an edit prompt.
- Resettable fields return to safe defaults, for example priority=10, retries=0, class default runner=auto.
- Security exception fields can be cleared from the Task Creator by selecting the field and pressing Delete.

## 0.17.51 - pol_blocked resubmission and exemption audit model


## 0.17.51 - policy command blocks and exemption visibility

- Added shared/admin class-policy command blocks for zero-hour response:
  - `CLASS_POLICY_BLOCK_COMMAND_HASHES`
  - `CLASS_POLICY_BLOCK_COMMAND_WORDS`
  - `CLASS_POLICY_BLOCK_COMMAND_PATTERNS`
  - `CLASS_POLICY_BLOCK_COMMAND_REQUIRE`
- Worker policy gate now blocks matching commands before claims, preflight, or payload launch.
- Jobs that run because of a standing grant, reason, or valid authorisation now log a `security_exemption` event.
- `queue explain` now shows exemption type/action/detail/authorisation for completed jobs, including `run_with_authorisation`.
- Queue Manager Task Creator F10/Enter now edits security reason, authorisation code, and no-exemption fields.
- Added docs for emergency policy command blocks.

- Renamed the new policy-block terminal state to `pol_blocked` for screen-friendly Queue Manager display, while retaining legacy `pol_blocked` directory compatibility for existing jobs.
- `queue resubmit` now accepts jobs in `pol_blocked` / legacy `pol_blocked` as well as `failed` and `interrupted`.
- Resubmitted jobs preserve security authorisation/exemption fields so an authorised policy-blocked command can be resubmitted after approval.
- Submit and worker policy gates now look for any valid on-file command-bound authorisation for the same user and exact command hash; the user does not have to paste the code again until it expires.
- Added explicit exemption audit categories:
  - `policy-approved` for standing policy/user grants,
  - `description-approved` for policy-permitted reason text,
  - `code-approved` for command-bound authorisation codes.
- Queue Manager Task Creator now exposes security reason, authorisation code, and “no security exemption requested” controls.

## 0.17.33 - Policy-block test class policy

- Added `policies.d/class-statement/policyblock-test.env`, a validation-only shared policy statement that policy-blocks jobs using class name `POLICYBLOCKED`.
- Added `classes/POLICYBLOCKED.env` as a harmless test class for validating the `pol_blocked` terminal state.
- Worker policy gate now supports `CLASS_POLICY_BLOCK_CLASS_NAMES` and reports the blocked class in the policy-block reason.
- Added docs and regression tests for the policy-block test hook.

## 0.17.32 - Policy-blocked terminal state

- Added `pol_blocked` as a terminal queue state for jobs that are contrary to the active shared/admin class-policy statement at execution time and do not have a valid standing grant or command-bound authorisation.
- Worker-side policy checking now happens before class claims, asset preflight, dynamic preflight, global claims, or payload launch.
- Policy-blocked jobs are not retried; they must be resubmitted after a valid authorisation exists for the exact command.
- Valid command-bound authorisations can be reused for unlimited resubmissions of the same command until expiry.
- Added regression coverage for policy-blocked state handling and authorisation reuse.

## 0.17.31 - Authorisation keygen selected-user key-root fix

- Fixed `queue keygen` while operating on a selected foreign queue so it creates the operator/signer key under the operator identity root, not the selected target queue root.
- Reinforced authorisation signing key lookup so root authorising hc3 jobs uses `/root/.queuebash/keys`, while authorisation records and job stamps remain in `/home/hc3/.queuebash`.
- Added regression coverage for keygen/signing separation in selected-user mode.

## 0.17.30 - Authorisation signer key-root fix

- Fixed signed authorisation lookup when an operator/root shell is switched to another user's queue with `queue --queue-user USER`.
- Authorisation files and job stamping still target the selected queue root.
- Signing private keys now belong to the authorising admin/signer identity, not the selected target queue.
- For example, root authorising a job in hc3's queue signs with `/root/.queuebash/keys/private/root.ed25519.pem`, not `/home/hc3/.queuebash/keys/private/root.ed25519.pem`.
- Added signer key-root diagnostics to `queue authorisation policy`.
- Added regression tests for selected-queue signing.

## 0.17.51 - Per-user class-policy standing grants


## 0.17.29 - Authorisation stamping transaction guard

- Hardened `queue authorise QID` so it builds an authorisation candidate, validates it against the active class-policy signature rules, and only then publishes the authorisation file and stamps the job.
- A policy-required signature failure now refuses the operation with `queue authorise: policy requires a valid signature for admin ...` and leaves the job file untouched.
- Hardened `queue authorisation generate` with the same candidate validation path.
- Added regression coverage for refusing invalid signed-policy candidates before stamping jobs.

- Added shared class-policy per-user grants for standing delegated security exceptions.
- The active class policy can now allow specific users to use narrow exception values without a per-command authorisation, for example permitting web administrators to add ports 80, 1080, and 8080 while requiring DBAs to obtain an authorisation for the same ports.
- Added command-specific grant variables keyed by full command hash or the first 16 hex characters.
- Added regression tests for user-specific port grants.

## 0.17.27 - Authorisation trust-list generation hardening

- Added `queue authorisation policy` to show the active class policy statement path, signature mode, and policy-declared trusted authorisation signers.
- Hardened `queue authorisation generate` and `queue authorise QID`: if the active class policy declares a trusted public key for an admin, a matching private-key signature is now mandatory at creation time rather than allowing an unsigned record that later lists as invalid.
- When a policy trust list exists, undeclared admins are now rejected at authorisation creation time instead of creating unusable authorisation files.
- Added regression coverage for policy trust-list diagnostics and creation-time rejection of unsigned/untrusted authorisations.

## 0.17.26 - Authorisation readability and signature policy enforcement

- Fixed root-created authorisation records in a selected user's queue so they are published read-only/readable (`0444` fallback `0644`) instead of inheriting root-only permissions such as `0640 root:root`.
- `queue authorisation list` now distinguishes unreadable records as `invalid-unreadable` instead of hiding the underlying permission problem behind a generic source failure.
- Tightened `CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED=if-trusted-key`: once a class policy declares trusted authorisation public keys, an unsigned authorisation by a declared signer is `invalid-missing-signature`, and an authorisation by an undeclared signer is `invalid-untrusted-admin`.
- Added regression coverage for authorisation file publication permissions and policy-declared signature enforcement.

## 0.17.51 - Authorisation list invalid-source rendering fix

- Fixed `queue authorisation list` rendering for malformed/tampered authorisation files.
- Invalid source files now display a clean basename/code with `status=invalid-source` and `integrity=invalid-source` instead of leaking literal shell `$'\t'` escape text into the list output.
- Added regression coverage for mixed valid and invalid authorisation records.

## 0.17.24 - Selected-user authorisation target fix

- Fixed `queue authorise QID` when root/operator authorises a job inside a selected user's queue.
- Existing-job authorisations now default the authorised target user from `QUEUEBASH_SELECTED_USER` / queue root owner before falling back to the job `SUBMIT_USER` field.
- This preserves the intended split: `admin=root`, `user=<queue owner>` for root approvals in another user's queue.
- Added a smoke regression proving a root-submitted job in an `hc3` selected queue receives `AUTHORISATION_USER=hc3`, not `root`.

## 0.17.23 - Signed policy authorisations and key generation

- Added `queue keygen authorisation NAME` for Ed25519 authorisation signing keypairs.
- Added `queue keys list` and `queue keys show NAME` for queue-local public key inspection.
- Class policy statements can now declare trusted authorisation public keys per admin/user via `CLASS_POLICY_AUTHORISATION_SIGNER_<NAME>_PUBLIC_KEY_*`.
- Added `CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED` with `off`, `if-trusted-key`, and `always` modes.
- Authorisation records can now carry an Ed25519 signature over queue root, authorising admin, authorised user, exact command hash, expiry, and reason hash.
- `queue authorisation list` / `show` now report signed integrity status such as `valid-signed`, `valid-unsigned`, `invalid-payload-hash`, or `invalid-signature`.

## 0.17.22 - Job authorisation stamping and validity checks

- Added `queue authorise <qid>` / `queue authorize <qid>` for stamping a queue-local authorisation directly onto an existing job record.
- `queue authorise` appends to the existing `.job` file, preserving the file owner/group instead of rewriting the job through a root-owned temporary file.
- Added Queue Manager job action and typed job command support for authorising the selected job.
- `queue authorisation list` now reports authorisation file integrity as `valid` or an invalid reason such as `invalid-command-hash`.
- `queue authorisation show CODE` now includes `AUTHORISATION_FILE_INTEGRITY=...`.
- Submit and cron authorisation checks now reject tampered authorisation files whose stored command array no longer matches the stored command hash.

## 0.17.21 - Class policy statement and command-bound authorisations

- Added a central class policy statement under `policies.d/class-statement/default.env`.
- `queue submit` now enforces policy-governed justification for security exception overlays.
- Added `--reason TEXT` and `--authorisation CODE` support for `--sandbox-override`, `--seccomp-allow`, `--drop-cap`, and `--add-port`.
- Added queue-local short authorisations via `queue generate authorisation` / `queue authorisation generate`.
- Authorisation codes are case-insensitive, no more than five letters/numbers, queue specific, and bound to the exact command hash.
- The cron bridge now checks requested `BASHQUEUES_CLASS` against the crontab minimum security floor; weak explicit classes require a matching `BASHQUEUES_AUTHORISATION`, otherwise cron falls back to the generated safe class.
- Added docs and regression tests for class policy statements, reason enforcement, authorisations, and cron minimum handling.

## 0.17.20 - Security exception guidance in explain

- Added a `Security exception guidance` section to `queue explain`.
- Runtime security failures now suggest the narrowest relevant submit-time exception, such as `--drop-cap no-network-tools`, `--drop-cap no-network-sockets`, `--drop-cap only-local-sockets`, `--drop-cap no-spawn-shell`, or `--add-port PORT`.
- Sandbox network failures now suggest `--sandbox-override off` when the command/log indicates networking was blocked by `network-none` or `strict`.
- Seccomp-looking failures now suggest a narrow `--seccomp-allow` starting point, with `@debug` only when that is the likely blocked syscall group.
- Pending class/asset preflight failures now show the exact `queue exception add <qid> <asset> --reason ...` command for a job-local exception overlay.
- Pending `queue explain` now displays effective execution caps after exception overlays, matching worker launch behaviour.
- Added static and smoke regression tests for security exception guidance.

## 0.17.19 - Exception overlay explain visibility

- Fixed `queue explain` so submit-time security exceptions are visible in the `Exception overlays` section.
- `--sandbox-override`, `--seccomp-allow`, `--drop-cap`, and `--add-port` are now reported from the job record, not only from already-sourced shell variables.
- Added a static regression test for security exception overlay visibility.

## 0.17.18 - Queue Manager class edit safety

- Fixed Queue Manager class edit action so it no longer calls interactive `queue classes edit` through `qrun()`.
- Class edit from the panel now loads the selected class into Class Creator for noninteractive preview/validate/save editing.
- Fixed Python 3.13 timeout handling in `qrun()` so `TimeoutExpired` bytes output is decoded before building diagnostics.

## 0.17.17 - Class Creator seccomp policy chooser

- Added seccomp policy selection to the Queue Manager Class Creator.
- Class Creator now exposes both default sandbox and default seccomp profiles.
- Added F2 commands for `classcreator seccomp NAME` and `classcreator seccomp-allow GROUPS`.
- Seccomp chooser reads policy names from `queue policies list seccomp`, matching sandbox policy behaviour.

## 0.17.16 - Security policy snapshots and editor commands

- Security policies are now snapshotted into each job record at submit time after class defaults are applied.
- The worker prefers the per-QID snapshot for sandbox/seccomp launch properties, so later policy edits do not silently change already-submitted jobs.
- `queue explain` shows the policy snapshot time, policy origin, and policy hash.
- Shared/admin policies in `/etc/bashqueues/policies.d` now take precedence over queue-root personal policies with the same name.
- Added policy editor commands: `queue policies edit KIND NAME` and `queue policies create KIND NAME [--from EXISTING]`.
- Added `queue-default` sandbox/seccomp policies as recommended safe defaults for ordinary queue behaviour.


## 0.17.15

- Moved sandbox and seccomp launch profiles into policy files under `policies.d/`.
- Added bundled sandbox policies: `off`, `network-none`, `restrict-egress`, `strict`.
- Added bundled seccomp policies: `off`, `docker-default`, `strict`.
- Added `queue policies list` and `queue policies show sandbox|seccomp NAME`.
- Queue roots now install policy files under `$QUEUEBASH_ROOT/policies.d/`.

## 0.17.11
## 0.17.14 - Systemd relative executable normalization

- Fixed `systemd-run --user` launch of queue commands whose argv[0] is a relative path containing a slash, such as `./tests/runtime_cap_payload_test.sh`.
- systemd-run requires argv[0] after `--` to be either a PATH-resolved executable name or an absolute path; `--working-directory` does not make `./script.sh` valid for systemd's parser.
- The worker now converts relative executable argv[0] values to absolute paths for systemd launches while preserving direct-runner behaviour.
- Added a static regression test for this launch path.

## 0.17.14 - systemd relative executable normalization

- Fixed `systemd-run --user` launch of queue commands whose argv[0] is a relative path containing a slash, such as `./tests/runtime_cap_payload_test.sh`.
- systemd-run requires argv[0] after `--` to be either a PATH-resolved executable name or an absolute path; `--working-directory` does not make `./script.sh` valid for systemd's parser.
- The worker now converts relative executable argv[0] values to absolute paths for systemd launches while preserving direct-runner behaviour.
- Added a static regression test for this launch path.


## 0.17.12 - Runtime cap normalization and stronger static C2 audit

- Normalise runtime cap names so underscore spelling such as `no_spawn_shell` arms the same cap as `no-spawn-shell`.
- Warn on unknown runtime cap names in the job record, log, history, and explain output.
- Expand `secaudit:no_network_c2` to catch listener-style `nc`, `ncat`, `socat TCP-LISTEN`, Python socket bind patterns, and wget pipe-to-shell patterns.
- `queue explain` now surfaces runtime cap violations and warning metadata directly under Execution caps.



- Fixed Class Creator default sandbox editing from the panel field list.
- Fixed F2 command-line class sandbox handling so `classcreator sandbox strict` writes `CLASS_DEFAULT_SANDBOX_LEVEL=strict`.
- Task Creator sandbox override behaviour is unchanged.

## 0.17.10

- Added runtime cap facilities `runtime:only_local_sockets` and `runtime:only_port`.
- Added `CLASS_DEFAULT_RUNTIME_CAP_PORTS` for port allow-lists such as `5432,8000-8099`.
- Runtime socket policy now uses `lsof -p PID -i` to distinguish localhost-only sockets and allowed service ports.
- Kept `assets.d/net_usage.sh` removed; runtime net usage remains under `caps.d/net_usage.sh`.


## 0.17.8

- Added runtime caps via `caps.d/runtime.sh`.
- Added class defaults `CLASS_DEFAULT_RUNTIME_CAPS` and `CLASS_DEFAULT_RUNTIME_CAP_INTERVAL`.
- Worker now runs a best-effort runtime watchdog for `no-spawn-shell`, `no-network-tools`, and `no-network-sockets`.
- Runtime watchdog uses `/proc` and `lsof -p` where available, records `RUNTIME_CAP_*` metadata, logs `runtime_cap_violation`, and fails violating jobs with exit code 96.
- Kept `assets.d/net_usage.sh` removed; runtime net usage remains under `caps.d/net_usage.sh`.

## 0.17.7 - Runtime sandbox and secaudit asset

- Added runtime sandboxing support through `--sandbox off|network-none|restrict-egress|strict`.
- Added `CLASS_DEFAULT_SANDBOX_LEVEL` so classes can default jobs into a sandbox.
- Systemd runner injects native sandbox properties such as `PrivateNetwork=yes`, `IPAddressDeny=any`, `ProtectSystem=strict`, and `NoNewPrivileges=yes`.
- Direct runner uses `unshare --net -r --` as a best-effort fallback for `network-none` and `strict`.
- Task Creator and Class Creator expose sandbox fields.
- Added `assets.d/secaudit.sh` with `secaudit:script_safe`, `secaudit:string_safe`, `secaudit:no_destructive`, `secaudit:no_network_c2`, `secaudit:no_privesc`, and `secaudit:no_obfuscation`.

## 0.17.6 - Queue history asset checks

- Added `assets.d/queue.sh` for bashqueues job-history preflight checks.
- New facilities: `queue:command_has_run`, `queue:command_has_not_run`, `queue:job_has_run`, and `queue:job_has_not_run`.
- These checks answer whether a matching queue job command/name has run within a time window such as `time=24h`; they are distinct from `proc:not_running`, which checks current OS processes.

## 0.17.5 - Cron review fixes and proc asset

- Cron generated class names are now scoped by user as well as command, preventing two users with identical commands from sharing the same generated class file.
- The cron ticker writes generated class files only when absent or changed.
- Added cron macro handling for `@hourly`, `@daily`, `@weekly`, `@monthly`, `@yearly`, and `@annually`; `@reboot` is reported as unsupported instead of silently misparsed.
- Cron de-duplication markers are cleaned after `${QUEUEBASH_CRON_STATE_MAX_AGE_DAYS:-7}` days.
- `queue cron list` now previews scheduled entries, `queue cron show [user]` prints a crontab, and `queue cron preview [--now ISO]` runs the ticker in dry-run mode.
- Added `assets.d/proc.sh` for process/running-job preflight checks.

## 0.17.4 - Global claim blocked history detail

- Global claim blocking now logs the specific claim key, mode, slots, and current holder summary.
- Suppressed the duplicate generic `class=... reason=global_claim` event so history is not filled with low-information repeats.
- `queue explain QID` now shows required global claims even for pending blocked jobs, including slots used and holders.

## 0.17.4 - Shell class wizard helper contract

- Restored the shell-side class wizard helper contract used by static and fallback tooling.
- Added `_queue_mgr_list_facilities_compact`, `_queue_mgr_facility_family`, `_queue_mgr_facility_check`, and `_queue_mgr_wizard_render_preview`.
- The legacy text QueueManager remains removed; these helpers only publish facility data and render record-format class text.

## 0.17.4 - Publish/selftest resubmit smoke fix

- Fixed global-claim empty-list iteration so ordinary classes with no `queue_class_global_*` records are not treated as blocked.
- Fixed `tests/selftest.sh` so the deliberate `failer` job is actually driven to `failed` before `queue resubmit failer` is exercised.
- This prevents queued publish jobs from failing when a two-worker selftest pass leaves `failer` pending.
- No runtime queue/resubmit behaviour change intended.

## 0.17.4 - Global shared resource slots

- Added explicit cross-user/global resource records:
  - `queue_class_global_exclusive_claim`
  - `queue_class_global_shared_claim`
  - `queue_class_global_exclusive_asset`
  - `queue_class_global_shared_asset`
- Added root/admin global coordination root: `${QUEUEBASH_GLOBAL_ROOT:-/var/lib/bashqueues/global}`.
- Added global commands: `queue global root|claims|claim|cleanup|release|health`.
- Added global claim audit events and user queue global-claim events.
- Added Global Resources panel to QueueManager.
- Added explicit exception bypass support for `global:claim` and `global:claim:CLAIM`.
- Existing non-global class records remain per-queue-root only.

## 0.16.37 - Module command identity/action parsing

- Fixed F2 module command parsing for completion-expanded module identities such as `class:CAPS_TEST explain`.
- Module commands now treat `class:NAME`, `asset:NAME`, and `cap:NAME` as the selected module identity, with the following word used as the action.
- Kept `assets.d/net_usage.sh` removed; runtime net usage remains under `caps.d`.

## 0.16.36 - User-context static test alignment

- Updated `tests/user_context_static.sh` so it expects the current submit-user normalisation path.
- The panel implementation already correctly calls `qrun(..., as_user=_normalise_optional_user(d.submit_user))`.
- No runtime behaviour change intended.

## 0.16.35 - Selected-user helper cleanup

- Removed a duplicate generated selected-user helper block from `queuebash.sh`.
- `queuebash.sh` now has exactly one definition each for `_queue_home_for_user`, `_queue_root_for_user`, `_queue_user_exists`, `_queue_select_user_queue`, and `queue`.
- Added static regression coverage so duplicated dispatcher/user-helper blocks are caught before future releases.
- No behaviour change intended; this is a hygiene patch before further operator/sysadmin workflow work.

## 0.16.34 - Better Class Creator restriction hint prompts

- Improved Class Creator restriction wizard prompts generated from asset/cap hints.
- Test/internal parameters such as `now_epoch=TEST` are no longer offered as normal production class fields.
- Updated `time:window` hints so `now_epoch` is documented as test-only rather than included in normal params.
- Updated `runnable:filesystem` hints so directory checks explain executable/search/traverse semantics and default to `executable=1`.
- Added static regression coverage for restriction hint quality.

## 0.16.33 - Exception panel honours selected queue owner

- Fixed the Exceptions panel when root/operator is viewing another queue owner.
- The panel now loads exception overlays through `queue exception list-all` instead of reading `$QUEUEBASH_ROOT/exceptions` directly.
- Added `queue exception list-all` / `queue exceptions list-all` for panel/global exception overlay listing.
- The panel header now displays the selected queue owner's queue root instead of the operator process root when `--queue-user` is active.

## 0.16.33 - Class Creator parameter prompts from asset/cap hints

- Class Creator restriction setup now parses asset/cap hint metadata instead of asking for one generic params line.
- A selected facility such as `time:window` now generates useful prompts for the target and each advertised key=value parameter.
- `*` on generated restriction fields opens contextual chooser lists, including policy names, day sets, time windows, interfaces, limits, and common queue variables.
- Optional/testing parameters such as `now_epoch=TEST` can be omitted instead of being accidentally saved into production class records.

## 0.16.33 - Prune obsolete asset-side net_usage and fix module explain path

- Added an explicit obsolete asset-plugin prune for `assets.d/net_usage.sh`; runtime net usage remains under `caps.d/net_usage.sh`.
- The Modules panel defensively hides stale `asset:net_usage` entries from older queue roots.
- Hardened `queue modules explain cap:NAME` so it reads the active module path first and only falls back to `.disabled` when the active file is absent.
- Added regression coverage for stale asset-side `net_usage` pruning and active-module explain output.

## 0.16.30 - Class Creator hint-driven restrictions

- Class Creator can now build restriction records directly from asset/cap hints.
- Added a Class Creator `add restriction` row and F2 commands such as `classcreator restriction net:allowance` and `restriction billing`.
- Restriction prompts use the standard `*` chooser behaviour for facilities, variables, record type, and parameter examples.
- Generated class records are appended to the Class Creator draft only after confirmation.
- `assets.d/net_usage.sh` remains removed; `caps.d/net_usage.sh` remains the cap module location.


## 0.16.29 - Task Creator queue-reference chooser

- Task Creator dependency fields now use a queue job reference chooser.
- `after success deps` and `inherit env from` offer existing queue job names/QIDs and an explicit clear option.
- Entering `*` in those fields opens the chooser instead of saving a literal wildcard such as `--inherit-env-from '*'`.

## 0.16.28

Panel command line object actions are now available for Assets and Classes. From the Classes panel, bare F2 commands such as `explain`, `history`, `enable`, `disable`, `refresh`, and `use` apply to the selected class. From the Assets panel, bare commands such as `explain`, `hint`, `validate`, `enable`, `disable`, `refresh`, and `rollback` apply to the selected asset/plugin. Explicit cross-panel forms such as `class GITHUB_PUBLISH history`, `class GITHUB_PUBLISH disable`, `asset net:allowance explain`, and `asset net:allowance disable` work from any panel. Contextual `*` completions now list selected class/asset actions directly.

## 0.16.28

- Add Task Creator/job editor fields for dependencies and hooks.
- Task Creator now supports after-success dependencies, inherited environment dependencies, on-success hooks, on-failure hooks, and on-retry-failure hooks.
- `queue draft create` now preserves the same dependency and hook metadata, and `queue draft submit` replays it into `queue submit`.
- Add regression coverage for task editor hook/dependency fields and draft preservation.

## 0.16.25

- Add panel Modules view for managing installed modules across `classes/`, `assets.d/`, and `caps.d/`.
- Install bundled `caps.d` modules into the selected queue root alongside bundled classes and asset helpers.
- Add enable/disable support for classes, asset plugins, and cap plugins:
  - `queue classes enable|disable CLASS`
  - `queue assets enable|disable FAMILY [--force]`
  - `queue caps enable|disable FAMILY`
  - `queue modules enable|disable class|asset|cap NAME`
- Disabled modules are moved under `.disabled/` below the owning directory, so normal loaders skip them without deleting the file.
- Add `queue modules list|explain|refresh` as a cross-module management surface.
- Add Shift-Tab reverse panel navigation.

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

## 0.17.30 - Authorisation signer key-root fix

- Fixed signed authorisation lookup when an operator/root shell is switched to another user's queue with `queue --queue-user USER`.
- Authorisation files and job stamping still target the selected queue root.
- Signing private keys now belong to the authorising admin/signer identity, not the selected target queue.
- For example, root authorising a job in hc3's queue signs with `/root/.queuebash/keys/private/root.ed25519.pem`, not `/home/hc3/.queuebash/keys/private/root.ed25519.pem`.
- Added signer key-root diagnostics to `queue authorisation policy`.
- Added regression tests for selected-queue signing.

## 0.17.4

- Added optional bashqueues cron bridge.
- Added `bashqueues-cron-ticker.py`, `bashqueues-crontab`, systemd timer/service, and installer.
- Added `queue cron root|list|tick|edit|remove`.
- Cron entries submit queue jobs with generated `cron_<hash>` classes capped at one concurrent run.
- The bridge does not replace `/usr/bin/crontab` by default.


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


## 0.16.36

- Fixed `tests/user_context_static.sh` to assert the current normalised submit-user delegation path.
- The implementation already correctly passes `d.submit_user` through `_normalise_optional_user(...)` before calling `qrun`.
- No runtime behaviour change.

## 0.17.14 - Seccomp profiles, exception overlays, and cron class routing

- Added class-level seccomp defaults: `CLASS_DEFAULT_SECCOMP_PROFILE` and `CLASS_DEFAULT_SECCOMP_ALLOW`.
- Added systemd `SystemCallFilter=` emission for `docker-default` and `strict` profiles.
- Added job-level exception overlay flags: `--sandbox-override`, `--seccomp-allow`, `--drop-cap`, and `--add-port`.
- `queue explain` now surfaces these security exceptions in the Exception overlays section.
- Cron bridge now supports `BASHQUEUES_CLASS=` stateful crontab routing.
- Auto-generated cron classes default to strict sandboxing and basic runtime caps.
