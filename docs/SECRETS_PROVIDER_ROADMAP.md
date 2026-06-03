# Secrets provider broker roadmap

Status: roadmap handoff, contract-first. This document records the accepted direction for a future secrets provider package. It is not a runtime implementation and it does not introduce live secret access.

## Lane allocation

The secrets provider broker belongs to Bob17, because it sits beside cloud/resource/policy-gated lifecycle and remote-dependency controls. Bob14 may later add fixture-first provider-family packs for specific secret-manager backends, but must not implement the runtime secret broker, job wrapper secret delivery, break-glass workflows, or cleanup hooks unless explicitly assigned.

Bob15 should merge this handoff carefully and prevent display/resource surfaces from rendering secret values.


## Implemented follow-up contract

Bob17 has now supplied the first contract/fixture implementation under `providers.d/secrets/`. This does not change the roadmap boundary that bashqueues must not become the secret store: the helper exposes a governed provider contract and fixture/file-backed broker shape, with redacted normalized metadata and tests. Live Vault/cloud-provider integrations, job-wrapper secret delivery, and production break-glass operation remain separately gated future work.

## Design verdict

bashqueues must not become the secret store. It should become a governed secret access broker that consumes provider-backed secrets through normalized contracts and exposes only redacted delivery metadata to jobs and operators.

Provider examples include HashiCorp Vault, AWS Secrets Manager, OCI Vault, Azure Key Vault, GCP Secret Manager, IBM Secrets Manager, LDAP/AD/Kerberos-backed enterprise systems, and file-backed fixture providers for local tests.

## Default delivery contract

Preferred default:

```text
QUEUEBASH_SECRET_DELIVERY=file
QUEUEBASH_SECRET_<NAME>_FILE=/run/queuebash/secrets/<qid>/<name>
```

Environment-value delivery must be explicit and exceptional. The default should never expose:

```text
QUEUEBASH_SECRET_<NAME>=actual-secret-value
```

Supported delivery modes:

| Mode | Status | Notes |
| --- | --- | --- |
| file | preferred | per-job file, ideally tmpfs-backed, 0600, job-visible by path |
| fd | stronger later | open file descriptor passed to a wrapper |
| env | discouraged | only for tools that cannot read files; explicit policy required |

## Provider architecture direction

Suggested future family:

```text
providers.d/secrets/
  secrets_provider.sh
  file_provider.sh
  vault_provider.sh
  aws_secrets_provider.sh
  oci_vault_provider.sh
  azure_keyvault_provider.sh
  gcp_secret_provider.sh
  ibm_secrets_provider.sh
```

Policy/config examples:

```text
policies.d/secrets/default.env.example
policies.d/secrets/providers.tsv.example
policies.d/secrets/secret-acl.tsv.example
policies.d/secrets/class-bindings.tsv.example
policies.d/secrets/break-glass.example.env
```

Optional asset helper if cleanly additive:

```text
assets.d/secrets.sh
```

## Normalized request and response

A job requests a governed secret reference, not a raw provider-specific path.

Request shape:

```json
{
  "schema": "queuebash.secret_request.v1",
  "qid": "20260603_...",
  "class": "DB_MIGRATION",
  "requester": "alice",
  "secret_ref": "customer-db/prod/password",
  "purpose": "approved database migration",
  "delivery": "file",
  "ttl_seconds": 1800,
  "policy_context": {
    "change_ticket": "CHG-12345",
    "reason": "approved migration window",
    "data_classification": "customer",
    "region": "uk-london-1"
  }
}
```

Provider result shape:

```json
{
  "schema": "queuebash.secret_provider.result.v1",
  "status": "ok",
  "provider": "oci-vault",
  "secret_ref": "customer-db/prod/password",
  "delivery": "file",
  "path": "/run/queuebash/secrets/20260603_xxx/db_password",
  "ttl_until": "2026-06-03T23:30:00Z",
  "audit_id": "sec-evt-...",
  "redacted": true
}
```

The result must never include the secret value.

## Secret Zero

Do not solve Secret Zero with a long-lived master token in `/etc/bashqueues`.

Preferred identity order:

1. workload identity / instance principal / managed identity
2. Kerberos / AD service identity
3. short-lived OIDC/JWT from enterprise identity provider
4. cloud-native metadata identity where policy allows
5. file-backed dev token only for local fixture tests

Cloud mapping examples:

| Platform | Preferred identity direction |
| --- | --- |
| OCI | Instance Principals / Resource Principals |
| AWS | IAM role / STS |
| Azure | Managed Identity |
| GCP | Workload Identity / service account token |
| IBM | Trusted profile / service identity |

## Runtime controls

Future runtime controls should enforce or strongly recommend:

- no-ptrace
- no-debug
- no-secret-env by default
- no-shell-history
- redacted logging
- tmpfs/file delivery
- per-job secret directory
- 0600 file mode
- ownership by job runner identity
- cleanup on success, failure, timeout, and panic
- security event on cleanup failure

Secret TTL must be compatible with the job/class maximum runtime unless a class explicitly allows refresh or startup-only secret use.

## Break-glass direction

Break-glass must be supported only through a deliberately high-friction workflow:

```text
queue secrets break-glass request SECRET_REF --reason TEXT --ticket ID
queue secrets break-glass approve REQUEST_ID --authorisation CODE
queue secrets break-glass deliver REQUEST_ID --delivery file
```

Rules:

- signed or dual-control authorisation
- mandatory reason and ticket
- short TTL
- audit event always
- prefer file delivery
- no terminal reveal by default
- never write secrets to scratchpad

## Command-surface direction

Future contract-first command family:

```text
queue secrets providers --json
queue secrets explain SECRET_REF --class CLASS --json
queue secrets request SECRET_REF --class CLASS --purpose TEXT --delivery file --json
queue secrets revoke QID SECRET_NAME --json
queue secrets cleanup QID --json
queue secrets audit --since 24h --json
```

Provider helper side:

```text
providers.d/secrets/secrets_provider.sh explain SECRET_REF --json
providers.d/secrets/secrets_provider.sh request REQUEST_JSON --json
providers.d/secrets/secrets_provider.sh cleanup QID --json
```

Later job submission shape:

```text
queue submit migrate_customers \
  --class DB_MIGRATION \
  --secret db_password=customer-db/prod/password \
  -- bash ./migrate.sh --password-file "$QUEUEBASH_SECRET_DB_PASSWORD_FILE"
```

The secret path variable must be expanded inside the job wrapper, not in the submission shell.

## Acceptance-test direction

First Bob17 package should be fixture-first and prove:

1. file-backed fixture provider returns normalized redacted JSON
2. secret value never appears in stdout, stderr, log, scratchpad, docs, examples, zips, or command lines
3. file delivery creates 0600 secret file under a per-job secret directory
4. cleanup removes files and records redacted evidence
5. denied class cannot request secret
6. denied purpose cannot request secret
7. TTL too short blocks request
8. env delivery denied by default
9. break-glass requires authorisation
10. no live cloud/Vault calls in default tests

## Safety boundary

This roadmap is not an implementation. It must not be used as evidence that bashqueues currently delivers or brokers secrets. Until Bob17 implements and tests the package, secrets support remains roadmap-only except for fixture-first provider-family service coverage already present under Bob14's secret-manager advisory family.
