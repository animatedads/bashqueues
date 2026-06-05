# Bob25 cluster provider contract

Cluster providers are coordination backends. They are not policy engines and must not bypass queuebash security gates.

## Provider responsibilities

A provider may implement:

- `status`
- `membership.list`
- `membership.propose`
- `membership.commit`
- `lease.read`
- `lease.acquire`
- `lease.renew`
- `lease.release`
- `vote.propose`
- `vote.cast`
- `vote.status`
- `timing.observe`

## Provider request principles

Every mutating request must include:

- actor
- node id
- cluster name
- operation
- reason
- policy decision evidence
- local monotonic timestamp
- wall-clock timestamp
- idempotency key

## Provider response principles

Every response must include:

- schema
- provider
- operation
- decision/result
- reason
- provider evidence id or record key
- timing evidence where relevant

## Hard boundaries

Providers must not receive job payloads, secrets, class files, legal case hint data, or redacted policy evidence unless an explicit egress policy allows that transfer.

## Built-in file-dev provider seed

The built-in `file-dev` provider seed is a local coordination fixture, not a production
consensus mechanism. It exists to make the cluster command contract testable and to let
admins inspect the state shape before selecting a real coordination provider.

Required seed files:

```text
cluster.env
nodes.d/<node-id>.env
cluster_events.jsonl
```

The seed must preserve local-only defaults and must not be treated as permission to run
remote workloads, open egress, change legal scope, or bypass voting gates.


## Local lease witness provider obligation

The `file-dev` provider may materialize a local lease witness for test/dev use only. Production providers must expose equivalent fields: leader, lease epoch, TTL seconds, expiry epoch, provider name, scope, and network-touch marker. A provider must not imply a remote quorum from a local lease file.


## Local vote proposal witness provider obligation

The `file-dev` provider may materialize local pending vote proposals for test/dev use only. Production providers must expose equivalent fields: proposal id, operation, proposer, reason, status, provider name, scope, and network-touch marker. A local pending vote witness must never be treated as quorum or approval evidence.

## Local ballot witness

The `file-dev` provider may materialize local ballot witnesses for development and contract testing only. A local ballot is evidence of one node's stated decision; it is not quorum, approval, or authorization. Production providers must expose equivalent proposal id, voter/node id, decision, provider, scope, created timestamp, network-touch marker, quorum result, and mutation-unlock marker.


## Local vote tally provider shape

A provider implementing the Bob25 vote contract must keep proposal storage, ballot storage, tally/evaluation, quorum grant, and mutation unlock as separate auditable steps. The file-dev provider may report local approve/reject/abstain counts for evidence, but it must not claim quorum or unlock mutations. Production providers must declare quorum rules, voter eligibility, legal scope, timing windows, and egress behaviour before returning any approval decision.

## Bob25 0.18.125 vote evaluation provider contract

Provider-backed quorum must implement evaluation as a distinct step from proposal creation, ballot recording, and tallying. A provider may only report quorum granted when it can prove voter eligibility, quorum threshold, timing window, policy authorization, legal scope, and egress controls. The local `file-dev` provider is evidence-only and must always report `quorum_granted:false` and `cluster_mutation_unlocked:false`.
