# bashqueues secrets security model

The secret should arrive like a sealed envelope in a locked drawer, not as a
plain environment variable.

## Secret Zero

Default provider implementations should avoid long-lived master tokens. Preferred
identity order is:

1. workload identity, instance principal, resource principal, or managed identity
2. Kerberos, AD, or enterprise service identity
3. short-lived OIDC/JWT from an identity provider
4. cloud-native metadata identity where policy permits
5. file-backed fixture tokens only for development and tests

Provider examples include OCI Instance Principals, AWS IAM role/STS, Azure
Managed Identity, GCP Workload Identity, IBM trusted profiles, and Vault/Kerberos
enterprise identities.

## Runtime controls

Recommended class controls:

```text
CLASS_SECRET_DELIVERY=file
CLASS_SECRET_TMPFS=1
CLASS_SECRET_ENV_ALLOWED=0
CLASS_SECRET_REFRESH_ALLOWED=0
CLASS_DEFAULT_RUNTIME_CAPS=no-ptrace,no-debug,no-network-tools
```

Secret delivery should use a per-job directory with `0700` directory mode and
`0600` file mode. Cleanup must run on success, failure, timeout, and cancel; a
cleanup failure should create a security event.

Do not rely on `shred` for tmpfs. Remove files and unmount tmpfs where mounted.

## TTL

A secret request has a TTL and an expected job/runtime duration. By default the
request must fail if the requested TTL is shorter than the maximum runtime unless
policy explicitly says the secret is startup-only or refresh is allowed.

## Break-glass

Break-glass is a future governed workflow. It must require signed/authorised
approval, reason, ticket, short TTL, mandatory audit, and should still prefer file
delivery. It must not print secret values to terminal or scratchpad by default.

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

## Audit hardening and break-glass boundary

Secret audit evidence is redacted by construction.  The default provider may log
that a class requested a secret reference for a hashed purpose, whether the
request was allowed or denied, and which policy gate made the decision.  It must
not log the delivered secret value, raw purpose text, provider credentials,
terminal reveal output, or scratchpad-ready secret material.

Break-glass is deliberately not implemented as a shortcut in the fixture broker.
A real break-glass provider must be signed/authorised, dual-control, ticketed,
short-lived, audited, and delivery should still prefer file mode.  Until that
provider exists, `queue secrets break-glass ... --json` returns a structured
denial with `authorization_required` and `secret_value_included=false`.
