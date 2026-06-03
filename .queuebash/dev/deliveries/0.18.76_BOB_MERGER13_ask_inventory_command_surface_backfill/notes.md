# 0.18.76 BOB_MERGER13 ask inventory command-surface backfill

This delivery repairs the broader stale ask command inventory problem observed after the `queue remote add` one-off fix. The command context now combines top-level help, discovered installed usage strings, and remote helper help. Asset context includes bundled facility/example lines, including grid_energy, without executing asset plugins in the ask path.

No queue dispatch, provider live posture, provisioning, or grid-energy runtime behaviour changed.
