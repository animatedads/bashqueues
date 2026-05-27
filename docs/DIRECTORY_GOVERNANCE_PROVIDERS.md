# Directory Governance Provider Contracts

This document defines the LDAP and PAM.d/NSS provider contracts for bashqueues
enterprise installations. These contracts are siblings of the Microsoft
provider contract and use the same normalized provider envelope introduced by
the trust-provider boundary.

The goal is simple:

```text
Enterprise installations may delegate governance to existing directory,
authentication, and account-policy systems.
Single-user installations remain simple and file-backed.
```

LDAP and PAM.d/NSS provider output is data, not shell. bashqueues consumes
constrained JSON and exit-code decisions, validates the schema, and fails closed
on malformed, missing, stale, or denied provider output.

## Canonical paths

Use the queuebash namespace:

```text
/etc/queuebash/policy/providers.d/ldap.env
/etc/queuebash/policy/providers.d/pam.env
/var/cache/queuebash/ldap/
/var/cache/queuebash/pam/
/usr/libexec/queuebash/providers/ldap/
/usr/libexec/queuebash/providers/pam/
```

Do not introduce a parallel legacy plural namespace for new provider work.

## Shared provider envelope

All JSON helpers should use this response envelope:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "ldap",
  "decision": "allow",
  "reason": "subject is a member of the required LDAP group",
  "evidence": {
    "source": "ldap:groupMembership",
    "directory": "corp.example.com"
  },
  "ttl_seconds": 300
}
```

Valid decisions are:

```text
allow
deny
error
```

`deny` and `error` both block. `error` means the provider could not produce a
valid decision. Stale, malformed, missing, unsigned, or schema-invalid provider
output blocks.

## Shared operation ACL vocabulary

Providers should answer the same operation questions, regardless of whether the
backing system is LDAP, PAM.d, Microsoft Entra, local files, or another provider.

Common operations:

```text
job.submit
job.cancel
job.clear
queue.clear
profile.approve
profile.verify
profile.sign
class.manage
policy.override
dev.patch
dev.extract
dev.flow
reporter.manage
provider.configure
```

The normalized question is:

```text
Can subject X perform operation Y on resource Z in context C?
```

A single-user file-backed installation may answer this locally. An enterprise
installation may map operations to LDAP groups, PAM account policy, NSS identity,
domain roles, or a higher-level provider.

## LDAP provider contract

The LDAP provider is intended for organisations where directory groups, OUs, or
roles are authoritative for command ACLs, class ACLs, signer delegation, or
profile approval.

### LDAP configuration

Example location:

```text
/etc/queuebash/policy/providers.d/ldap.env
```

Example content:

```bash
QUEUEBASH_LDAP_PROVIDER=1
QUEUEBASH_LDAP_URI="ldaps://ldap.example.com"
QUEUEBASH_LDAP_BASE_DN="dc=example,dc=com"
QUEUEBASH_LDAP_BIND_DN="cn=queuebash-reader,ou=service,dc=example,dc=com"
QUEUEBASH_LDAP_BIND_PASSWORD_FILE="/etc/queuebash/policy/providers.d/ldap.bind.secret"
QUEUEBASH_LDAP_USER_FILTER="(&(objectClass=person)(uid={subject}))"
QUEUEBASH_LDAP_GROUP_FILTER="(&(objectClass=groupOfNames)(member={dn}))"
QUEUEBASH_LDAP_ACL_GROUP_PREFIX="BQ_"
QUEUEBASH_LDAP_CACHE_DIR="/var/cache/queuebash/ldap"
QUEUEBASH_LDAP_CACHE_TTL_SECONDS=300
```

Use LDAPS or a protected local channel. Secrets should be readable only by the
provider helper account.

### LDAP helper commands

```text
queue-ldap-acl-check
queue-ldap-policy-resolve
queue-ldap-key-resolve
queue-ldap-identity-check
```

The helpers may be implemented in Python, Go, Perl, or another controlled
runtime. Their output is JSON; their failure mode is fail-closed.

### LDAP ACL checker

Example invocation:

```bash
queue-ldap-acl-check \
  --subject alice \
  --operation profile.approve \
  --resource profile:goodrexx \
  --class SECURE_PROFILED
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "ldap",
  "decision": "allow",
  "subject": "alice",
  "operation": "profile.approve",
  "resource": "profile:goodrexx",
  "class": "SECURE_PROFILED",
  "groups": ["BQ_Profile_Approvers", "BQ_Ops"],
  "reason": "subject is a member of the required LDAP approval group",
  "evidence": {
    "source": "ldap:groupMembership",
    "base_dn": "dc=example,dc=com"
  },
  "ttl_seconds": 300
}
```

### LDAP policy resolver

Purpose: resolve class/job required assets from LDAP attributes or group metadata
without returning executable shell.

Example invocation:

```bash
queue-ldap-policy-resolve \
  --class CLOUD_COMPUTE_GDPR \
  --operation job.submit \
  --subject alice
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "ldap",
  "decision": "allow",
  "class": "CLOUD_COMPUTE_GDPR",
  "operation": "job.submit",
  "required_assets": [
    {
      "asset": "legal",
      "facility": "retention_respected",
      "args": ["datasetScope=GDPR"]
    },
    {
      "asset": "sovereign",
      "facility": "framework_allowed",
      "args": ["GDPR"]
    }
  ],
  "evidence": {
    "source": "ldap:classPolicyAttribute",
    "object": "cn=BQ_Class_CLOUD_COMPUTE_GDPR,ou=queuebash,dc=example,dc=com"
  },
  "ttl_seconds": 300
}
```

### LDAP key and delegation resolver

LDAP may provide signer delegation, public key locations, certificate
fingerprints, or a pointer to an enterprise PKI. It should not print private key
material.

Example invocation:

```bash
queue-ldap-key-resolve \
  --purpose profile-public-key \
  --signer ops-release \
  --class SECURE_PROFILED
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "ldap",
  "decision": "allow",
  "purpose": "profile-public-key",
  "signer": "ops-release",
  "public_key_ref": "file:/etc/queuebash/policy/provider-cache/ldap/ops-release.ed25519.pub.pem",
  "public_key_sha256": "sha256-hex-here",
  "delegation": {
    "scope": "profile:SECURE_PROFILED",
    "source": "ldap:delegationAttribute"
  },
  "ttl_seconds": 300
}
```

## PAM.d / NSS provider contract

The PAM.d/NSS provider is intended for host and domain identity checks that are
already expressed in standard Linux account policy: locked accounts, expired
passwords, disabled logins, NSS identity resolution, or PAM account/session
rules.

PAM.d is usually best for identity/account eligibility decisions, not for
returning complex policy rows. It should answer whether a subject is valid and
eligible to perform a local operation in the current host context.

### PAM configuration

Example location:

```text
/etc/queuebash/policy/providers.d/pam.env
```

Example content:

```bash
QUEUEBASH_PAM_PROVIDER=1
QUEUEBASH_PAM_SERVICE="queuebash"
QUEUEBASH_PAM_NSS_REQUIRED=1
QUEUEBASH_PAM_CACHE_DIR="/var/cache/queuebash/pam"
QUEUEBASH_PAM_CACHE_TTL_SECONDS=60
```

A package may install a sample PAM service file such as:

```text
/etc/pam.d/queuebash
```

The service file is distribution- and site-specific. It may delegate to local
accounts, SSSD, LDAP, Kerberos, Active Directory, or another PAM stack.

### PAM helper commands

```text
queue-pam-account-check
queue-pam-session-check
queue-nss-identity-resolve
queue-pam-acl-check
```

### PAM account checker

Example invocation:

```bash
queue-pam-account-check \
  --subject alice \
  --operation job.submit \
  --service queuebash
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "pam",
  "decision": "allow",
  "subject": "alice",
  "operation": "job.submit",
  "service": "queuebash",
  "reason": "PAM account phase allowed the subject",
  "evidence": {
    "source": "pam:account",
    "nss_uid": "1001"
  },
  "ttl_seconds": 60
}
```

### NSS identity resolver

Example invocation:

```bash
queue-nss-identity-resolve --subject alice
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "pam",
  "decision": "allow",
  "subject": "alice",
  "uid": 1001,
  "gid": 1001,
  "home": "/home/alice",
  "shell": "/bin/bash",
  "reason": "subject resolved through NSS",
  "evidence": {
    "source": "nss:getpwnam"
  },
  "ttl_seconds": 60
}
```

### PAM ACL checker

PAM may also act as an ACL bridge when the site encodes command operation policy
in PAM modules, SSSD access providers, or account rules.

Example invocation:

```bash
queue-pam-acl-check \
  --subject alice \
  --operation dev.patch \
  --resource source:queuebash.sh \
  --service queuebash-dev
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "pam",
  "decision": "allow",
  "subject": "alice",
  "operation": "dev.patch",
  "resource": "source:queuebash.sh",
  "service": "queuebash-dev",
  "reason": "PAM service allowed the requested operation",
  "evidence": {
    "source": "pam:account",
    "service": "queuebash-dev"
  },
  "ttl_seconds": 60
}
```

## Validation rules

Provider output must satisfy these rules before bashqueues consumes it:

- `schema` must be `queuebash.provider.v1`.
- `provider` must be the expected provider name.
- `decision` must be `allow`, `deny`, or `error`; only `allow` permits the
  operation.
- `ttl_seconds`, when present, must be an integer and must not exceed the
  configured maximum for that provider.
- `operation` values must come from the shared operation vocabulary or a
  site-configured extension allow-list.
- `required_assets[].asset` and `required_assets[].facility` must match
  bashqueues asset syntax.
- `required_assets[].args` must be an array of strings.
- provider output is never evaluated as shell.

## Fail-closed requirements

LDAP and PAM.d/NSS providers must fail closed when:

- the helper is missing or not executable;
- the directory, PAM service, or NSS lookup is unavailable;
- JSON is malformed or has the wrong schema;
- `decision` is absent or not `allow`;
- the output is stale beyond `ttl_seconds` or an explicit expiry;
- the subject cannot be resolved;
- the provider says the subject lacks the required operation ACL;
- the provider returns executable code instead of normalized data.

## Relationship to Microsoft and file providers

The directory providers are not special inside bashqueues. They are peers of the
Microsoft provider and the default file provider. Microsoft, LDAP, PAM.d/NSS, and
file-backed providers should use the same response envelope, operation ACL
vocabulary, TTL/cache semantics, and fail-closed behaviour.

This is what lets enterprise installations plug into existing governance tools
while single-user installations remain simple and unaware of the enterprise
backplate.
