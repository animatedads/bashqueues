# Policy command blocks

Shared/admin class-policy statements can rapidly block a command before it runs.
This is intended for zero-hour operational response: if a tool or invocation is
suddenly known to be unsafe, an administrator can put a read-only policy under
`/etc/queuebash/policies.d/class-statement/` and stop matching jobs from
executing, including jobs submitted by cron.

The worker checks command blocks before class claims, asset preflight, dynamic
preflight, global claims, and payload launch.  A blocked job moves to `pol_blocked`
and is not retried.

## Policy variables

Exact hash blocks are preferred:

```bash
CLASS_POLICY_BLOCK_COMMAND_HASHES="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
```

A first-16-hex prefix may also be used for operator convenience, but full SHA256
is better for production policy.

Command word blocks match `argv[0]` or `basename(argv[0])`, case-insensitively:

```bash
CLASS_POLICY_BLOCK_COMMAND_WORDS="exiftool vulnerable-tool"
```

Pattern blocks match the shell-escaped command string using shell globs.  Use
these sparingly because they are broader than command hashes:

```bash
CLASS_POLICY_BLOCK_COMMAND_PATTERNS="*exiftool*;*vulnerable --mode*"
```

By default, command blocks require a valid command-bound authorisation:

```bash
CLASS_POLICY_BLOCK_COMMAND_REQUIRE="authorisation"
```

## Running with authorisation

If a command is blocked but a valid authorisation exists for the exact command
hash and user, the job may run.  The job record and `queue explain` show this as
an exemption:

```text
exemption:         code-approved
  action:          run_with_authorisation
  detail:          on-file command-bound authorisation ABC12
  authorisation:   ABC12
```

The history also receives a `security_exemption` event so the job is still
visible as an exception even when it completes successfully.

## Standing grants

Standing policy grants may be used for carefully delegated operations.  For
blocked commands, the supported grant suffixes are:

```bash
CLASS_POLICY_USER_WEBADMINS_ALLOW_BLOCKED_COMMAND_HASHES="0123456789abcdef"
CLASS_POLICY_USER_WEBADMINS_ALLOW_BLOCKED_COMMAND_WORDS="exiftool"
CLASS_POLICY_USER_WEBADMINS_ALLOW_BLOCKED_COMMAND_PATTERNS="*safe-wrapper*"
```

Command-bound authorisations are still safer for emergency blocks because they
bind the approval to one exact argv array.
