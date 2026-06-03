# Distributed Framework provider contracts

        This package adds a fixture-first `distributed_framework` provider family for bashqueues service coverage.

        ## Scope

        The helper returns normalized JSON facts only. It is an advisory contract used by policies, docs, and future controlled integrations. It does not perform live API calls by default and does not require credentials for tests.

        ## Facts

        - detect Ray/Spark/Dask-like framework facts from fixtures
- explain runtime/cluster/data-access/governance facts
- make cluster authority explicit as false by default

        ## Non-goals

        - start clusters
- submit framework jobs
- scale workers
- execute provider-supplied code
- replace queue scheduling

        ## Safety contract

        - fixture-first by default
        - fail-closed when fixtures are missing
        - no secrets in fixtures, docs, or examples
        - provider output is never shell
        - no provisioning, destruction, queue dispatch, or scheduler changes
