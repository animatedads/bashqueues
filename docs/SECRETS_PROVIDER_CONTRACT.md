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
