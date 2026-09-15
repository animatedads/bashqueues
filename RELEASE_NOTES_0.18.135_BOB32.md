# bashqueues 0.18.135 BOB32 full release

Base: `bashqueues_0.18.124_BOB27_health_install_policy_plan_platform_service_merge_full_delivery.zip`

Applied Bob32 fixes through 0.18.135:

- postclaim preflight waiting-state model
- priority-bucketed waiting tree
- waiting lookup/list/explain/authorise/reevaluate support
- queue run preflight/sentinel sweep before worker claim
- queue pause allowed for waiting without --force
- queue list `--state waiting` and CLASS display
- queue waiting diagnostics split between dependency-waiting pending jobs and first-class waiting jobs
- sys:memory_available accepts `min_mb=` as well as `min_gb=`
- cron JSON surfaces
- class explain multi-record JSON
- executable install-system.sh
- stale version-guard cleanup
- enterprise helper examples
- queue-side RTO detection/wrapper/ask advisory integration through the operation-boundary grounding fix

RTO packaging note:

- The RTO application is intentionally **not bundled** in this full release.
- Queue-side RTO integration remains present and reports unavailable until an external `RTO/` directory is supplied beside `queuebash.sh` or `QUEUEBASH_RTO_ROOT` is set.

Focused validation run in this packaging environment:

```text
bash -n queuebash.sh
python3 -m py_compile bin/*.py tests/*.py
queue health --json | python3 -m json.tool
queue policy paths --json | python3 -m json.tool
queue rto status --json | python3 -m json.tool
```
