# Queue class fingerprints

Class fingerprints are deterministic command signatures used for class
recommendation and downgrade/anomaly detection.

A fingerprint records:

```text
argv0
script
argument shape
working-directory family
requested class
raw / shape / family hashes
```

The shape hash is the primary key for class history.  It should be stable for
commands such as:

```bash
python3 render.py --input scene001.json --output out001.mp4 --frames 1-300
python3 render.py --input scene002.json --output out002.mp4 --frames 301-600
```

where paths and ranges change but the workload shape remains the same.

Fingerprints must not expose secrets.  Tokens that look like secret-bearing
argument names are reduced to `<secret-key>` in the shape representation.
