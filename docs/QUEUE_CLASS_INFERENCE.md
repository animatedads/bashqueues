# Deterministic class inference

`queue class-infer` is a contract-first, non-mutating class brokerage helper.
It computes deterministic command fingerprints and can recommend a queue class
from local history, pins, and policy references.

This is deliberately **not AI classification**.  It is reproducible evidence
that may later feed submit warnings, upclass decisions, or downgrade blocks.
This package does not alter `queue submit` behaviour.

## Commands

```bash
queue class-infer fingerprint --json -- ffmpeg -i in.mp4 out.mp4
queue class-infer recommend --json --history history.jsonl --pins pins.jsonl --policy policy.json --class DEFAULT -- ffmpeg -i in.mp4 out.mp4
queue class-infer explain --history history.jsonl --pins pins.jsonl --policy policy.json --class DEFAULT -- ffmpeg -i in.mp4 out.mp4
```

Aliases:

```text
queue class_infer
queue class-recommend
queue class-recommendation
```

## Schemas

```text
queuebash.class_inference.fingerprint.v1
queuebash.class_inference.recommendation.v1
queuebash.class_inference.explain.v1
queuebash.class_inference.policy.v1
```

## Fingerprints

The helper emits three hashes:

```text
command_raw_hash      exact command and arguments
command_shape_hash    normalized command shape
command_family_hash   broader command family
```

The normalizer replaces unstable values:

```text
numbers       -> <num>
dates         -> <date>
paths         -> <path.ext>
URLs          -> <url>
UUIDs         -> <uuid>
hashes        -> <hash>
ranges        -> <range>
secret names  -> <secret-key>
```

## History and pins

History is JSONL and should contain observed, weighted evidence:

```json
{"command_shape_hash":"sha256:...","class":"VIDEO_ENCODE","outcome":"done","learning_weight":1.0}
```

Anomalous or downgrade runs should not poison the profile:

```json
{"command_shape_hash":"sha256:...","class":"DEFAULT","outcome":"accepted_with_warning","learning_weight":0.1}
```

Pins are JSONL and override statistical history:

```json
{"command_shape_hash":"sha256:...","class":"SECURE_IMPORT","authority":"admin","reason":"Sensitive import jobs require audit"}
```

## Policy and brokerage linkage

Class brokerage decisions may need to explain **why** a class is recommended or
why a downgrade is suspicious.  The policy file therefore supports regulatory
and corporate references.

```json
{
  "schema": "queuebash.class_inference.policy.v1",
  "mode": "suggest",
  "min_observations": 3,
  "confidence_threshold": 0.8,
  "validation_status": "mapped_pending_validation",
  "corporate_policy_refs": [
    {"id":"CORP-QUEUE-CLASS-001","title":"Workload classing standard","status":"accepted"}
  ],
  "regulatory_refs": [
    {"id":"UK-DPA-2018","title":"UK data protection posture mapping","status":"mapped_pending_validation"}
  ]
}
```

The helper copies these into `policy_linkage` and `audit_event_preview`.
References are **evidence links**, not compliance claims.  A mapped or imported
reference remains pending until validated against primary sources and accepted
by project policy.

## Future submit integration

Later packages may add:

```text
observe
suggest
warn
auto-upclass
block-downgrade
require-authorisation
```

This package only provides deterministic evidence and recommendations.
