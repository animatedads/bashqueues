# bashqueues secrets provider contract

The secrets subsystem is a governed access broker. bashqueues must not become the
secret store. It brokers access to provider families such as Vault, cloud secret
managers, Kerberos/AD backed systems, workload identity providers, and file-backed
fixtures for tests.

## Rules

- Secret values must never be emitted in JSON, logs, scratchpad, docs, command
  examples, or ordinary environment variables by default.
- Provider JSON returns redacted metadata and delivery references only.
- Default delivery is per-job file delivery with restrictive permissions.
- Environment delivery is denied by default and must be an explicit class/policy
  exception.
- First package is fixture-first and must not perform live Vault/cloud calls.

## Normalized commands

```text
queue secrets providers [--json]
queue secrets explain SECRET_REF --class CLASS [--json]
queue secrets request SECRET_REF --name NAME --class CLASS --purpose TEXT --qid QID --delivery file --json
queue secrets cleanup QID [--json]
queue secrets verify-manifest QID [--json]
```

The broker helper lives under `providers.d/secrets/secrets_provider.sh` and may
delegate to provider-specific helpers such as `file_provider.sh`,
`vault_provider.sh`, or cloud-native secret manager providers.

## Response contract

Secret request responses use `queuebash.secret_provider.result.v1` and include a
path or other delivery reference, never the secret value:

```json
{
  "schema": "queuebash.secret_provider.result.v1",
  "ok": true,
  "provider": "file",
  "secret_ref": "customer-db/prod/password",
  "delivery": "file",
  "path": "/run/queuebash/secrets/JOB/db_password",
  "secret_value_included": false,
  "redacted": true
}
```

Error responses in JSON mode use `queuebash.error.v1`.

## Delivery modes

`file` is the default and only mode enabled in the fixture provider. The job
receives a path such as:

```text
QUEUEBASH_SECRET_DB_PASSWORD_FILE=/run/queuebash/secrets/JOB/db_password
```

The secret value itself is not placed in an ordinary environment variable.

`fd` may be added later for stronger wrappers.

`env` is discouraged and denied by default.

## Active fixture policy enforcement

The fixture/file provider supports active local policy files for contract tests and
small deployments. If `QUEUEBASH_SECRETS_POLICY_DIR` is set, or if active policy
files exist under `$QUEUEBASH_ROOT/policies.d/secrets`, the provider reads:

```text
class-bindings.tsv
secret-acl.tsv
```

`class-bindings.tsv` gates whether a class may request secrets and which delivery
mode is allowed. `secret-acl.tsv` gates the `class + secret_ref + purpose +
delivery` tuple and may set a maximum TTL. Example `.example` files are not active
policy. A denied class, denied purpose, delivery mismatch, or over-policy TTL must
return `queuebash.error.v1` and must not read or copy the fixture secret.

## 0.18.102 hardening: redacted audit and break-glass refusal

The fixture broker remains a governed access broker, not a secret store and not an
emergency reveal tool.  Break-glass verbs are intentionally visible in the
contract surface so operators can plan the dual-control workflow, but the bundled
fixture broker refuses them by default with `authorization_required` and
`secret_value_included=false` until a later signed provider implements approval,
short TTL, ticket, and audit requirements.

The file-backed fixture provider writes redacted JSONL audit evidence for secret
request and cleanup events.  Audit records include metadata such as provider,
class, delivery mode, secret reference, decision status, reason code, and a
`purpose_hash`; they do not include the secret value and do not preserve the raw
purpose text.  The audit command returns the audit log path and event count rather
than replaying secret-bearing data.

The broker path must stay shell-native and bounded.  JSON escaping for broker
metadata is implemented in Bash so the default fixture path does not depend on a
Python interpreter for simple command routing or break-glass refusal responses.

## 0.18.103 hardening: delivery manifest and cleanup evidence

File delivery now records a per-job redacted delivery manifest next to delivered
secret files.  The manifest uses `queuebash.secret_delivery_manifest.v1`, is mode
`0600`, records provider/name/class/delivery, hashed secret reference metadata,
path metadata, TTL seconds, and `secret_value_included=false`.  It must not store
the secret value or the raw purpose text.

Cleanup removes the whole per-job secret directory and writes separate redacted
cleanup evidence under the secret audit directory using
`queuebash.secret_cleanup_evidence.v1`.  The cleanup JSON response reports the
number of manifest entries observed and the cleanup evidence path.  Cleanup
evidence is retained outside the secret run directory so operators can prove
best-effort cleanup without retaining secret files or their manifest.

## 0.18.104 hardening: delivery manifest verification

The fixture broker exposes a read-only `verify-manifest` operation for a delivered secret job directory. It validates that the per-job delivery manifest exists, is mode `0600`, contains only redacted `queuebash.secret_delivery_manifest.v1` rows, includes hashed secret reference/path metadata, and points only inside the expected per-job secret run directory.

Verification emits `queuebash.secret_manifest_verify.v1` with counts for entries, insecure permissions, unsafe paths, missing delivered files, malformed rows, and secret-value marker failures. It never reads or prints the delivered secret file contents. Failed verification returns non-zero and writes a redacted `secret.manifest.verify` audit event.

## 0.18.106 hardening: delivery manifest seal evidence

The fixture provider exposes a read-only manifest sealing operation:

```text
queue secrets seal-manifest QID --json
providers.d/secrets/file_provider.sh seal-manifest QID --json
```

The seal uses schema `queuebash.secret_manifest_seal.v1` and records only
redacted manifest metadata: qid, manifest path, manifest hash, manifest mode,
entry count, creation time, `redacted=true`, and `secret_value_included=false`.
It is stored in the secret audit directory as mode `0600` evidence. The seal is
a tamper-evidence fixture contract for the redacted delivery manifest; it is not
a signing-key or live KMS implementation.

`verify-manifest` reports the current manifest hash and seal status:

```text
seal_status=absent|match|mismatch
```

A mismatched seal fails verification. Verification and sealing must not read,
print, JSON-return, or log the delivered secret file contents.
