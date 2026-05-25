# Noninteractive submit default reason

`QUEUEBASH_SUBMIT_REASON_DEFAULT` is an operator convenience for trusted noninteractive scripts that call `queue submit` repeatedly, for example smoke tests that create a temporary queue while a shared `/etc/bashqueues` class-statement policy is active.

When `queue submit` is called without `--reason`, and this variable is set, the value is used exactly as if the script had passed:

```bash
--reason "$QUEUEBASH_SUBMIT_REASON_DEFAULT"
```

The resulting job still records `SECURITY_EXCEPTION_REASON` and a `description-approved` exemption where the active policy permits reason-based approval.

This variable is not an authorisation mechanism. It does not satisfy `authorisation`-only policy modes and it does not make a signed code valid for a different command.
