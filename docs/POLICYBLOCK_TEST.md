# Policy-block test policy

`policies.d/class-statement/policyblock-test.env` is a deliberate validation policy.
It marks jobs using class name `POLICYBLOCKED` as policy-contrary.

This is not intended as a normal production policy. It is a stable test hook for
checking that the worker moves jobs into the terminal `pol_blocked` state before
class claims, asset preflight, dynamic preflight, global claims, or payload launch.

## Install as shared/admin policy

```bash
sudo mkdir -p /etc/queuebash/policies.d/class-statement
sudo cp policies.d/class-statement/policyblock-test.env \
  /etc/queuebash/policies.d/class-statement/policyblock-test.env
sudo chmod 0644 /etc/queuebash/policies.d/class-statement/policyblock-test.env
```

Then select it for the queue process:

```bash
export QUEUEBASH_CLASS_POLICY_STATEMENT=policyblock-test
```

## Validation

```bash
queue submit pbtest --class POLICYBLOCKED -- echo SHOULD_NOT_RUN
queue run
queue list
```

Expected result: the job appears in `pol_blocked`, and the payload text does not
appear in the job log.

The block is command-authorisation compatible: if a valid, unexpired,
command-bound authorisation is later issued for the same command, that command may
be resubmitted with the authorisation code until the authorisation expires.
