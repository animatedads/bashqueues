# Windows WSL2 quickstart

Bob30 scope: administrator-facing guidance for the first viable Windows host
runtime. This document does not claim native Windows worker support. The current
supported route is to run bashqueues inside a WSL2 Linux distribution and to
reach Windows estate resources through explicit remote/provider facts such as
WinRM, OpenSSH, MSAD, MSDNS, and MSFS.

## Supported first route

Use this topology:

```text
Windows host
  -> WSL2 enabled
  -> Linux distribution installed
  -> bashqueues installed and sourced inside the Linux guest filesystem
  -> optional Windows resources reached through explicit remotes/providers
```

Recommended administrator posture:

1. Install a WSL2 Linux distribution such as Ubuntu or Debian.
2. Place the bashqueues checkout under the Linux filesystem, for example under
   `$HOME`, rather than under `/mnt/c/...`.
3. Use the normal Linux development flow:

   ```bash
   cd ~/bashqueues
   source ./queuebash.sh
   queue version --json
   ```

4. Run workers, queue roots, logs, locks, and policy files inside the WSL Linux
   filesystem unless a future adapter explicitly says otherwise.
5. Treat Windows paths, Windows accounts, and Windows services as external
   resources until native adapters exist.

## What is deliberately not supported yet

The following are not current support claims:

- native PowerShell worker runtime
- Windows Service worker installation
- Task Scheduler replacement for cron/systemd scheduling
- NTFS ACL parity for Unix chmod/chown policy enforcement
- native Windows process-tree cancellation parity
- lock-sensitive concurrent worker execution under Git Bash, MSYS2, or Cygwin

## Early smoke checklist for WSL2

A future CI/smoke path should prove at least this set inside WSL2:

```bash
bash -n queuebash.sh
source ./queuebash.sh
queue version --json
queue help >/dev/null
queue submit --help >/dev/null
queue list --json >/dev/null
```

Any failing command should report a normal Linux/WSL problem, not fall back to a
native Windows code path.

## Line endings and filesystem placement

Keep repository scripts as LF, not CRLF. Do not use a Windows editor or archive
extractor that rewrites shell scripts to CRLF. Prefer the WSL Linux filesystem
for the checkout and queue root. A checkout under `/mnt/c/...` can expose
case-insensitive path behaviour, Windows antivirus scanning delays, and Unix mode
bit surprises.

## Escalation rule

If an administrator asks whether bashqueues now runs natively on Windows, answer:

```text
Run it in WSL2 today. Native PowerShell/Windows Service support is planned but
not yet a support claim.
```
