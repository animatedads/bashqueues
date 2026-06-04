# Event Stream legal and compliance notes

The event_stream provider family is fixture-first. Default tests do not contact live services, retrieve data, alter retention, modify access, or create provider resources.

Compliance review should treat outputs as redacted metadata and advisory facts. Live-provider support, if later added, must be opt-in, audited, policy-gated, and credential-safe.
