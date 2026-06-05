# Policy-blocked jobs

`pol_blocked` is a terminal queue state for jobs that are contrary to the active shared/admin class-policy statement at execution time and do not have a valid standing grant or command-bound authorisation.

The worker checks this before class claims, asset preflight, dynamic preflight, global claims, or payload launch.  A policy-blocked job therefore does not run preflight checks and is not retried.

## Why this exists

Submit-time `--reason` is useful audit text, but it is not a durable permission to run after an admin policy has been installed or changed under `/etc/queuebash/policies.d`.  If the active policy requires authorisation for a weak policy or an exception overlay, the worker must see one of these before executing:

- a standing user/command grant in the class-policy statement, or
- a valid, unexpired, command-bound authorisation code.

Without that, the job moves to:

```text
$QUEUEBASH_ROOT/pol_blocked/<qid>.job
```

The job log records `POLICY_BLOCKED` and states that no preflight or payload launch was attempted.

## Resubmission model

A policy-blocked job should not be retried automatically.  Obtain or create a valid authorisation for the exact command, then resubmit the command with:

```bash
queue submit NAME --authorisation CODE -- command args...
```

The same authorisation code may be reused for unlimited resubmissions of the exact same command until the authorisation expires.  It remains command-bound, so copying the code to another command does not work.

## Authorisation reuse

This is intentional.  It supports sensible administration: an admin can approve a command once, and the user can resubmit that same command while debugging unrelated runtime problems, without asking for a new approval each time.

Expiry still applies.  Once the authorisation expires, future submissions using that code are blocked by normal authorisation validation.


Legacy name: older 0.17.32/0.17.33 jobs may still live under `pol_blocked`; current screen-facing state is `pol_blocked`.
