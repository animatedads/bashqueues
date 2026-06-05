# Cache Service legal and compliance boundary

This provider family is fixture-first and read-only. It is suitable for documentation, compliance evidence mapping, and UI/fronting contract tests.

It must not be used to perform live provider changes, access secrets, alter customer traffic/data, or infer authority to provision resources. Legal/compliance controls are represented as normalized JSON facts only.
