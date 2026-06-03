# Secret Manager explainability notes

The `secret_manager` provider family is intended to explain provider capability and governance facts without executing service operations. Provider helpers must never return shell commands or command fragments. queuebash and reviewers consume the JSON evidence as advisory context only.

Explainability expectations:

- every response has a schema, provider_family, provider, decision, fail_closed, and mutated field
- deny/fail-closed responses include a reason and remediation hint
- fixtures distinguish metadata from protected values
- live behaviour, when later added, must be separately gated and auditable

Lessons for AI sessions:

- do not infer live support from fixture-first contracts
- verify provider-family presence from the tree and JSON contract tests before claiming files are missing
- treat provider facts as policy evidence, not as queue commands
