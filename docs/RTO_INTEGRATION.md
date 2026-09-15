# RTO integration

This package carries the RTO application under `RTO/` as a contained application tree.

`queue ask` detects the tree automatically when it is present next to `queuebash.sh`, or when `QUEUEBASH_RTO_ROOT` points at an RTO tree. When a question is about deployment planning, Windows/VM/MySQL operations, provider selection, preflight, rollback, receipts, or RTO itself, the local advisory context includes RTO v66 plan/preflight/receipt guidance.

The integration is advisory-only. It does not run RTO execution, does not bypass queue policy, and does not make network/provider calls by itself.

Useful RTO commands from the RTO tree:

```bash
RTO/rto plan deploy vm windows-10le
RTO/rto plan explain latest
RTO/rto plan preflight latest --json
```

RTO v66 currently reports execution as plan-only; execution is not implemented in that build.
