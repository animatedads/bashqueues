# bashqueues profile multi-signature contract

Version: 0.18.16

This release defines the profile multi-signature contract without forcing a
migration of existing signed interrogation profiles.

The sidecar file is:

```text
profiles/interrogation/NAME/signatures.json
```

The sidecar schema is:

```text
queuebash.profile_signatures.v1
```

Verification responses use:

```text
queuebash.profile_signature_verification.v1
```

## Design principles

- Existing signed profiles continue to work.
- Multi-signature metadata lives beside the profile in `signatures.json`.
- Signer trust is resolved through key/trust provider contracts, not hard-coded
  file-only logic.
- This release validates structure and required signer policy only. It does not
  perform cryptographic verification yet.
- Provider output remains data only. Providers never supply shell.
- Missing, malformed, or policy-failing signature metadata fails closed for
  privileged approval decisions.

## Signer namespaces

Supported signer namespaces are:

```text
self:NAME
team:NAME
org:NAME
external:NAME
trusted-ca:NAME
```

Examples:

```text
self:hc3
team:security-review
org:bashqueues
external:vendor-name
trusted-ca:root
```

## Roles

Supported signature roles are:

```text
author
reviewer
approver
countersigner
issuer
auditor
```

## Sidecar example

```json
{
  "schema": "queuebash.profile_signatures.v1",
  "profile": "goodrexx",
  "artifact_sha256": "0000000000000000000000000000000000000000000000000000000000000000",
  "signatures": [
    {
      "signer": "self:hc3",
      "role": "author",
      "alg": "ed25519",
      "public_key_sha256": "1111111111111111111111111111111111111111111111111111111111111111",
      "signature_b64": "ZmFrZS1zaWduYXR1cmU=",
      "signed_at": "2026-05-27T12:00:00Z",
      "key_provider_ref": "file:self:hc3:profile.sign:goodrexx"
    },
    {
      "signer": "team:security-review",
      "role": "reviewer",
      "alg": "ed25519",
      "public_key_sha256": "2222222222222222222222222222222222222222222222222222222222222222",
      "signature_b64": "ZmFrZS1yZXZpZXctc2lnbmF0dXJl",
      "signed_at": "2026-05-27T12:30:00Z"
    }
  ]
}
```

## Required signer policy

A required-signer policy is TSV:

```text
profile_glob<TAB>role<TAB>signer_pattern<TAB>required<TAB>reason
```

Example:

```text
*       author          self:*                  required        profile must have an author signature
*       reviewer        team:security-review    required        security team review required
prod-*  approver        org:bashqueues          required        production profiles require org approval
vendor-* countersigner  org:bashqueues          required        external vendor signatures need local countersign
```

Canonical policy locations for examples are under:

```text
~/.queuebash/policy/profile-signatures/
/etc/queuebash/policy/profile-signatures/
```

Do not use the legacy bashqueues system path namespace.

## Command surface

```bash
queue profile-signature help
queue profile-signature schema
queue profile-signature roles
queue profile-signature verify PROFILE_DIR [--policy FILE] [--json]
queue profile-signature explain PROFILE_DIR [--policy FILE] [--json]
queue profile-signature required-policy-example
```

Aliases:

```bash
queue profile-signatures ...
queue profile-sig ...
queue profile-multisig ...
queue multisig ...
```

## Verification result contract

```json
{
  "schema": "queuebash.profile_signature_verification.v1",
  "decision": "allow",
  "reason": "profile_signatures_contract_valid",
  "profile": "goodrexx",
  "fail_closed": false,
  "contract_only": true,
  "cryptographic_verification_performed": false,
  "migration_required": false
}
```

A missing required signer returns `deny` and `fail_closed=true`. Malformed
sidecars return `error` and `fail_closed=true`.

## Future work

Later packages may add cryptographic verification, profile approval enforcement,
key-provider lookup, revocation checks, rotation workflows, countersigning flows,
and migration helpers. Those are intentionally not forced in 0.18.16.

## 0.18.17 file verifier layer

`queue profile-signature verify PROFILE_DIR [--policy FILE] [--json]` is now a
practical file verifier rather than a schema-only checker.

It performs these checks:

- reads `PROFILE_DIR/signatures.json`
- validates the `queuebash.profile_signatures.v1` sidecar structure
- validates signer namespaces and roles
- reads optional required-signer TSV policy
- checks required signer/role presence
- consults the key-provider registry contract for each signer using operation
  `profile.sign` and resource equal to the profile directory basename

The verifier remains deliberately conservative:

- it does not force migration of older profiles
- it does not execute provider-supplied shell
- it fails closed on missing or malformed key-provider trust
- it does not perform cryptographic signature verification in 0.18.17

Expected output includes:

```json
{
  "schema": "queuebash.profile_signature_verification.v1",
  "file_verifier": true,
  "key_provider_consulted": true,
  "cryptographic_verification_performed": false,
  "cryptographic_verification_status": "not_performed"
}
```
