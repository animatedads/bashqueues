# Windows support matrix

`queue platform matrix [--json]` is a read-only support-posture surface for operators,
test harnesses, and other Bob lanes. It makes the Windows runtime position explicit without
requiring a platform spoof or a live Windows host.

The command does not start workers, install services, change policy roots, call PowerShell,
call WinRM, or certify native Windows support.

## Human output

```sh
queue platform matrix
```

The human output lists each supported detector id and the current operator position:

- `linux`: primary POSIX runtime and worker path.
- `wsl2`: W1, the first viable Windows route, running inside a WSL2 Linux guest.
- `wsl`: detectable legacy WSL, but not the preferred worker path.
- `git-bash`, `msys2`, `cygwin`: W2 client/developer shell candidates only.
- `native-windows-powershell`: W3 future adapter only.
- `unknown`: fail-closed, no support claim.

## JSON output

```sh
queue platform matrix --json
```

The JSON schema is `queuebash.platform_matrix.v1`.

Key fields:

- `policy_ref`: points to `policies.d/platform/windows-runtime-parity.json`.
- `claim`: the overall WSL2-first/native-Windows-not-yet-supported position.
- `tiers[]`: one record for each detector id, with `runtime_supported`,
  `worker_runtime_supported`, `support_tier`, `family`, and `operator_position`.

## Support posture

This matrix is intentionally conservative. W2 shells and native Windows report both
`runtime_supported:false` and `worker_runtime_supported:false`. The only Windows-hosted route
that can claim worker support is WSL2, and that claim is specifically for the Linux guest
runtime, not for native Windows worker execution.
