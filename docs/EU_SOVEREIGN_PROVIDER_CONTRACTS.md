# EU sovereign cloud provider contracts

This package defines fixture-first provider contracts for OVHcloud, Scaleway, Hetzner Cloud, and Open Telekom Cloud.

Scope is contract/backfill only:

- no live API calls by default
- no credentials required for tests
- no provisioning or destruction
- no queue dispatcher refactor
- no compliance claims beyond mapped/proposed/pending validation

The provider helper returns normalized JSON only and must not return shell code, secrets, API tokens, private keys, signed URLs, or provider console session material.

Schemas include:

- `queuebash.eu_sovereign.ovhcloud.detect.v1`
- `queuebash.eu_sovereign.scaleway.identity.v1`
- `queuebash.eu_sovereign.hetzner.region.v1`
- `queuebash.eu_sovereign.otc.legal.v1`

Required checks for each provider:

- detect
- identity
- region
- compute
- storage
- network
- finops
- legal

Provider-specific notes must remain pending validation until checked against primary provider documentation and legal/compliance authority.
