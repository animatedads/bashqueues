# 0.18.95 BOB15 hot-seat service coverage wave3, suite cd cleanup, and display-help extraction merge

Merged three patch streams onto the 0.18.94 Bob15 base:

- Bob12 suite root-cd continuation.
- Bob14 fixture-first GPU marketplace and distributed-framework service coverage.
- Bob16 display/help resource extraction.

Release identity was normalized to Bob15 0.18.95. README/CHANGELOG were reconciled manually because Bob16 was lane-local 0.18.94 and Bob14 carried its own 0.18.95 changelog section. Scratchpad was merged by item id only.

Boundaries preserved: no live provider calls, no GPU allocation, no framework launch, no image/object mutation, no provisioning, no queue dispatch refactor, no executable display text, and assets.d/net_usage.sh remains absent.
