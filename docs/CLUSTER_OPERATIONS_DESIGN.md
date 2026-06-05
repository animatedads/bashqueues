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


## 0.18.119 local vote proposal witness

Bob25 now adds `queue cluster vote propose` as the first concrete voting artefact. It follows the same safety posture as cluster init and lease witness: read-only/dry-run by default, local file-dev state only with explicit `--materialize`, and no network.

The local proposal record exists to prove the operation/reason/proposer/status shape before real coordination providers are attached. It deliberately does not approve work, create quorum, or unlock cluster mutations. Voting remains a governance gate for risk-bearing operations such as membership, policy, trust, egress, and destructive cluster cleanup.

## 0.18.121 local vote cast witness

Bob25 now adds `queue cluster vote cast` as the first concrete ballot artefact. This keeps the proposal and ballot phases separate: proposing a risky operation does not approve it, and casting a local ballot does not grant quorum or unlock a mutation.

The implementation remains local-only and dry-run by default. With `--materialize`, it writes one file-dev ballot witness for an existing local proposal and appends audit evidence. Future Kubernetes, Consul, etcd or signed-peer providers must implement the same fields while adding real quorum evaluation under policy, legal and egress controls.


## 0.18.124 Bob25 local vote tally witness

Bob25 now adds `queue cluster vote tally` as the read-only evidence view over local file-dev proposals and ballots. The design intentionally keeps tallying separate from granting quorum: local evidence can show one or more approve/reject/abstain ballots, but only a future provider with declared quorum, voter eligibility, policy, timing, legal and egress controls may turn that into an approval.

This is the next provider contract shape after proposal and ballot witnesses: future Kubernetes, Consul, etcd or signed-peer providers must be able to produce the same JSON facts while preserving fail-closed mutation behaviour.


## 0.18.125 vote evaluation witness

Bob25 now adds `queue cluster vote evaluate` as the read-only bridge between local ballot tallying and future production quorum providers. The command intentionally reports a fail-closed decision for file-dev because local evidence alone cannot prove voter eligibility, timing window, policy authorization, legal scope, or egress compliance. This keeps the admin surface simple while preventing accidental treatment of local test ballots as corporate approval.
