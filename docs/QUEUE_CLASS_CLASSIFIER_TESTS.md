# Queue class classifier downgrade/anomaly fixture tests

This package treats `queue class-infer` as a governed anomaly signal, not as a direct submit-path policy override.

The implemented command surface remains:

- `queue class-infer fingerprint`
- `queue class-infer recommend`
- `queue class-infer explain`

The classifier test fixtures exercise trusted normal history, obvious class downgrades, near-miss lower-risk dry-run work, cold-start jobs, adversarial renames, and behavioural drift.  The helper may read a job fixture with `--job FILE`; this keeps the existing verbs while allowing tests to include richer features such as user, group, paths, secrets, network needs, requested assets, runtime buckets, and cloud/resource use.

## Enforcement boundary

`queue class-infer` still does not change queue submission behaviour. It emits explainable recommendation JSON containing `decision`, `recommended_action`, `reasons`, `confidence`, `recommended_class`, and `requested_class`. Class policy decides whether that signal means warn, block, require authorisation, require signed exception, or allow-but-audit.

A blocking recommendation must include reasons. If a recommendation cannot explain itself, submit-path policy must not automatically block on it.

## Trusted history boundary

Fixture history is treated as trusted only when rows are accepted/post-review observations. Rows marked as failed, blocked, anomaly, untrusted, or policy override are excluded unless explicitly marked as valid exceptions. This prevents the classifier learning from already misclassified or bypassed jobs.
