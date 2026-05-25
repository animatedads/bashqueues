# pol_block re-evaluation

`pol_block` is a terminal non-run state: the payload has not executed. When an administrator changes the active shared class-policy statement, existing `pol_block` jobs can be rechecked without cloning them manually.

```bash
queue reevaluate --all
queue reevaluate <QID-or-name>
queue reevaluate <QID-or-name> --dryrun
```

If the current policy now allows the command, or a valid on-file command-bound authorisation/grant is available, the original job file is moved back to `pending`. If it is still contrary to policy, it stays in `pol_block` and the command prints the policy reason.

This command performs the same cheap policy gate used by the sentinel and worker. It does not run asset preflight and does not launch payloads.
