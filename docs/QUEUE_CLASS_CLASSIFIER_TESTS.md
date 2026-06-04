# Queue class classifier downgrade/anomaly fixture tests

This package treats `queue class-infer` as a governed anomaly signal, not as a direct submit-path policy override.

The implemented command surface remains:

- `queue class-infer fingerprint`
- `queue class-infer recommend`
- `queue class-infer explain`
- `queue class-infer test`

The classifier test fixtures exercise trusted normal history, obvious class downgrades, near-miss lower-risk dry-run work, cold-start jobs, adversarial renames, and behavioural drift.  The helper may read a job fixture with `--job FILE`; this keeps the existing verbs while allowing tests to include richer features such as user, group, paths, secrets, network needs, requested assets, runtime buckets, and cloud/resource use.

## Enforcement boundary

`queue class-infer` still does not change queue submission behaviour. It emits explainable recommendation JSON containing `decision`, `recommended_action`, `reasons`, `confidence`, `recommended_class`, and `requested_class`. Class policy decides whether that signal means warn, block, require authorisation, require signed exception, or allow-but-audit.

A blocking recommendation must include reasons. If a recommendation cannot explain itself, submit-path policy must not automatically block on it.


## Class-policy asset integration

The classifier remains advisory until class policy consumes its JSON through an asset contract. The `class_classifier` asset helper is deliberately non-mutating: it reads a `queue class-infer recommend --json` or `explain --json` decision file, or optionally runs a local fixture/job preview with explicit `job_file=`, `history=`, and `policy=` inputs. It does not submit jobs, rewrite classes, train from live labels, or override queue policy.

Example blocking policy signal:

```bash
queue_class_shared_asset class_classifier no_downgrade _ \
  decision_file=/run/queuebash/class-infer.json \
  min_confidence=0.80 \
  action=block
```

Example warning-only signal:

```bash
queue_class_shared_asset class_classifier warn_on_downgrade _ \
  decision_file=/run/queuebash/class-infer.json \
  min_confidence=0.65
```

Explainability can be required as a separate policy gate:

```bash
queue_class_shared_asset class_classifier decision_explainable _ \
  decision_file=/run/queuebash/class-infer.json
```

The important safety rule is preserved in the helper contract: `no_downgrade` only blocks an explainable high-confidence downgrade/mismatch. If a classifier result has no reasons, `decision_explainable` fails, while `no_downgrade` reports `unexplained_not_auto_blocked` rather than automatically blocking on an opaque score.


## Policy risk-floor escalation

Trusted history remains the preferred signal, but some cold-start jobs are already high-risk before there is enough history to infer a usual class. The policy risk floor is a deterministic, non-learning guard for that boundary. When a low-risk submitted class is paired with evidence such as production secrets, outbound network, customer/prod data paths, high-risk assets, or sensitive environment keys, `queue class-infer recommend --json` returns `decision=risk_floor_escalation`, `recommended_action=require_authorisation`, and a `risk_floor` explanation block.

This does not mean the classifier directly blocks the job. It means class policy has a concrete authorisation/review signal, while harmless cold-start work still returns `insufficient_history` and defers to class policy.

Example asset gate:

```bash
queue_class_shared_asset class_classifier risk_floor_review _ \
  decision_file=/run/queuebash/class-infer.json \
  min_risk_score=3 \
  action=require_authorisation
```

## Trusted history boundary

Fixture history is treated as trusted only when rows are accepted/post-review observations. Rows marked as failed, blocked, anomaly, untrusted, or policy override are excluded unless explicitly marked as valid exceptions. This prevents the classifier learning from already misclassified or bypassed jobs.

For stricter deployments, policy may set `history_trust_mode=reviewed_only`. In that mode accepted-looking history rows are still excluded unless they carry an explicit review marker such as `trusted=true`, `reviewed=true`, `signed_class=true`, `class_review_status=accepted`, or `valid_exception=true`. This is the guard against blindly learning from long-running wrong class labels that were never reviewed.

## Fixture test runner command

`queue class-infer test --fixtures DIR --json` runs the downgrade/anomaly fixture set as a single non-mutating contract gate. It uses the implemented `fingerprint`/`recommend`/`explain` model rather than changing queue dispatch or class policy enforcement.

Default fixture inputs under `DIR`:

- `history_normal.jsonl` trusted baseline history.
- `policy_block_on_downgrade.json` class-policy linkage for block/warn thresholds.
- `jobs_normal.jsonl` expected normal submissions.
- `jobs_downgrade.jsonl` obvious class downgrade attempts.
- `jobs_near_miss.jsonl` legitimate lower-risk decoys that must not be blocked.
- `jobs_cold_start.jsonl` insufficient-history cases.
- `jobs_adversarial_rename.jsonl` rename-only evasions.
- `jobs_drift.jsonl` acceptable drift and suspicious drift examples.
- `history_poisoned_labels.jsonl` poisoned/downclassed labels that must be excluded from learning.
- `jobs_trusted_history_guard.jsonl` regression case proving untrusted low-class history cannot defeat downgrade detection.
- `jobs_reviewed_history_guard.jsonl` reviewed-only regression proving unreviewed accepted-looking labels cannot poison the baseline.

Example:

```bash
queue class-infer test \
  --fixtures tests/fixtures/class_classifier \
  --json
```

Expected JSON schema:

```json
{
  "schema": "queuebash.class_classifier.test_result.v1",
  "status": "pass",
  "cases": 9,
  "passed": 9,
  "failed": 0,
  "downgrade_detection": {
    "expected_blocks": 4,
    "actual_blocks": 4
  },
  "false_positive_guard": {
    "near_miss_cases": 1,
    "unexpected_blocks": 0
  },
  "reason_coverage": {
    "cases_requiring_reasons": 4,
    "cases_with_reasons": 4
  },
  "trusted_history_guard": {
    "total_rows_seen": 47,
    "trusted_rows_seen": 45,
    "excluded_rows_seen": 2,
    "valid_exception_rows_seen": 0,
    "reviewed_rows_seen": 3
  },
  "risk_floor_guard": {
    "cases": 1,
    "escalations": 1
  },
  "decision_metrics": {
    "downgrade_detection_rate": 1.0,
    "near_miss_false_positive_rate": 0.0,
    "cold_start_unknown_rate": 1.0,
    "risk_floor_escalation_rate": 0.2,
    "reason_coverage_rate": 1.0,
    "decision_counts": {
      "class_downgrade_suspected": 4,
      "insufficient_history": 1,
      "ok": 3,
      "risk_floor_escalation": 1
    },
    "recommended_action_counts": {
      "allow": 3,
      "block_pending_authorisation": 4,
      "defer_to_class_policy": 1,
      "require_authorisation": 1
    },
    "per_category": {
      "near_miss": {"cases": 1, "passed": 1, "failed": 0, "pass_rate": 1.0}
    }
  },
  "non_mutating": true
}
```

The `decision_metrics` block gives the later statistical-dashboard shape without loosening the fixture gate. These metrics are observability signals derived from hard expected outcomes: downgrade detection rate, near-miss false-positive rate, cold-start unknown rate, risk-floor escalation rate, reason coverage, decision/action/source counts, and per-category pass/fail counts. They are not a replacement for the explicit fixture assertions above and they do not authorise automatic enforcement.

Acceptance remains policy-led. The test runner proves that recommendations are parseable, explainable, and stable across known downgrade, near-miss, cold-start, rename, drift, poisoned-history, and reviewed-history fixtures; it does not make the classifier an unchecked enforcement authority.
