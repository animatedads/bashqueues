# 0.18.65 BOB_MERGER QBTEST wave3-wave8 function coverage

Merged Bob13 QBTEST wave3/wave5, wave6/wave7, and wave8 function-level embedded tests onto the current 0.18.62 Bob Merger base by extracting QBTEST blocks from each patchset's `files/queuebash.sh` and reapplying them against matching function names on the current merger head.

This deliberately avoids whole-file `queuebash.sh` replacement from older QBTEST waves. The malformed nested `env-valid-name` block in wave8 was not preserved; the valid earlier block was used and both `_queue_env_valid_name` and `_queue_env_dir` pass.

The resulting `queuebash.sh` contains 105 listed QBTEST blocks and the full embedded QBTEST run reports 105 pass, 0 fail, 0 invalid.
