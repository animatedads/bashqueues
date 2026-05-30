# Cloud provisioning security model

The provisioning layer treats cloud creation or lifecycle mutation as a future
high-risk operation. In this contract package, live mutation is not implemented.

## Fail-closed defaults

`cloud_provision` denies or marks review when required facts are missing:

```text
missing region
missing legal framework
unknown provider
ITAR workload on a non-ITAR template
cost ceiling breach
live mutation requested
```

## Live mutation rule for future packages

Provider credentials alone must never be sufficient. A future live apply package
must require all of the following:

```text
explicit live enablement
provider policy permission
template allowlist
identity/role authority
change ticket or reason
cost policy pass
region/legal/data-protection/export-control pass
audit sink available
normalized JSON evidence
```

## Secrets

Provisioning templates, plans, scratchpad notes, logs, and examples must not
store provider secrets, API keys, private keys, user-data scripts, access tokens,
PAR URLs, or full sensitive metadata. Store references, redacted labels,
resource identifiers, and provenance only.

## Dispatch boundary

Ordinary queue submit/dispatch must not create cloud servers. Dispatch may read
`cloud_resource` facts through assets/classes after a resource exists or after a
future approved provisioning handoff has reconciled the resource into the
registry.
