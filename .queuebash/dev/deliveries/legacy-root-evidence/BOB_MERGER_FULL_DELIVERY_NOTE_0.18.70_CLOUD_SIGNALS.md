# 0.18.70 BOB_MERGER cloud cost and service availability wiring merge

Merged Bob10 cloud cost/service-availability wiring onto the accepted 0.18.69 remote connection entry base. The incoming patch identity was 0.18.69 and is treated as branch identity only; the accepted merger-line identity is 0.18.70.

Boundaries preserved: no live cloud API calls, no credentials, no billing queries, no provisioning/destruction, and no queue dispatch refactor.
