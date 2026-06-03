# GPU Marketplace provider contracts

        This package adds a fixture-first `gpu_marketplace` provider family for bashqueues service coverage.

        ## Scope

        The helper returns normalized JSON facts only. It is an advisory contract used by policies, docs, and future controlled integrations. It does not perform live API calls by default and does not require credentials for tests.

        ## Facts

        - detect marketplace availability from fixtures
- explain offer/capability/quota/compliance facts
- support finops/export-control review as advisory facts

        ## Non-goals

        - reserve GPUs
- bid/allocate capacity
- install drivers
- run training jobs
- mutate queue scheduling

        ## Safety contract

        - fixture-first by default
        - fail-closed when fixtures are missing
        - no secrets in fixtures, docs, or examples
        - provider output is never shell
        - no provisioning, destruction, queue dispatch, or scheduler changes
