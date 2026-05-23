# Queue classes and resource claims

Queue classes define cooperative scheduling constraints.

## Submit

```bash
queue submit ingest_day --class FORENSIC_DSP -- python ingest.py
```

## Class files

Class files live under:

```text
~/.queuebash/classes/<CLASS>.env
```

Example:

```bash
# Only one job of this class may run at once.
CLASS_ALLOW_PARALLEL=0

# Optional concurrency cap. 0 means unlimited.
CLASS_MAX_CONCURRENT=1

# Shared assets can run together unless an exclusive claim exists.
CLASS_SHARED_ASSETS="audio_disk"

# Exclusive assets block all other users of the same asset.
CLASS_EXCLUSIVE_ASSETS="camera_A"
```

Synonyms:

```bash
CLASS_EXCLUSIVE=1       # same effect as CLASS_ALLOW_PARALLEL=0
CLASS_ASSETS="name"     # alias for CLASS_SHARED_ASSETS
```

## Semantics

Class exclusivity controls jobs of the same class only.

Exclusive assets are stronger: an exclusive asset claim blocks all other jobs claiming that asset, whether shared or exclusive.

Commands:

```bash
queue class init FORENSIC_DSP
queue class list
queue class show FORENSIC_DSP
queue claims
```

Claims are inspectable directories:

```text
~/.queuebash/claims/classes/
~/.queuebash/claims/assets/
```
