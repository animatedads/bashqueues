# Bob28 direct-source and global JSON contract

Bob28 closes two dropped-job surfaces without colliding with the 0.18.117 Bob27 plan-ingestion and lifecycle JSON merge.

## Direct execution guard

`queuebash.sh` is a shell environment loader. Executing it as `bash queuebash.sh` cannot install the `queue` function, completion hooks, or shell state into the caller's already-running shell. The top of the file now detects direct execution before the normal non-interactive source guard and exits with a clear operator advisory.

Human form:

```bash
bash queuebash.sh
```

returns exit code `2` and tells the user to run:

```bash
source queuebash.sh
```

It also gives a persistent interactive-shell example:

```bash
printf '%s\n' 'source queuebash.sh' >> ~/.bashrc
```

Automated form:

```bash
bash queuebash.sh --json
```

returns `queuebash.direct_execution_advice.v1` with `reason=queuebash_must_be_sourced`, the one-shot source command, and the `.bashrc` append command.

## Global JSON switch

Frontends may now place the JSON request before the command:

```bash
queue --json version
queue --json help
queue --json submit demo -- echo hello
```

The dispatcher stores the request in dynamically scoped `QUEUEBASH_OUTPUT_JSON=1` for the duration of that `queue` invocation only. Existing command-local `--json` parsing remains valid and takes precedence where a command already has a command-specific schema. The global switch must not leak into later human commands.

`queue --json help` emits `queuebash.command_catalog.v1`, a bounded command catalogue and negotiation point for frontends.

Unknown commands reached through the global JSON switch return `queuebash.error.v1` instead of a prose-only parser failure.

## Compatibility boundary

This patch does not replace Bob23/Bob27 lifecycle JSON schemas and does not rewrite command implementations. It adds a dispatcher-level JSON request path and initializes existing `json`/`json_output` locals from that path, so commands with JSON support can be driven uniformly by `queue --json COMMAND ...` while preserving normal human output by default.
