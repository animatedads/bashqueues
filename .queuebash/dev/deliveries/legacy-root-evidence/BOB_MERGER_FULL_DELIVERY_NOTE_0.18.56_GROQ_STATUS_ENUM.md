# 0.18.56 Bob Merger full delivery: Groq provider and scratchpad status enum guard

Merged Bob11 Groq ask-provider support and Bob2 scratchpad status enum guard onto the accepted 0.18.56 QBTEST example/timeout-helper full-delivery base.

Patch tooling was used first. Bob2 applied directly. Bob11 Groq preconditions were independent for provider/docs files, but its queuebash full-file application would have reintroduced stale QBTEST help/example text, so queuebash Groq provider integration was reconciled manually while preserving the accepted EXAMPLE_QBTEST escape behaviour and the absence of the old fake/malformed QBTEST entry.
