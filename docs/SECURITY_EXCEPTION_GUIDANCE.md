# Security exception guidance

`queue explain <qid>` includes a `Security exception guidance` section.

The guidance is deliberately job-local. It does not rewrite class defaults, policy files, or trust settings. It prints the smallest likely operator exception for the specific job record and log evidence available.

## Runtime caps

When a runtime cap kills a job, explain maps the recorded `RUNTIME_CAP_VIOLATION` to a narrow submit-time flag:

- `no-network-tools` -> `--drop-cap no-network-tools`
- `no-network-sockets` -> `--drop-cap no-network-sockets`
- `only-local-sockets` -> `--drop-cap only-local-sockets`
- `no-spawn-shell` -> `--drop-cap no-spawn-shell`
- `only-port` -> `--add-port PORT` when the port can be inferred

The example `queue submit ...` line preserves the original job name, class, and command where available.

## Sandbox and seccomp

When a strict/network-none sandbox appears to have blocked a network command, explain suggests:

```bash
--sandbox-override off
```

When strict seccomp appears to have blocked debugging/syscall behaviour, explain suggests the relevant narrow `--seccomp-allow` starting point, commonly:

```bash
--seccomp-allow @debug
```

## Class/asset preflight

For pending jobs blocked by a class/asset preflight, explain probes the existing preflight checks and prints the job-local exception command:

```bash
queue exception add <qid> <asset-or-facility> --reason "approved one-off exception for this job"
```

Prefer specific facilities such as `secaudit:no_network_c2` over broader family exceptions such as `secaudit`, unless the broader exception is intentional and documented.
