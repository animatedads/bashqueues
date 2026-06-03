# 0.18.56 BOB_MERGER QBTEST example escape and timeout helper

Merged Bob12's QBTEST example/timeout-helper patch onto the accepted 0.18.55 Bob Merger line.

Patch route used first:

- `source queuebash.sh`
- `queue dev patchset inspect --patchset ... --json`
- patch apply script precheck/apply route

The patch tooling correctly reported two expected conflicts because the current master had already removed the legacy fake QBTEST placeholder while this patchset was built against the earlier 0.18.55 base. Those conflicts were limited to `queuebash.sh` and `docs/QUEUE_DEV_QBTEST.md`; the Bob12 changes supersede the fake-placeholder removal by escaping help examples and preserving only the real `_queue_now` embedded QBTEST block.

Runtime additions:

- `QUEUEBASH_VERSION="0.18.56"`
- QBTEST help shows escaped `EXAMPLE_QBTEST:*` markers.
- `queue dev test qbtest --function my_func` returns `no_match` and exits 3 rather than reporting an invalid placeholder block.
- `bin/queue-dev-timeout` provides a bounded, non-interactive helper for repeatable Bob/test runs.

Preserved boundaries:

- No queue dispatch refactor.
- No cloud/provider behaviour changed.
- No live network/API calls introduced.
- `assets.d/net_usage.sh` remains absent.
- `caps.d/net_usage.sh` remains present.
