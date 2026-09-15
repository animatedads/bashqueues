# Windows platform doctor

`queue platform doctor [--json]` is a read-only readiness surface for the Windows runtime lane.
It does not enable native Windows worker execution and it does not change queue state, host
configuration, services, policy roots, or files.

## Support posture

The support tiers remain:

- **Linux/POSIX**: primary supported runtime and worker path.
- **W1 / WSL2**: first viable Windows route, running BashQueues inside the WSL2 Linux guest.
- **W1 legacy / WSL1**: detectable but not the preferred worker path.
- **W2 / Git Bash, MSYS2, Cygwin**: constrained client/developer shell candidates only.
- **W3 / native Windows PowerShell / Windows Service**: future adapter work only.

The doctor is intentionally conservative. It reports `fail` for W2/W3 worker execution rather
than silently implying support.

## Human output

```sh
queue platform doctor
```

The human output reports:

- overall status: `ok`, `warn`, or `fail`
- detected platform id
- queue root
- queuebash.sh line-ending posture
- per-finding severity/code/message lines

## JSON output

```sh
queue platform doctor --json
```

The JSON schema is `queuebash.platform_doctor.v1`.

Fields:

- `status`: `ok`, `warn`, or `fail`
- `platform_id`: same detector id used by `queue platform --json`
- `queue_root`: active queue root
- `root_on_windows_mount`: true when WSL queue root appears under `/mnt/...`
- `queuebash_line_endings`: `lf` or `crlf`
- `policy_ref`: `policies.d/platform/windows-runtime-parity.json`
- `findings[]`: severity/code/message records

## WSL2 guidance

For WSL2 workers, prefer a queue root under the WSL ext4 filesystem, for example
`$HOME/.queuebash`, rather than `/mnt/c/...`. Windows-mounted roots can have different
metadata, locking, path, and line-ending behaviour from the Linux filesystem.

## Non-goals

This command does not:

- start workers
- install Windows services
- call PowerShell remoting or WinRM
- mutate policy roots
- convert line endings
- certify Git Bash/MSYS2/Cygwin/native Windows worker support
