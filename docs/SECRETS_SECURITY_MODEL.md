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

## 0.18.106 hardening: manifest tamper evidence

Secret delivery manifests can be sealed after delivery by hashing the redacted
manifest and writing a `queuebash.secret_manifest_seal.v1` evidence file under
the audit directory. This provides fixture-level tamper evidence without turning
bashqueues into a secret store or requiring a live signing provider.

The seal contains no secret value, no raw purpose text, and no raw secret
reference. If the manifest changes after sealing, `verify-manifest` reports
`seal_status="mismatch"` and fails closed. If no seal exists, verification
reports `seal_status="absent"`; operators may then choose to seal before cleanup
where evidence retention is required.

### Seal verification hardening

`verify-manifest` also validates the retained manifest seal when one exists. A seal is trusted only when it is mode `0600`, uses `queuebash.secret_manifest_seal.v1`, remains redacted, declares `secret_value_included=false`, contains a manifest hash, points at the same per-job manifest path, and names the same QID being verified.

The verifier reports these seal evidence fields in `queuebash.secret_manifest_verify.v1`:

```json
{
  "seal_status": "absent|match|mismatch|invalid",
  "seal_mode": "600",
  "seal_schema_ok": 1,
  "seal_redacted_ok": 1,
  "seal_secret_value_marker_ok": 1,
  "seal_manifest_path_ok": 1,
  "seal_qid_ok": 1,
  "seal_hash_present": 1
}
```

A seal whose hash no longer matches the manifest is `mismatch`. A seal with unsafe permissions, wrong schema, missing redaction markers, missing hash, wrong manifest path, or wrong QID is `invalid`. Both conditions make verification fail closed without reading or printing secret values.

### Manifest row integrity verification

`verify-manifest` also validates the integrity of each redacted delivery row. Every row must name the requested QID, include non-empty `secret_ref_hash` and `path_hash` fields, and the `path_hash` must match the hash of the recorded delivery path. A row with a mismatched QID, missing hash metadata, or altered path hash is treated as malformed evidence and causes verification to fail closed. The JSON evidence reports `qid_mismatches`, `missing_hashes`, and `path_hash_mismatches`; it still never reads or returns secret values.
