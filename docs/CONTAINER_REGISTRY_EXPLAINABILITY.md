# Container registry explainability

Container registry facts must explain why an image or digest is acceptable or
blocked for governance review.

Required explanation fields include:

- `registry`
- `repository`
- `tag` or `digest`
- `architectures`
- `signature_status`
- `sbom_status`
- vulnerability counts
- retention/legal-hold posture
- `decision`
- `reason`
- `fail_closed`
- `mutated`

The provider helper must never return shell commands. queuebash consumers may use
these facts for policy review, but must not execute provider output.
