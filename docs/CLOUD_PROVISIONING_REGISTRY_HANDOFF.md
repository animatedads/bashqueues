# Cloud Provisioning Registry Handoff Preview

`registry-preview` shows the `queuebash.cloud_resource.v1` record that a governed future handoff would place into the cloud resource registry after a successful provisioning workflow.

This release does **not** write the registry by default. It previews the handoff so tests and reviewers can validate the schema, provenance, labels, compliance facts, capacity, region, class allowance, and lifecycle state.

Expected states for later packages:

```text
planned -> approved -> provisioning -> observed -> claimable -> retired|failed
```

Ordinary queue dispatch should only consume cloud-resource availability and claim facts through assets/classes. It must not know how a server was created.
