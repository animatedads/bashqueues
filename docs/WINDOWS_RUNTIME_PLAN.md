# Windows runtime plan

Bob30 scope: define a viable path for running bashqueues on Windows without taking
provisioning, remote-resource lifecycle, ask-provider runtime, or secrets-runtime
ownership. This is a planning and contract package. It must not claim native
Windows support before the runtime, test, installer, and service contracts exist.

## Current conclusion

The practical Windows path is tiered:

1. **Supported first target: WSL2 with a Linux distribution.** Run bashqueues
   inside Ubuntu/Debian/openSUSE-on-WSL with the normal Bash/Linux userland. This
   preserves the existing queue function, file layout, process model, shell
   quoting, permissions, lock, and test assumptions.
2. **Constrained compatibility target: Git Bash, MSYS2, or Cygwin.** These can be
   useful for light developer commands, docs, static checks, and client-side
   remote management. They should not be advertised as full worker/service
   runtimes until process-tree handling, locking, filesystem permissions,
   signals, and scheduler semantics are proven.
3. **Future native target: PowerShell plus a Windows service wrapper.** Native
   operation should be implemented through a platform adapter layer rather than
   by spreading Windows conditionals throughout `queuebash.sh`.

The near-term acceptance target is therefore **Windows host, WSL2 guest runtime**.
Native Windows is a roadmap item, not an implied support claim.

## Existing Windows-adjacent coverage

The tree already contains Windows and Microsoft enterprise facts/provider-adjacent
coverage:

- `assets.d/winrm.sh`
- `assets.d/msad.sh`
- `assets.d/msdns.sh`
- `assets.d/msfs.sh`

Those assets are useful for classification, policy, and provider fact surfaces.
They are not a native runtime port by themselves.

## Runtime assumptions that must be isolated

The current runtime assumes a POSIX shell environment. A Windows port must isolate
or replace these assumptions before native support is credible:

| Area | Current Linux/POSIX expectation | Windows concern | Adapter needed |
| --- | --- | --- | --- |
| Shell entry | `source queuebash.sh`, Bash functions, Bash arrays | PowerShell cannot source Bash functions | launcher/bridge contract |
| Process model | `ps`, `pgrep`, process groups, `kill`, signals | Windows process tree and termination semantics differ | process adapter |
| Job isolation | shell subprocesses, process groups, optional `setsid` | Windows lacks POSIX sessions/signals | runner adapter |
| Locks | `flock`, atomic rename expectations | Git Bash/MSYS/Cygwin behaviour varies; native uses Win32 locks | lock adapter |
| Permissions | `chmod`, `chown`, mode bits, sticky dirs | NTFS ACLs are not Unix mode bits | ACL/permission adapter |
| Paths | `/tmp`, `$HOME`, `/usr/local`, colon-free queue paths | drive letters, backslashes, long paths, spaces | path adapter |
| Time | GNU/POSIX `date` assumptions | PowerShell/.NET and busybox/MSYS variants differ | time adapter |
| Scheduling | cron, systemd timers, process watchdogs | Task Scheduler and Windows Services differ | scheduler/service adapter |
| Identity | Unix UID/GID/root/sudo assumptions | Windows SID/groups/UAC/elevation differ | identity adapter |
| Text files | LF shell scripts | CRLF can break shebangs and Bash parsing | line-ending guard |
| Filesystem | case-sensitive expectations possible | NTFS is normally case-insensitive | path-collision guard |
| Networking remotes | OpenSSH/WinRM tools may exist or be absent | transport availability varies | remote transport adapter |

## Tier definitions

### Tier W1: WSL2 runtime

Goal: make the admin instruction clear and testable.

Expected posture:

- Install and run inside a WSL2 Linux distribution.
- Use normal `source ./queuebash.sh` development flow or the Linux system
  installer inside the WSL distribution.
- Store queue roots inside the Linux filesystem where possible, not under
  `/mnt/c/...`, to avoid permission, path, and file-watcher surprises.
- Treat Windows files and tools as external resources reached through mounted
  paths, OpenSSH, or WinRM rather than as native queue runtime internals.

Acceptance gates:

- README and system install docs state that Windows support begins with WSL2.
- Static tests guard against claims that Git Bash/MSYS2/Cygwin/PowerShell are
  full native worker runtimes.
- A smoke profile eventually runs `bash -n queuebash.sh`, `source queuebash.sh`,
  `queue version --json`, `queue submit`, `queue run`, and `queue list --json`
  inside WSL2.

### Tier W2: POSIX-on-Windows compatibility shell

Goal: allow useful client/dev operations without pretending full service parity.

Candidate environments:

- Git Bash
- MSYS2
- Cygwin

Allowed early scope:

- `queue version`, `queue help`, static checks, docs lookup, command catalogue,
  local classification helpers that do not require Unix service/process control.
- Remote client operations that use explicit transports and do not launch local
  Windows workers.

Blocked until proven:

- worker lifecycle control
- process-tree cancellation
- cron/systemd equivalents
- root/sudo policy semantics
- chmod/chown enforcement
- service installation
- lock-sensitive concurrent queue runs

Acceptance gates:

- platform detection reports a constrained tier.
- commands that rely on unsupported semantics fail closed with JSON facts when
  `--json` is requested.
- no live provisioning or remote mutation is introduced.

### Tier W3: native Windows runtime

Goal: true native operation without requiring WSL2.

This should be implemented only after a platform adapter boundary exists.

Required components:

- PowerShell launcher that calls a supported command surface and preserves JSON
  output semantics.
- Windows service wrapper for workers, probably separate from the Bash function
  entrypoint.
- Task Scheduler bridge for scheduled ticks.
- NTFS ACL policy mapping for class/policy roots.
- Windows Event Log or file-backed audit adapter.
- WinRM/OpenSSH transport abstraction for remote administration.
- process-tree cancellation using Windows APIs or a trusted helper.
- path normalisation for drive letters, UNC paths, spaces, and long paths.
- CRLF and case-collision guards at install/extract time.

Native Windows support should be accepted only when every worker-affecting command
has a JSON-safe fail-closed path and at least one Windows CI/smoke path.

## Recommended implementation sequence

1. Add platform detection facts: `linux`, `wsl2`, `git-bash`, `msys2`, `cygwin`,
   `native-windows-powershell`, and `unknown`.
2. Add a `queue platform --json` or equivalent platform fact surface before any
   behavioural changes.
3. Add a docs-only WSL2 quickstart and a static guard preventing unsupported
   native claims.
4. Introduce internal platform adapters for path, process, lock, permissions,
   time, scheduler, identity, and service operations.
5. Make unsupported adapter calls fail closed with structured JSON.
6. Add WSL2 smoke tests first, then Git Bash/MSYS2/Cygwin constrained smoke
   tests, then native PowerShell/Windows service tests.
7. Only then advertise native Windows worker support.

## Admin guidance for first viable Windows deployment

For now, the viable Windows deployment is:

```text
Windows 10/11 or Windows Server host
  -> WSL2 enabled
  -> Linux distribution installed
  -> bashqueues installed and run inside the WSL Linux filesystem
  -> Windows estate reached through WinRM/OpenSSH/MSAD/MSDNS/MSFS provider facts
```

Do not install the current Linux systemd/cron/root-key path directly into native
Windows. Do not promise Task Scheduler, Windows Service, or PowerShell-native
worker support until the adapter and smoke-test gates exist.

## Non-goals for Bob30

- No provisioning or resource lifecycle.
- No ask-provider runtime changes.
- No secrets runtime/security-control ownership.
- No queue-dev/display-resource/command-contract ownership except for static
  documentation guards if needed.
- No claim that Windows native operation is complete.
