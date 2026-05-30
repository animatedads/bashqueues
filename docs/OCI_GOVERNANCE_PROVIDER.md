# Oracle Cloud Infrastructure Governance Provider Contract

This document defines the Oracle Cloud Infrastructure provider contract for
bashqueues enterprise installations. It is a contract and integration boundary,
not a live OCI SDK, CLI, Vault, IAM, Cloud Guard, Resource Manager, or Events
implementation.

The OCI provider is a peer of the Microsoft, LDAP, PAM/NSS, ACL, key, and trust
provider contracts. Oracle Cloud Infrastructure may provide authoritative policy,
ACL, key, identity, compartment, tagging, posture, and audit evidence decisions,
but bashqueues consumes only constrained normalized provider output and remains
fail-closed.

## Design rule

OCI-sourced governance is data, not shell.

Provider helpers must return normalized JSON or simple exit-code decisions.
bashqueues must never execute IAM policies, compartment names, tag values,
Cloud Guard problem text, Resource Manager outputs, Object Storage object names,
Vault metadata, work-request logs, or Events payloads as shell code.

## Oracle reference basis

This contract is intentionally mapped to stable OCI primitives:

- IAM policies, compartments, dynamic groups, instance principals, and resource
  principals.
- Vault keys, secrets, certificates, and key-version metadata.
- Audit log events for API activity evidence.
- Events for resource lifecycle and CRUD event routing.
- Work Requests for long-running operation state and diagnostics.
- Cloud Guard and Security Zones for posture evidence and governance findings.
- Resource Manager jobs/stacks for IaC operation evidence where used.

The provider contract does not require every installation to enable every OCI
service. A small single-user installation may use local file providers. A larger
OCI tenancy may use this provider to ask OCI for narrow, auditable decisions.

## Canonical paths

Use the queuebash namespace:

```text
/etc/queuebash/policy/providers.d/oci.env
/var/cache/queuebash/oci/
/usr/libexec/queuebash/providers/oci/
```

Do not introduce a parallel legacy plural namespace for new provider work.

## Provider components

An OCI-dominated organisation normally has these authoritative systems:

- OCI IAM for users, groups, dynamic groups, compartments, policies, and identity
  domain context.
- Instance principals and resource principals for workload identity.
- Defined tags, free-form tags, compartments, and tenancy metadata for governance
  routing.
- OCI Vault for keys, secrets, certificates, wrapping, and key-version state.
- Audit, Logging, Events, Work Requests, and Resource Manager jobs for evidence.
- Cloud Guard and Security Zones for security posture and guardrail evidence.
- Object Storage for signed manifests, evidence bundles, exported logs, or
  provider cache material where policy permits.

bashqueues should not own that truth. It should ask provider helpers for the
small decision it needs at the point of enforcement.

## Configuration file

Example location:

```text
/etc/queuebash/policy/providers.d/oci.env
```

Example content:

```bash
QUEUEBASH_OCI_PROVIDER=1
QUEUEBASH_OCI_TENANCY_OCID="ocid1.tenancy.oc1..example"
QUEUEBASH_OCI_REGION="uk-london-1"
QUEUEBASH_OCI_PROFILE="DEFAULT"

# Authentication mode: config_file, instance_principal, resource_principal,
# delegation_token, security_token, or external_helper.
QUEUEBASH_OCI_AUTH_MODE="instance_principal"
QUEUEBASH_OCI_CONFIG_FILE="/etc/queuebash/policy/providers.d/oci.config"
QUEUEBASH_OCI_DELEGATION_TOKEN_FILE="/etc/queuebash/policy/providers.d/oci.delegation_token"

# Governance scoping.
QUEUEBASH_OCI_COMPARTMENT_ROOT_OCID="ocid1.compartment.oc1..example"
QUEUEBASH_OCI_REQUIRED_DEFINED_TAG_NAMESPACE="queuebash"
QUEUEBASH_OCI_CLASS_TAG_KEY="class"
QUEUEBASH_OCI_ENV_TAG_KEY="environment"

# Provider sources.
QUEUEBASH_OCI_POLICY_SOURCE="iam:policy+tags+compartment"
QUEUEBASH_OCI_ACL_SOURCE="iam:group+dynamic-group+compartment"
QUEUEBASH_OCI_KEY_SOURCE="vault"
QUEUEBASH_OCI_POSTURE_SOURCE="cloud-guard"
QUEUEBASH_OCI_AUDIT_SOURCE="audit+events+work-requests"

# Cache and helper roots.
QUEUEBASH_OCI_CACHE_DIR="/var/cache/queuebash/oci"
QUEUEBASH_OCI_CACHE_TTL_SECONDS=300
QUEUEBASH_OCI_HELPER_DIR="/usr/libexec/queuebash/providers/oci"
```

Secrets and OCI config files must be readable only by the account that runs the
provider helpers. Where possible, prefer instance principal, resource principal,
security token, delegation token, or an enterprise secret broker instead of long
lived local user API keys.

## Helper commands

The helper commands are intentionally separate from hot-path shell logic:

```text
queue-oci-auth-context
queue-oci-policy-resolve
queue-oci-acl-check
queue-oci-key-resolve
queue-oci-posture-check
queue-oci-audit-evidence
```

They may be implemented in Python, Go, shell that calls `oci`, or another
controlled runtime, but their output contract is JSON and their failure semantics
are fail-closed.

### Common response envelope

All JSON helpers should follow this envelope:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "oci",
  "decision": "allow",
  "reason": "human readable short reason",
  "evidence": {
    "source": "iam",
    "request_id": "provider-request-id-or-empty",
    "compartment_id": "ocid1.compartment.oc1..redacted-or-stable-id"
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
valid decision. Stale, malformed, missing, unsigned, expired, or schema-invalid
provider output blocks.

## Auth context helper

Purpose: identify which OCI authentication mode and tenancy/compartment context
will be used by other provider helpers without printing sensitive credentials.

Example invocations:

```bash
queue-oci-auth-context --operation job.submit --class CLOUD_OCI_GOVERNED
queue-oci-auth-context --operation key.resolve --purpose profile-public-key
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "oci",
  "decision": "allow",
  "auth_mode": "instance_principal",
  "tenancy_id": "ocid1.tenancy.oc1..redacted-or-stable-id",
  "region": "uk-london-1",
  "principal_type": "instance",
  "principal_id": "ocid1.instance.oc1.uk-london-1.redacted",
  "evidence": {
    "source": "iam",
    "dynamic_group": "queuebash-workers"
  },
  "ttl_seconds": 300
}
```

The helper must not print private keys, session tokens, security tokens,
delegation tokens, resource principal session tokens, or raw config files.

## Policy resolver

Purpose: resolve class/job policy requirements from OCI IAM, compartments, tags,
Cloud Guard posture, or controlled policy objects without returning executable
shell.

Example invocation:

```bash
queue-oci-policy-resolve \
  --class CLOUD_OCI_GOVERNED \
  --operation job.submit \
  --subject alice@example.com \
  --compartment ocid1.compartment.oc1..example \
  --job-file /var/lib/queuebash/system/pending/job.job
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "oci",
  "decision": "allow",
  "class": "CLOUD_OCI_GOVERNED",
  "operation": "job.submit",
  "compartment_id": "ocid1.compartment.oc1..redacted-or-stable-id",
  "required_assets": [
    {
      "asset": "legal",
      "facility": "retention_respected",
      "args": ["datasetScope=OCI", "region=uk-london-1"]
    },
    {
      "asset": "finops",
      "facility": "anomaly_free",
      "args": ["provider=oci", "block_on=error"]
    },
    {
      "asset": "integrity",
      "facility": "manifest_verified",
      "args": ["/etc/queuebash/manifests/oci.manifest"]
    }
  ],
  "evidence": {
    "source": "iam:policy+defined-tags",
    "tag_namespace": "queuebash",
    "work_request_id": ""
  },
  "ttl_seconds": 300
}
```

Validation rules:

- `asset` and `facility` must match bashqueues asset-name syntax.
- `args` must be an array of strings.
- Unknown assets or facilities block unless the class explicitly allows deferred
  provider validation.
- No returned value is evaluated as shell.
- OCI policy statements and tag values may explain why a decision was made, but
  they are never directly spliced into class files or executed.

## ACL checker

Purpose: answer whether a subject, group, dynamic group, instance principal, or
resource principal may perform an operation on a class, profile, queue root, job,
compartment, tag namespace, or governance resource.

Example operation identifiers:

```text
job.submit
job.cancel
job.clear
queue.clear
profile.approve
profile.verify
class.manage
dev.patch
policy.override
provider.oci.audit.read
provider.oci.vault.key.read
```

Example invocation:

```bash
queue-oci-acl-check \
  --subject alice@example.com \
  --operation profile.approve \
  --resource SECURITY_OFFICIAL \
  --compartment ocid1.compartment.oc1..example
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "oci",
  "decision": "allow",
  "subject": "alice@example.com",
  "operation": "profile.approve",
  "resource": "SECURITY_OFFICIAL",
  "principal_type": "user",
  "matched_groups": ["QueuebashSecurityApprovers"],
  "matched_dynamic_groups": [],
  "compartment_id": "ocid1.compartment.oc1..redacted-or-stable-id",
  "evidence": {
    "source": "iam:group+policy",
    "policy_statement_id": "redacted-or-stable-id"
  },
  "ttl_seconds": 300
}
```

Deny response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "oci",
  "decision": "deny",
  "subject": "instance:ocid1.instance.oc1.uk-london-1.redacted",
  "operation": "dev.patch",
  "resource": "queuebash.sh",
  "principal_type": "instance",
  "reason": "dynamic group may run DEV_TEST_RUNNER jobs but may not patch source",
  "evidence": {
    "source": "iam:dynamic-group+policy",
    "dynamic_group": "queuebash-workers"
  },
  "ttl_seconds": 120
}
```

## Key resolver

Purpose: resolve public keys, certificate chains, signing metadata, Vault key
references, or wrapping-key references for profile signatures, job authorization,
authorisation stamps, and package integrity.

Example invocation:

```bash
queue-oci-key-resolve \
  --purpose profile-public-key \
  --signer security-release \
  --profile SECURITY_OFFICIAL
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "oci",
  "decision": "allow",
  "purpose": "profile-public-key",
  "signer": "security-release",
  "key_ref": "oci-vault://ocid1.vault.oc1..redacted/keys/security-release/versions/current",
  "public_key_ref": "cache:/var/cache/queuebash/oci/keys/security-release.ed25519.pub.pem",
  "algorithm": "Ed25519",
  "not_after": "2026-12-31T23:59:59Z",
  "evidence": {
    "source": "vault",
    "vault_id": "ocid1.vault.oc1..redacted",
    "key_id": "ocid1.key.oc1..redacted"
  },
  "ttl_seconds": 300
}
```

The key resolver must not print private key material, secret values, vault
plaintext, or unwrapped data keys. It may print stable references to helper-owned
cache paths with strict permissions.

## Posture checker

Purpose: let a class require security posture evidence before queueing or running
jobs. The helper can consult Cloud Guard, Security Zones, Audit, Logging, Events,
or a locally cached posture export.

Example invocation:

```bash
queue-oci-posture-check \
  --class CLOUD_OCI_GOVERNED \
  --operation job.submit \
  --compartment ocid1.compartment.oc1..example \
  --require cloud_guard_open_problems=0
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "oci",
  "decision": "allow",
  "operation": "job.submit",
  "class": "CLOUD_OCI_GOVERNED",
  "posture": {
    "cloud_guard_open_problems": 0,
    "security_zone_violations": 0,
    "audit_window_minutes": 60
  },
  "evidence": {
    "source": "cloud-guard+audit",
    "target_id": "ocid1.cloudguardtarget.oc1..redacted"
  },
  "ttl_seconds": 300
}
```

If the posture helper cannot query Cloud Guard or the configured cache is stale,
it must return `decision=error`, not allow by default.

## Audit evidence helper

Purpose: return bounded, redacted evidence for a bashqueues decision without
stuffing raw OCI logs into the queue output or scratchpad.

Example invocation:

```bash
queue-oci-audit-evidence \
  --operation job.submit \
  --job-id 20260529_101500_000001 \
  --since 2026-05-29T09:00:00Z \
  --compartment ocid1.compartment.oc1..example
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "oci",
  "decision": "allow",
  "operation": "job.submit",
  "evidence_bundle_ref": "oci-audit://2026-05-29/job.submit/20260529_101500_000001",
  "summary": {
    "audit_events": 3,
    "events": 1,
    "work_requests": 0,
    "redactions": ["principalEmail", "sourceIpAddress"]
  },
  "evidence": {
    "source": "audit+events",
    "compartment_id": "ocid1.compartment.oc1..redacted-or-stable-id"
  },
  "ttl_seconds": 300
}
```

Large raw logs should be stored outside the scratchpad and referenced by bounded
file paths, object references, or evidence bundle IDs. Provider helpers must
redact secrets, bearer tokens, private key fragments, object pre-authenticated
request URLs, and raw customer data by default.

## Cache rules

- Cache only normalized provider decisions or redacted evidence summaries.
- Cache entries must carry provider, schema, operation, subject/resource, OCI
  region, compartment, timestamp, TTL, and source evidence fields.
- Expired cache entries block unless the calling class explicitly permits a stale
  read-only advisory mode.
- Cache directories must not be world-writable.
- Cache content is data; it is never sourced as shell.

## Failure semantics

The OCI provider is fail-closed.

Block when:

- the helper executable is missing or not executable;
- the helper exits non-zero;
- JSON is missing, invalid, too large, or schema-invalid;
- `provider` is not `oci`;
- `decision` is not `allow`, `deny`, or `error`;
- `ttl_seconds` is expired or non-integer;
- the helper prints secrets in fields that bashqueues marks forbidden;
- the OCI region, tenancy, compartment, or principal context does not match the
  caller's policy constraints.

## Class integration pattern

A class should use OCI provider decisions as explicit gates, not as implicit shell
configuration. A future live asset might look like this conceptually:

```text
queue_class_shared_asset oci policy_resolved class=CLOUD_OCI_GOVERNED operation=job.submit compartment=ocid1.compartment.oc1..example
queue_class_shared_asset oci acl_allowed operation=job.submit subject=$QUEUEBASH_SUBMITTER
queue_class_shared_asset oci posture_clean require=cloud_guard_open_problems=0
queue_class_shared_asset integrity manifest_verified /etc/queuebash/manifests/oci.manifest
```

This contract deliberately does not add the live `oci` asset yet. It establishes
the helper names, JSON shapes, failure semantics, cache rules, and documentation
so a later package can wire enforcement without redesigning the trust boundary.

## Single-user and non-OCI installations

Single-user installations remain simple and file-backed. This provider contract
must not make OCI mandatory. If `QUEUEBASH_OCI_PROVIDER=0` or no OCI provider
configuration exists, existing file-backed trust, ACL, and key providers continue
to work normally.

## Relationship to other provider contracts

The OCI provider must preserve the same normalized helper model as Microsoft,
LDAP, PAM/NSS, ACL, key, and trust provider contracts:

- external systems provide authoritative facts;
- bashqueues consumes bounded JSON and exit-code decisions;
- provider output is never evaluated as shell;
- missing or malformed provider output blocks;
- all decisions carry source/evidence metadata suitable for audit;
- live enforcement remains explicit, reviewed, and testable.
