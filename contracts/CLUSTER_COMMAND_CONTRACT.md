# Bob25 cluster command contract

## Stable read-only commands

```text
queue cluster status [--json]
queue cluster policy status [--json]
queue cluster policy paths [--json]
queue cluster elect status [--json]
queue cluster vote status [--json]
queue cluster vote propose --operation OPERATION --reason REASON [--materialize] [--json]
queue cluster node list [--json]
queue cluster explain [SUBJECT] [--json]
```

These commands must be safe in standalone mode. They must not touch the network and must not write state.

## Planning and local materialisation command

```text
queue cluster init --name NAME [--profile PROFILE] [--dryrun] [--materialize] [--json]
```

Without `--materialize`, this command emits an init plan only. It does not write files, does not touch the network, and does not enable clustering. `--dryrun` is accepted explicitly so admin automation can use the same flag style as other queue operations.

With explicit `--materialize`, the file-dev provider may seed local cluster state under the queue root only. It writes local config, node, and JSONL audit evidence; it does not touch the network and it keeps egress local-only.

## Contract-only join planning and fail-closed mutation commands

```text
queue cluster join [--json]
queue cluster pause [--json]
```

`queue cluster join` is plan-only in this release. It validates node, role, provider and token-file arguments, but it does not read the token file, does not materialise state, does not expose a secret value, and does not touch the network. JSON output uses `queuebash.cluster.join_plan.v1` and reports `writes_performed:false`, `network_touched:false`, and `default_decision:fail-closed-for-cluster-mutations`.

`queue cluster pause` remains fail-closed until provider-backed coordination is implemented. With `--json`, it returns non-zero with `queuebash.cluster.mutation_blocked.v1` evidence including `network_touched:false`, `writes_performed:false`, and `default_decision:fail-closed-for-cluster-mutations`.

## Node token planning command

```text
queue cluster node token create --node NODE --role worker|controller|observer [--json]
```

This is a plan-only command in this release. It validates node and role arguments and emits `queuebash.cluster.node_token_plan.v1` without materialising or displaying a secret value. It reports `token_materialised:false`, `secret_value_included:false`, `writes_performed:false`, and `network_touched:false`.

## JSON schemas

- `queuebash.cluster.status.v1`
- `queuebash.cluster.policy_status.v1`
- `queuebash.cluster.policy_paths.v1`
- `queuebash.cluster.election_status.v1`
- `queuebash.cluster.vote_status.v1`
- `queuebash.cluster.vote_proposal.v1`
- `queuebash.cluster.node_list.v1`
- `queuebash.cluster.explain.v1`
- `queuebash.cluster.init_plan.v1`
- `queuebash.cluster.init_result.v1`
- `queuebash.cluster.node_token_plan.v1`
- `queuebash.cluster.join_plan.v1`
- `queuebash.cluster.mutation_blocked.v1`

## Required status fields

Cluster status JSON must include:

- `mode`
- `cluster_enabled`
- `cluster_name`
- `node_id`
- `provider`
- `policy_dir`
- `state_dir`
- `election_strategy`
- `voting_strategy`
- `timing_strategy`
- `egress_mode`
- `network_touched`
- `writes_performed`


## 0.18.118 local lease witness contract

`queue cluster elect lease [--materialize|--renew] [--ttl-seconds N] [--json]` is a file-dev/local-only election witness. Without `--materialize` it is read-only. With `--materialize` it writes only `$QUEUEBASH_ROOT/cluster/lease.env` and appends a `cluster_local_lease_materialized` audit event to `cluster_events.jsonl`. It never contacts peers and reports `network_touched=false`. This is not production consensus; it is the local state shape that later providers must implement with real lease semantics.

JSON schema: `queuebash.cluster.local_lease.v1`.


## 0.18.119 local vote proposal witness contract

`queue cluster vote propose --operation OPERATION --reason REASON [--materialize] [--json]` is the first local vote witness. Without `--materialize`, it emits a dry-run proposal plan only. With `--materialize`, the file-dev provider writes one pending vote record under `$QUEUEBASH_ROOT/cluster/votes.d/` and appends a `cluster_vote_proposal_materialized` audit event to `cluster_events.jsonl`.

This does not approve the operation, does not contact peers, does not create quorum, and does not allow any cluster mutation to proceed. It gives future providers a concrete proposal shape while preserving fail-closed voting semantics.

JSON schema: `queuebash.cluster.vote_proposal.v1`.
