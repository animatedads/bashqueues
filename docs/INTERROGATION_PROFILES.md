# Interrogation profiles

Interrogation profiles add a learning/replay governance rail to bashqueues.
They are intended for tasks whose behaviour should not silently drift after
approval.

The lifecycle is deliberately conservative:

1. **Profile** known-good behaviour using `strace`, `ss`, and `lsof` where available.
2. **Repeat/campaign profile** stateful tasks that may only reveal behaviour after several runs.
3. **Compile/merge** candidate seccomp, network, and file/resource profiles.
4. **Review** the candidates.
5. **Approve/sign** the candidates explicitly.
6. **Gate** secure classes with `secprofile`, `netprofile`, and `fileprofile` assets.

Generated profiles are candidates first and contain `SHOULD_BE_SIGNED=1`. They
must not be treated as enforceable policy until approved.

## PID-scoped compilation

Compiled candidate policies are intentionally PID-tree scoped.  The collector may
record global `ss` and `lsof -i` samples as evidence, but those machine-wide
records can include browser, mail, DHCP, or other unrelated traffic.  They are
therefore not used to populate `NETPROFILE_ALLOWED_REMOTE_PORTS` or
`NETPROFILE_ALLOWED_REMOTE_HOSTS`.

The compiler uses `lsof.process.trace`, collected with `lsof -p` against the
profiled root process and its children, as the source for network and file
allow-list candidates.  Global network samples are retained as ignored context
fields such as `NETPROFILE_CONTEXT_REMOTE_PORTS_IGNORED` and accompanied by the
`global_network_context_ignored` warning.

Generated seccomp candidates also filter non-syscall status tokens such as
`WEXITSTATUS`; only lower-case Linux syscall names are emitted into
`SECPROFILE_ALLOWED_SYSCALLS`.

Deleted-file handling is conservative: `FILEPROFILE_ALLOW_DELETED_FILES=1` is
only written when deleted file handles were actually observed in the PID-scoped
`lsof` evidence.

## Commands

```bash
queue profile interrogate run wget-google -- wget http://www.google.com
queue profile interrogate run short-script --pre-arm-delay 0.5 -- ./script.sh

queue profile interrogate repeat harmless-rexx --count 10 -- rexx harmless.rex
queue profile interrogate diff-runs ~/.queuebash/profiles/interrogation/campaigns/<campaign-id>
queue profile interrogate merge ~/.queuebash/profiles/interrogation/campaigns/<campaign-id> --name harmless_rexx

queue profile interrogate compile ~/.queuebash/profiles/interrogation/runs/<run-id> --name wget_google
queue profile interrogate approve wget_google
queue profile interrogate show wget_google
queue profile interrogate diff wget_google ~/.queuebash/profiles/interrogation/runs/<new-run-id>
```

## Pre-arm delay

Very short-lived programs can execute before socket/file/process monitors have
sampled anything. `queue-interrogate` therefore starts the trace wrapper and
monitor first, waits briefly, and only then `exec`s the real payload. The default
pre-arm delay is controlled by:

```bash
QUEUEBASH_INTERROGATE_PRE_ARM_DELAY=0.25
```

It can be overridden per run:

```bash
queue profile interrogate run NAME --pre-arm-delay 0.75 -- command args...
```

The delay is observation setup time, not a security control.

## Campaign/repeat mode

One clean run is not enough for stateful or delayed behaviour. A script might be
quiet for nine executions and only open network sockets or delete files on the
tenth. Campaign mode records each run separately:

```text
$QUEUEBASH_ROOT/profiles/interrogation/campaigns/<campaign-id>/
  campaign.env
  run-001/
  run-002/
  ...
  merged/
```

`diff-runs` compares later runs against the first run and writes:

```text
drift.report.json
```

`merge` creates candidate profiles from the union of all campaign runs.

## Run artefacts

A single run creates:

```text
$QUEUEBASH_ROOT/profiles/interrogation/runs/<run-id>/
  syscalls.raw.trace
  syscalls.summary.txt
  net.ss.trace
  lsof.process.trace
  lsof.net.trace
  process.tree.trace
  profile.env
  profile.json
  candidate.seccomp.env
  candidate.net.env
  candidate.file.env
```

Approved profiles live under:

```text
$QUEUEBASH_ROOT/profiles/interrogation/approved/<name>.seccomp.env
$QUEUEBASH_ROOT/profiles/interrogation/approved/<name>.net.env
$QUEUEBASH_ROOT/profiles/interrogation/approved/<name>.file.env
```

## Asset gates

```bash
queue_class_shared_asset secprofile profile_verified wget_google
queue_class_shared_asset netprofile profile_verified wget_google
queue_class_shared_asset fileprofile profile_verified wget_google
```

The first implementation verifies approved/signed profile metadata and a
SHA256 approval stamp. Full runtime enforcement of network and file behaviour
is intentionally separate future work; the profile rail provides reviewed policy
artefacts and class gates first.

## Why `strace`, `ss`, and `lsof`?

`strace` shows syscall behaviour. `ss` records socket/port behaviour. `lsof`
adds open files, libraries, Unix sockets, deleted files, and other process
resources. The compiler normalises these into broad profile fields rather than
brittle exact command output.


### Drift reports when the first run is already expanded

`queue profile interrogate diff-runs` reports both `new_*` and `missing_*`
behaviour relative to the first run, and also includes a `changed_from_previous`
section for each later run.  This matters for delayed-trigger tests where the
first campaign run may already be in the suspicious branch because previous
state existed before profiling began.  In that case later “good” runs still
represent behavioural drift and the report must not silently say `drift=false`.

## Review / explain and signed approval

Generated interrogation profiles are security policy, not telemetry.  They are
therefore candidates until a review step approves and signs them.

Use `explain` to review the candidate before approval:

```bash
queue profile interrogate explain PROFILE_NAME
```

`explain` reports the candidate files, syscall count, network endpoints, file
prefixes, warnings, blockers, and the command required to approve the profile.
Warnings block casual approval by default.  Risk blockers such as observed
network egress, listeners, broad `/tmp` access, deleted-file observations, or
obvious destructive syscalls require an explicit risk acknowledgement.

Approval signs by default.  If no signing key is supplied, bashqueues uses a
local self-signing identity such as `self:$USER`.  A site policy can later
replace this with a stronger key/trust store without changing the approved
profile format.

Examples:

```bash
queue profile interrogate approve goodrexx --accept-warnings
queue profile interrogate approve badrexx --accept-warnings --accept-risk --signing-key ops-release
```

The approved profile is stamped with fields such as:

```text
SECPROFILE_SIGNED=1
SECPROFILE_SIGNED_BY=self:hc3
SECPROFILE_SELF_SIGNED=1
SECPROFILE_SIGNATURE_SHA256=...
```

`review` is accepted as an alias for `explain`, but `explain` is the preferred
verb because it matches the rest of the queue diagnostic surface.

## Profile signature verification

Approved interrogation profiles are signed with a tamper-evident SHA256 stamp.
Use:

```bash
queue profile interrogate verify NAME
```

The verifier checks that approved seccomp/net/file profiles exist, are marked
approved/signed, and that the recorded signature hash still matches the profile
content. Trust policy can then narrow accepted signers:

```bash
queue profile interrogate verify NAME --allow-self-signed 0
queue profile interrogate verify NAME --required-signer ops-release
```

Class assets can enforce the same policy:

```bash
queue_class_shared_asset secprofile profile_verified NAME allow_self_signed=0 required_signer=ops-release
queue_class_shared_asset netprofile profile_verified NAME allow_self_signed=0 required_signer=ops-release
queue_class_shared_asset fileprofile profile_verified NAME allow_self_signed=0 required_signer=ops-release
```

Self-signed profiles remain useful for development and test. Live, legal,
root/system installer, or destructive classes should require a trusted signer.
