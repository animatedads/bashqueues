# RTO ask feature registry integration

`queue ask --context rto` now receives the local RTO feature registry, not only the broad RTO planner posture.

The context bundle is identified as:

```text
rto.v66.catalog+object-tree+roles+resources
```

The bundle is built from:

```text
RTO/catalog/rto_admin_catalog.json
RTO/model/rto_object_tree.json
RTO/model/rto_roles.json
RTO/model/rto_resources.json
RTO/operations/operation_registry.json
RTO/model/operation_registry.json
```

This lets the advisory layer distinguish between:

- RTO as a generic shell runner, which it is not.
- RTO as an operation catalog with authority and provider selection.
- Wired read operations, such as Windows drive-space checks and current MySQL posture providers.
- Planned operations, such as some deployment and provider-backed change paths.

Queue-native wrappers:

```bash
queue rto status
queue rto catalog --json
queue rto allowed --json
queue rto features --json
queue rto plan deploy vm windows-10le --out PLAN.json
queue rto plan explain PLAN_ID_OR_PATH
queue rto plan preflight PLAN_ID_OR_PATH --json
```

Operators should capture the returned plan id or plan path and pass that exact value to `explain` and `preflight`. The ask layer should not casually recommend `latest` across queued steps because that can preflight or explain the wrong plan.

If a live AI provider, for example Gemini, returns `503` or otherwise fails, the fallback is to answer from the local RTO registry and suggest `queue rto features --json`, `queue rto allowed --json`, or `queue rto catalog --json`. Provider failure must not be interpreted as RTO lacking a feature.
