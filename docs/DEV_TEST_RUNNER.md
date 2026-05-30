# DEV_TEST_RUNNER

`queue dev test` submits real development test jobs into an isolated harness
`QUEUEBASH_ROOT`. The command path deliberately uses the public `queue submit`
interface inside a clean subprocess, then runs a bounded worker pass only when
`--run` is requested.

The result schema is `queuebash.dev_test_result.v1` and includes the created job
id, class, queue state, verdict, exit code, timeout flag, before/after state
counts, and bounded log tail metadata.

This package does not wire test results into `queue dev scratchpad`; manual
scratchpad notes remain allowed and automatic integration is deferred.
