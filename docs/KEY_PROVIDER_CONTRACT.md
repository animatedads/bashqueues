# Key provider registry contract

Version: 0.18.15

Keys, signer trust, delegation, revocation, rotation, and authorisation must be resolved through provider contracts, not hard-coded into command logic.

The core question is:

```text
Can signer S use key material K for operation O on resource R in context C?
```

The provider answers with normalized data:

```text
allow | deny | error
reason
evidence
ttl/cache policy
revocation/delegation status
```

bashqueues core enforces decisions. Providers supply decisions and evidence. Providers never supply shell.

## Provider families

```text
key_provider
  file
  PKI
  Vault/HSM
  IBM HPCS
  Azure Key Vault

trust_provider
  signer trust
  delegation
  revocation
  required signer policy
```

## Command surface

0.18.15 adds a contract command surface:

```bash
queue key-provider help
queue key-provider operations
queue key-provider status [--json]
queue key-provider lookup SIGNER OPERATION RESOURCE [--json]
queue key-provider explain SIGNER OPERATION RESOURCE [--json]
queue key-provider registry [--json]
queue key-provider register SIGNER OPERATION RESOURCE PUBLIC_KEY_REF [--reason TEXT]
queue key-provider revoke SIGNER OPERATION RESOURCE [--reason TEXT]
queue key-provider rotate SIGNER OPERATION RESOURCE NEW_PUBLIC_KEY_REF [--reason TEXT]
```

Aliases `queue trust-provider ...` and `queue keyprovider ...` use the same contract surface.

## Normalized operations

```text
profile.approve
profile.sign
profile.verify
authorisation.generate
authorisation.verify
code.sign
code.verify
trust-provider.add
trust-provider.revoke
trust-provider.verify
key.lookup
key.delegate
key.revoke
key.rotate
policy.override
module.configure
ai.ask
```

## Lookup request

```json
{
  "schema": "queuebash.key_lookup_request.v1",
  "operation": "profile.verify",
  "subject": "hc3",
  "signer": "team:security-review",
  "resource": "profile:goodrexx",
  "purpose": "verify profile approval signature"
}
```

## Lookup response

```json
{
  "schema": "queuebash.key_lookup_response.v1",
  "provider": "file",
  "decision": "allow",
  "reason": "signer trusted for profile.verify",
  "public_key_ref": "sha256:...",
  "status": "active",
  "revoked": false,
  "delegation": "team:security-review",
  "ttl_seconds": 0,
  "cache_policy": "no-store",
  "fail_closed": false,
  "evidence": [
    {
      "policy_file": "/home/hc3/.queuebash/policy/keys/key_registry.tsv",
      "line": 2
    }
  ]
}
```

## File provider

0.18.15 provides a simple local file-backed registry for single-user installs and tests.

Configuration:

```bash
QUEUEBASH_KEY_PROVIDER=file
QUEUEBASH_FILE_KEY_REGISTRY="$HOME/.queuebash/policy/keys/key_registry.tsv"
QUEUEBASH_FILE_KEY_DEFAULT=deny
```

System example:

```bash
QUEUEBASH_KEY_PROVIDER=file
QUEUEBASH_FILE_KEY_REGISTRY=/etc/queuebash/policy/keys/key_registry.tsv
QUEUEBASH_FILE_KEY_DEFAULT=deny
```

TSV format:

```text
# signer<TAB>operation<TAB>resource<TAB>public_key_ref<TAB>status<TAB>delegation<TAB>reason
team:security-review	profile.approve	*	sha256:abc...	active	team:security-review	security reviewers may approve profiles
external:vendor-xyz	profile.approve	*	sha256:def...	revoked	external:vendor-xyz	vendor key revoked
```

Blank lines and comments are ignored.

Matching rules are deterministic:

```text
signer exact beats signer *
operation exact beats operation *
resource exact beats resource *
first most-specific match wins
no active provider -> error/fail_closed
active file provider but no matching rule -> deny/fail_closed
malformed registry -> error/fail_closed
revoked/rotated/expired/disabled -> deny/fail_closed
```

## Design rules

- providers return normalized data only
- providers never return shell
- missing, malformed, or failed provider output fails closed for privileged operations
- single-user installs can use the file provider
- enterprise installs can delegate to LDAP, Microsoft, IBM, PKI, Vault/HSM, Azure Key Vault, or internal governance services
- no secret key material is written to normal policy files
- file registries store public key references, not private keys or API tokens

## Out of scope for 0.18.15

0.18.15 does not implement live PKI, Vault/HSM, IBM HPCS, Azure Key Vault, LDAP, Microsoft, or PAM/NSS key providers. It establishes the normalized command and JSON contract and ships a local file-backed reference provider.
