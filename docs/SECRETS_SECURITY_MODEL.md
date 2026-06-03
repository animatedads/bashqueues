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
