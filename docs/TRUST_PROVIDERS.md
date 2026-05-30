# Trust Providers

bashqueues treats local key files as one implementation of trust, not as the trust
model itself.

The profile verification assets (`secprofile`, `netprofile`, and `fileprofile`)
now resolve signer policy through a provider boundary. This keeps class gates,
profile approval, and runtime enforcement independent of where an organisation
keeps its authority data.

## Provider responsibilities

A trust provider answers questions such as:

- is this signer trusted for this operation?
- is this profile self-signed, and is that allowed here?
- is this signer delegated for this class, profile, environment, or queue root?
- where is the public key or certificate chain for this signer?
- what policy source made the decision?

## Built-in file provider

The default provider is `file`. It is deliberately small and suitable for local,
lab, packaging, and simple managed deployments.

Default policy file:

```text
/etc/queuebash/policy/trust.conf
```

You can override it with:

```bash
QUEUEBASH_TRUST_POLICY_FILE=/path/to/trust.conf
```

Supported file-provider settings:

```bash
TRUST_PROVIDER=file
TRUST_KEY_ROOT=/etc/queuebash/keys
TRUST_REQUIRED_SIGNERS=ops-release,security-release
TRUST_ALLOWED_SIGNERS=ops-release,security-release,buildbot
TRUST_DENIED_SIGNERS=revoked-key
TRUST_DENY_SELF_SIGNED=1
```

The key root is expected to contain public Ed25519 keys using the existing
bashqueues layout:

```text
$TRUST_KEY_ROOT/public/NAME.ed25519.pub.pem
```

Existing overrides still work and take precedence:

```bash
QUEUEBASH_PROFILE_KEY_ROOT=/path/to/profile/keys
QUEUEBASH_AUTHORISATION_KEY_ROOT=/path/to/authorisation/keys
```

## Exec provider

The `exec` provider is the plugin boundary for enterprise trust systems such as
LDAP, Active Directory, Kerberos/domain services, enterprise PKI, Vault/HSM, or an
internal policy API.

Enable it per process, policy file, or asset argument:

```bash
QUEUEBASH_TRUST_PROVIDER=exec
QUEUEBASH_TRUST_PROVIDER_HELPER=/usr/libexec/queuebash/trust-provider
```

or:

```bash
queue_class_shared_asset secprofile profile_verified PROFILE \
  trust_provider=exec trust_helper=/usr/libexec/queuebash/trust-provider
```

The helper interface is intentionally simple.

### Public key lookup

```bash
trust-provider public-key secprofile SIGNER
trust-provider public-key netprofile SIGNER
trust-provider public-key fileprofile SIGNER
```

The helper prints a readable public-key path on stdout and exits 0. Non-zero exit
means no usable public key is available.

### Signer authorization

```bash
trust-provider signer-allowed secprofile SIGNER \
  self_signed=0 allow_self_signed=0 required_signer=ops-release profile_file=/path/profile.env
```

Exit 0 means allowed. Any non-zero exit means blocked. The provider may log its
own detailed reason to an audit system.


## Microsoft governance provider contract

The Microsoft governance provider is the first enterprise provider contract built
on this boundary. Microsoft systems provide authoritative policy, ACL, key, and
delegation material through Entra ID, Microsoft Graph, SharePoint/Purview, and
Azure Key Vault or Managed HSM. bashqueues consumes constrained provider JSON
and exit-code decisions; it does not execute Microsoft-sourced policy rows as
shell.

See `docs/MS_GOVERNANCE_PROVIDER.md` for the helper contracts:

- `queue-ms-token`
- `queue-ms-policy-resolve`
- `queue-ms-acl-check`
- `queue-ms-key-resolve`

LDAP and PAM.d/NSS providers should use the same response envelope, operation
ACL vocabulary, TTL/cache semantics, and fail-closed behaviour.


## Oracle Cloud Infrastructure governance provider contract

The Oracle Cloud Infrastructure governance provider is the OCI peer of the
Microsoft, LDAP, PAM/NSS, ACL, key, and trust provider contracts. OCI IAM,
dynamic groups, compartments, defined tags, Vault, Audit, Events, Work Requests,
Resource Manager, Cloud Guard, and Security Zones can provide authoritative
policy, ACL, key, posture, and evidence material. bashqueues consumes constrained
provider JSON and exit-code decisions; it does not execute OCI-sourced policy,
tag, compartment, audit, or posture data as shell.

See `docs/OCI_GOVERNANCE_PROVIDER.md` for the helper contracts:

- `queue-oci-auth-context`
- `queue-oci-policy-resolve`
- `queue-oci-acl-check`
- `queue-oci-key-resolve`
- `queue-oci-posture-check`
- `queue-oci-audit-evidence`

The OCI provider keeps single-user installations file-backed by default and makes
live OCI enforcement an explicit later integration step.


## Directory governance provider contracts

LDAP and PAM.d/NSS providers are peers of the Microsoft provider. They let an
enterprise delegate command operation ACLs, class/job permissions, identity
resolution, signer delegation, and account validity checks to existing directory
and host policy systems.

See `docs/DIRECTORY_GOVERNANCE_PROVIDERS.md` for the helper contracts:

- `queue-ldap-acl-check`
- `queue-ldap-policy-resolve`
- `queue-ldap-key-resolve`
- `queue-ldap-identity-check`
- `queue-pam-account-check`
- `queue-pam-session-check`
- `queue-nss-identity-resolve`
- `queue-pam-acl-check`

Microsoft, LDAP, PAM.d/NSS, and file-backed providers should use the same
response envelope, operation ACL vocabulary, TTL/cache semantics, and fail-closed
behaviour. Provider output is normalized data, not executable shell.

## Scope boundary

The runtime seccomp path does not resolve LDAP, AD, PKI, ACLs, or key delegation
itself. It asks the profile verification layer for a verified syscall list. That
keeps runtime enforcement deterministic while letting the trust layer evolve.
