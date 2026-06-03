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
