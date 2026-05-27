# Microsoft Governance Provider Contract

This document defines the Microsoft provider contract for bashqueues enterprise
installations. It is a contract and integration boundary, not a live Graph or Key
Vault implementation.

The Microsoft provider is an implementation of the bashqueues trust/provider
model introduced in 0.17.96. Microsoft systems may provide authoritative policy,
ACL, key, and delegation decisions, but bashqueues consumes only constrained,
normalized provider output and remains fail-closed.

## Design rule

Microsoft-sourced governance is data, not shell.

Provider helpers must return normalized JSON or simple exit-code decisions.
bashqueues must never execute policy rows, SharePoint values, Graph attributes,
Purview labels, LDAP attributes, or Key Vault metadata as shell code.

## Canonical paths

Use the queuebash namespace:

```text
/etc/queuebash/policy/providers.d/microsoft.env
/var/cache/queuebash/ms/
/usr/libexec/queuebash/providers/microsoft/
```

Do not introduce a parallel legacy plural namespace for new provider work.

## Provider components

A Microsoft-dominated organisation normally has these authoritative systems:

- Entra ID / Azure AD for identity, groups, roles, and application identity.
- Microsoft Graph for directory and SharePoint/Purview access.
- Azure Key Vault or Managed HSM for keys, secrets, certificates, and wrapping.
- SharePoint Lists, Purview, or Graph-backed directory objects for policy rows.
- Sentinel, Activity Logs, Key Vault logs, and Purview audit for evidence.

bashqueues should not own that truth. It should ask provider helpers for the
small decision it needs at the point of enforcement.

## Configuration file

Example location:

```text
/etc/queuebash/policy/providers.d/microsoft.env
```

Example content:

```bash
QUEUEBASH_MS_PROVIDER=1
QUEUEBASH_MS_TENANT_ID="00000000-0000-0000-0000-000000000000"
QUEUEBASH_MS_CLIENT_ID="00000000-0000-0000-0000-000000000000"
QUEUEBASH_MS_CLIENT_SECRET_FILE="/etc/queuebash/policy/providers.d/microsoft.client.secret"

QUEUEBASH_MS_POLICY_SOURCE="sharepoint:list"
QUEUEBASH_MS_POLICY_SITE_ID="contoso.sharepoint.com,site-id,web-id"
QUEUEBASH_MS_POLICY_LIST_ID="policy-list-id"

QUEUEBASH_MS_ACL_SOURCE="graph:groupMembership"
QUEUEBASH_MS_ACL_GROUP_PREFIX="BQ_"
QUEUEBASH_MS_ACL_CACHE_DIR="/var/cache/queuebash/ms"
QUEUEBASH_MS_ACL_CACHE_TTL_SECONDS=300

QUEUEBASH_MS_KEY_SOURCE="keyvault"
QUEUEBASH_MS_KEYVAULT_DEFAULT_VAULT="queuebash-governance"
```

Secrets should be readable only by the account that runs the provider helpers.
Where possible, use managed identity, workload identity, certificate credentials,
or an enterprise secret broker instead of a local client secret file.

## Helper commands

The helper commands are intentionally separate from hot-path shell logic:

```text
queue-ms-token
queue-ms-policy-resolve
queue-ms-acl-check
queue-ms-key-resolve
```

They may be implemented in Python, Go, PowerShell, or another controlled runtime,
but their output contract is JSON and their failure semantics are fail-closed.

### Common response envelope

All JSON helpers should follow this envelope:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "microsoft",
  "decision": "allow",
  "reason": "human readable short reason",
  "evidence": {
    "source": "graph",
    "request_id": "provider-request-id-or-empty"
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

## Token helper

```bash
queue-ms-token --scope https://graph.microsoft.com/.default
queue-ms-token --scope https://vault.azure.net/.default
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "microsoft",
  "decision": "allow",
  "access_token_ref": "cache:/var/cache/queuebash/ms/token.graph.json",
  "expires_at": "2026-05-27T14:30:00Z",
  "ttl_seconds": 300
}
```

The token helper should avoid printing bearer tokens directly unless explicitly
configured for a controlled local IPC mode. Prefer a root-owned or helper-owned
cache reference with strict permissions.

## Policy resolver

Purpose: resolve class/job policy requirements from SharePoint, Purview, or
Graph-backed metadata without returning executable shell.

Example invocation:

```bash
queue-ms-policy-resolve \
  --class CLOUD_AZURE_GDPR \
  --operation job.submit \
  --subject alice@example.com \
  --job-file /var/lib/queuebash/system/pending/job.job
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "microsoft",
  "decision": "allow",
  "class": "CLOUD_AZURE_GDPR",
  "operation": "job.submit",
  "required_assets": [
    {
      "asset": "legal",
      "facility": "retention_respected",
      "args": ["datasetScope=GDPR"]
    },
    {
      "asset": "finops",
      "facility": "anomaly_free",
      "args": ["block_on=error"]
    },
    {
      "asset": "integrity",
      "facility": "manifest_verified",
      "args": ["/etc/queuebash/manifests/gdpr.manifest"]
    }
  ],
  "evidence": {
    "source": "sharepoint:list",
    "site_id": "redacted-or-stable-id",
    "list_id": "redacted-or-stable-id"
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

## ACL checker

Purpose: answer whether a subject may perform an operation on a class, profile,
queue root, job, or governance resource.

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
```

Example invocation:

```bash
queue-ms-acl-check \
  --subject alice@example.com \
  --operation profile.approve \
  --resource profile:goodrexx \
  --class SECURE_PROFILED
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "microsoft",
  "decision": "allow",
  "subject": "alice@example.com",
  "operation": "profile.approve",
  "resource": "profile:goodrexx",
  "groups": ["BQ_Profile_Approvers", "BQ_Ops"],
  "reason": "subject is a member of the required approval group",
  "evidence": {
    "source": "graph:memberOf",
    "tenant_id": "00000000-0000-0000-0000-000000000000"
  },
  "ttl_seconds": 300
}
```

A single-user file-backed installation may answer these operation ACL questions
locally. A Microsoft-backed installation should map operations and resources to
Entra ID groups, roles, or app-role assignments.

## Key resolver

Purpose: confirm availability of a key, secret, certificate, or public signing
key without making local files the trust model.

Example references:

```text
kv:queuebash-governance:ops-release-public
kv:queuebash-governance:dataset-prod-key
cert:queuebash-governance:profile-signing-cert
```

Example invocation:

```bash
queue-ms-key-resolve \
  --purpose profile-public-key \
  --signer ops-release \
  --reference kv:queuebash-governance:ops-release-public
```

Successful response:

```json
{
  "schema": "queuebash.provider.v1",
  "provider": "microsoft",
  "decision": "allow",
  "purpose": "profile-public-key",
  "signer": "ops-release",
  "public_key_ref": "cache:/var/cache/queuebash/ms/keys/ops-release.ed25519.pub.pem",
  "public_key_sha256": "sha256-hex-here",
  "evidence": {
    "source": "keyvault",
    "vault": "queuebash-governance"
  },
  "ttl_seconds": 300
}
```

For signing verification, bashqueues should consume a local cached public key or
certificate chain reference after the helper has validated the key source. Private
keys and unwrapped secrets should not be printed to stdout.

## Fail-closed requirements

The Microsoft provider contract must fail closed when:

- the helper is missing or not executable;
- JSON is malformed or has the wrong schema;
- `decision` is absent or not `allow`;
- the output is stale beyond `ttl_seconds` or an explicit expiry;
- asset/facility names fail validation;
- a key reference resolves to the wrong signer, purpose, or fingerprint;
- the provider says the subject lacks the required operation ACL;
- the provider returns executable code instead of normalized data.

## Relationship to LDAP and PAM.d providers

The Microsoft provider is not special inside bashqueues. It is the first concrete
enterprise contract using the 0.17.96 provider boundary. LDAP and PAM.d/NSS
providers should use the same response envelope, operation names, TTL rules, and
fail-closed behaviour.
