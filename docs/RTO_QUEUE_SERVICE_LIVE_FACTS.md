# RTO Queue service live facts

Bob32 v0.18.136 adds a queue-owned service contract for RTO.

RTO may rely on Queue for governance and operational facts, but Queue must be
honest about which facts are live and which are local policy/catalog evidence.
The contract is exposed with:

```bash
queue rto queue-services --json
```

## Queue-owned live facts

These are read from the active Queue installation or host state:

```text
queue policy paths --json
queue policy status --json
queue enterprise profiles --json
queue enterprise verify-profile PROFILE --json
queue cluster --json
queue cluster status --json
queue identity whoami --json
queue roles --json
queue consistency --json
```

RTO should treat these as evidence inputs only. They do not grant authority by
themselves.

## Cloud, billing, and cost facts

Queue exposes the cloud/cost surface honestly:

```bash
queue cloud status --json
queue cloud billing --json
queue cloud cost --json
```

By default these are **not** live cloud API or live billing calls. They report
helper availability, credential hints, and local cloud-signals policy/catalog
status. The JSON marks `live_cloud_api_calls=false` and `network_touched=false`.

RTO must not infer current cloud spend from this surface unless a future Queue
billing provider explicitly reports live billing enabled.

## RTO bridge behaviour

If RTO is installed, the wrapper can delegate:

```bash
queue rto bridge queue snapshot --json
queue rto bridge queue governance --json
queue rto bridge queue import --json
```

If RTO or ooRexx is unavailable, Queue returns the local service contract instead
of pretending the bridge succeeded.

## Consistency

`queue consistency --json` provides a read-only filesystem/state consistency
snapshot for RTO, including waiting-state support and the pre-run sentinel sweep.
