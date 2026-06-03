# GPU Marketplace explainability notes

Every `gpu_marketplace` decision is explainable through a fixture JSON document with schema, provider_family, provider, decision, fail_closed, and mutated fields. The facts are intentionally conservative: they describe observed/advisory capability and governance posture, not permission to execute live actions.

Reviewers should treat these records as inputs to policy gates. They are not acceptance evidence for live provider support and they do not promote a provider to first-tier parity.
