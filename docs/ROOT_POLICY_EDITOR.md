# Root-aware policy editor

`queue policies edit` is now root-aware.

When run as root, the default edit target is the shared site policy tree:

```text
/etc/bashqueues/policies.d
```

When run as a normal user, the default edit target remains the queue-local policy tree:

```text
$QUEUEBASH_ROOT/policies.d
```

Explicit scope flags are available for scripts and for operators who want to be precise:

```bash
queue policies edit class-statement default --shared
queue policies edit class-statement default --personal
queue policies create class-statement relaxed --from default --shared
queue policies path class-statement default --shared
queue policies path class-statement default --personal
```

Shared policy editing requires root. This is deliberate: shared policies are the site-wide guardrails and normally live under `/etc/bashqueues/policies.d`.

## Implicit defaults versus explicit weak choices

A normal job submitted with no explicit sandbox/seccomp choice should not become a security exception merely because the computed default is `off`. Weak-policy checks now distinguish between:

```bash
queue submit test -- echo ok
```

and:

```bash
queue submit test --sandbox off -- echo ok
```

The first is an ordinary default. The second is an explicit weak-policy selection and may require `--reason` or `--authorisation`, depending on the active class-statement policy.

Job files record this distinction with:

```bash
SECURITY_SANDBOX_EXPLICIT=0|1
SECURITY_SECCOMP_EXPLICIT=0|1
```
