# Class policy statements and short authorisations

`bashqueues` now has a central class policy statement layer.  This is not DKI
signing yet; it is the governance statement that decides which security policy
choices are user-selectable and when an exception must be justified.

Bundled default statement:

```text
policies.d/class-statement/default.env
```

Policy lookup uses the same precedence as sandbox/seccomp policies:

1. `/etc/bashqueues/policies.d/class-statement/default.env`
2. `$QUEUEBASH_ROOT/policies.d/class-statement/default.env`
3. bundled repository `policies.d/class-statement/default.env`

## What the statement controls

The default statement defines:

```bash
CLASS_POLICY_USER_SANDBOX_POLICIES="off network-none restrict-egress strict queue-default"
CLASS_POLICY_USER_SECCOMP_POLICIES="off docker-default strict queue-default"
CLASS_POLICY_EXCEPTION_FLAGS_REQUIRE="reason-or-authorisation"
CLASS_POLICY_WEAK_POLICY_REQUIRE="reason-or-authorisation"
CLASS_POLICY_SANDBOX_REASON_REQUIRED="off"
CLASS_POLICY_SECCOMP_REASON_REQUIRED="off"
CLASS_POLICY_CRON_MIN_SANDBOX_LEVEL="strict"
CLASS_POLICY_CRON_MIN_SECCOMP_PROFILE="off"
```

That means normal submit-time exception overlays are still ergonomic, but they
must now be deliberate and auditable.

These flags require either `--reason TEXT` or `--authorisation CODE` by default:

```bash
--sandbox-override LEVEL
--seccomp-allow GROUP
--drop-cap CAP
--add-port PORT
```

Selecting deliberately weak direct policies such as `--sandbox off` or
`--seccomp off` also requires the same justification by default.

## Reason-based exceptions

For ordinary one-off operator decisions, use a reason:

```bash
queue submit fetch_test \
  --class TIGHT_SEC \
  --sandbox-override off \
  --reason "one-off external fetch approved for incident 123" \
  -- wget https://example.com/
```

The job record stores the reason as `SECURITY_EXCEPTION_REASON`.

## Command-bound authorisations

An authorisation is a short queue-local admin permission code.  Codes are case
insensitive, queue specific, and must be no more than five letters/numbers.

Generate one for an exact command:

```bash
queue generate authorisation \
  --admin alice \
  --user bob \
  --code A1B2 \
  --reason "approved for tonight's maintenance" \
  -- bash -lc 'curl https://example.com/health'
```

Use it on submit:

```bash
queue submit health_check \
  --sandbox-override off \
  --authorisation A1B2 \
  -- bash -lc 'curl https://example.com/health'
```

The code is matched against the command hash.  Copying the same code onto a
different command fails.  The record is also self-checked: if someone forcibly
edits the stored `AUTHORISATION_COMMAND=(...)` line without regenerating the
matching hash, the file reports as invalid and is not accepted.

List records with validity/integrity status:

```bash
queue authorisation list
queue authorisation show A1B2
```

Existing jobs can be authorised in-place by an operator/root shell:

```bash
queue authorise 20260525_010203_000000000_012345_9999   --reason "approved one-off maintenance escape hatch"
```

That command creates the queue-local authorisation record and appends the code to
the existing `.job` file.  It deliberately appends to the current job file rather
than replacing it, so root/operator use does not accidentally change the job
file owner or group.

Authorisation records live in:

```text
$QUEUEBASH_ROOT/authorisations/CODE.env
```

They store the admin, target user, command hash, status, expiry, reason, and the
original command array.  They do not grant trust outside the queue root.

## Signed authorisation keys

For stronger governance, the class-policy statement can declare which public keys
are trusted to sign authorisations.  Generate an Ed25519 keypair for an
authorising admin/user:

```bash
queue keygen authorisation root
queue keygen authorisation hc3
```

This creates:

```text
$QUEUEBASH_ROOT/keys/private/NAME.ed25519.pem      # mode 0600
$QUEUEBASH_ROOT/keys/public/NAME.ed25519.pub.pem  # mode 0644
$QUEUEBASH_ROOT/keys/meta/NAME.env
```

`queue keygen` prints the policy lines for the public key.  Place those lines in
a central policy such as:

```text
/etc/bashqueues/policies.d/class-statement/default.env
```

and make it read-only/admin-owned if required:

```bash
CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="if-trusted-key"
CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_SHA256="..."
CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_PEM_B64="..."
CLASS_POLICY_AUTHORISATION_SIGNER_HC3_PUBLIC_KEY_SHA256="..."
CLASS_POLICY_AUTHORISATION_SIGNER_HC3_PUBLIC_KEY_PEM_B64="..."
```

Supported signature modes:

- `off` - legacy command-hash authorisation only.
- `if-trusted-key` - if policy declares a public key for `AUTHORISATION_ADMIN`,
  the authorisation must carry a valid signature.
- `always` - every authorisation must carry a valid signature and the admin must
  have a policy-declared public key.

The signed payload includes the queue root, authorising admin, authorised user,
exact command hash, creation time, expiry, and reason hash.  The short code stays
case-insensitive and no more than five letters/numbers, but it is only a lookup
handle; it cannot be copied to another command and it cannot be repaired by
editing the `.env` file unless the attacker also has the private signing key.

`queue authorisation list` reports `integrity=valid-signed`,
`integrity=valid-unsigned`, or the invalid reason, such as
`invalid-payload-hash`, `invalid-signature`, or `invalid-command-hash`.

## Crontab minimum security

The cron bridge now treats explicitly requested classes as security-sensitive.
If a crontab sets `BASHQUEUES_CLASS=NAME` and that class is weaker than the
statement's cron minimum, the ticker requires a matching command-bound
`BASHQUEUES_AUTHORISATION=CODE`.

Without a valid matching code, the ticker does **not** run the weaker class.  It
falls back to the generated safe cron class for that command and prints a
warning.

Example:

```cron
BASHQUEUES_CLASS=LOW_SECURITY_FETCH
BASHQUEUES_AUTHORISATION=A1B2
* * * * * curl https://example.com/health
```

If `A1B2` was generated for exactly `bash -lc 'curl https://example.com/health'`
and for the crontab user, the requested class is used.  If not, the safe
generated cron class is used instead.


### Authorisation signature enforcement details

With `CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="if-trusted-key"`, the policy file is the trust list. If it declares one or more `CLASS_POLICY_AUTHORISATION_SIGNER_<NAME>_PUBLIC_KEY_*` entries, then an authorisation from a declared signer must carry a valid signature over the queue root, authorising admin, authorised user, command hash, expiry, and reason hash. An unsigned record from a declared signer is reported as `invalid-missing-signature`; a record from a signer not present in the policy trust list is reported as `invalid-untrusted-admin`.

Authorisation records are published read-only/readable after creation so root can issue an approval into a selected user's queue without leaving an unreadable `0640 root:root` record behind.
