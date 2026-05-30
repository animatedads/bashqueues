# Provider explainability standard

This document defines the common explainability standard for provider-family
contract packs in bashqueues.

The standard is intentionally provider-neutral. It applies to cloud and
cloud-adjacent provider packs such as AWS, GCP, Azure, EU sovereign providers,
APAC/China providers, GPU clouds, edge clouds, and hybrid/on-prem providers.

## Scope

This package is a Bob2 consistency backfill. It standardizes documentation,
fixtures, JSON contract expectations, and testable status language.

It does **not** add live provider API calls, credentials, provisioning,
destruction, queue dispatch refactors, scheduler behaviour, or compliance
claims.

## Required human explain fields

Every provider-family explainability document should make the human output
model clear. Human explain output should include at least:

```text
Provider:
Check:
Decision:
Reason:
Source:
Fail-closed:
Remediation:
Validation status:
```

For provider-family packs that are fixture-first, the source should normally be
`fixture`, `policy`, `config`, or `mapped_pending_validation`, not a live cloud
API.

## Required JSON explain fields

Every provider-family explain JSON or fixture-backed decision object should use
stable fields where the concept applies:

```json
{
  "schema": "queuebash.<provider>.<check>.v1",
  "provider": "<provider>",
  "check": "<check>",
  "decision": "allow|available|deny|unknown",
  "reason": "short_machine_reason",
  "source": "fixture|policy|config|provider-cache|mapped_pending_validation",
  "fail_closed": true,
  "remediation_hint": "Human next step"
}
```

Provider-specific schemas may include additional fields, but they should not
remove the core explainability concepts.

## Status vocabulary

Provider-family status should be explicit:

```text
first_tier_contract
high_standard_reference
fixture_first_provider_family
mapped_pending_validation
needs_primary_source_validation
```

Provider-family presence is not the same as first-tier parity. A provider pack
can be useful and accepted while still being mapped/pending validation.

## Security and legal wording

Provider explainability must avoid overstating compliance. Legal/compliance
sections should use language such as:

```text
mapped pending validation
primary-source validation required
not a compliance certification
not first-tier parity unless tests prove it
```

## Forbidden defaults

Provider explainability packs must not require or introduce by default:

```text
live provider API calls
cloud credentials
provider SDK installation
cloud provisioning/destruction
queue dispatcher refactors
shell/exec/run endpoints
secret logging
PAR/signed URL logging
```

## Bob2 packaging rule

Bob2 provider-family drops should state clearly that they are Bob2 branch or
provider-pack work. Merge ownership remains with the Bob assigned by Team
Leader for the merge line.
