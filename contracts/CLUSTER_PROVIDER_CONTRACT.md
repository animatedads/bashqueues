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
