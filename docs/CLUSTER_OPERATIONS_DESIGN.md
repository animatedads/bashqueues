# Bob25 cluster operations design

Bob25 adds the cluster design and a safe command contract for bashqueues. The first implementation rule is that a single-user, single-instance queue must remain the default and must not gain a network dependency, background discovery, or consensus failure mode.

## Design decision

Queuebash should not implement a full consensus database inside `queuebash.sh`. Cluster support should be a thin orchestration layer over provider-backed coordination.

The queue front end remains responsible for:

- operator command contract
- JSON schemas
- audit records
- local policy evaluation
- class/security/egress/legal gates
- explainability

A cluster provider is responsible only for normalized coordination state:

- membership records
- leader lease records
- vote records
- timing/skew observations
- health heartbeats
- optional provider-specific locking

## Default mode

Default mode is standalone.

```text
queue cluster status
```

must report that clustering is disabled, local operation is unchanged, no network was touched, and no action is required.

## Election, voting, and timing

Election and voting are separate controls.

Election decides which node currently coordinates ordinary cluster control-plane activity. The preferred primitive is a short leader lease with monotonic timing and a declared skew budget.

Voting gates risky or governed mutations. Votes are not required for every job. They are required for membership changes, policy changes, trust/key/ACL changes, egress enablement, cross-node execution enablement, destructive multi-node cleanup, remote secret rotation, and regulated workload movement.

Timing must be conservative:

- monotonic local timestamps for lease calculations
- provider timestamps as evidence, not blind authority
- explicit skew budget
- fail-closed when a lease cannot be validated
- no shortening of existing holds or legal/policy delays

## Egress and legal scope

Cluster mutation is denied by default unless policy permits the operation. Egress must be declared and scoped by policy before any provider can send job data, metadata, secrets, or evidence outside the local queue root.

## Implementation phases

Phase 1 is contract-only and read-only:

- `queue cluster status [--json]`
- `queue cluster policy status|paths [--json]`
- `queue cluster elect status [--json]`
- `queue cluster vote status [--json]`
- `queue cluster node list [--json]`
- `queue cluster explain [SUBJECT] [--json]`
- `queue cluster init --name NAME [--profile PROFILE] [--json]` as a no-write plan

Phase 2 should add a file-dev provider for deterministic tests. It is not a production consensus provider.

Phase 3 should add production providers such as Kubernetes/OpenShift Lease, Consul, etcd, and signed peer coordination.

## Bob25 0.18.115 local materialisation increment

The first implementation increment keeps the standalone promise intact while giving an
admin an explicit, auditable seed step for local file-dev coordination state:

```bash
queue cluster init --name NAME --profile PROFILE --materialize
```

This command is deliberately local-only. It creates a private cluster state directory,
writes a minimal `cluster.env`, records the local node as a controller, and appends a
JSONL audit event. It does not start networking, contact peers, discover nodes, grant
remote execution, issue reusable join secrets, or relax policy. The status/explain
commands remain read-only.

Materialised state is interpreted as a local file-dev cluster seed only. Production
coordination providers still need separate provider implementations and policy gates.
The seed state uses `egress_mode=local-only` and `legal_scope=local` by default, so it
is safe for a single user and does not create accidental cross-border or corporate
policy exposure.


## 0.18.118 election lease witness

Bob25 now adds the first local election artefact: `queue cluster elect lease`. It is deliberately a witness, not consensus. The command gives operators and tests a concrete lease shape with epoch, TTL and expiry fields, while preserving the no-network default. The local lease is useful for validating timing, audit and JSON contracts before adding Kubernetes Lease, Consul or etcd-backed providers.

The safe boundary remains: standalone status is read-only, cluster init writes only with `--materialize`, and lease witness state writes only with `queue cluster elect lease --materialize`.
