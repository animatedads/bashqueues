# 0.18.93 BOB15 queue-dev-ai dogfood reconciliation merge

Merged Bob14 queue-dev-ai dogfood reconciliation onto refreshed Bob15 0.18.92 external signed display-resource base.

Scope:
- Pass QUEUEBASH_SCRIPT_PATH from queue-dev dispatcher into bin/queue-dev-ai.
- Allow read-only queue-dev-ai self-inspection through queue dev ai try.
- Add learn compatibility alias for lesson.
- Extend dev-ai dogfood smoke tests.
- Carry forward directory-scanned AI lesson records.

Boundaries:
- queue-dev-ai is not an AI provider.
- lessons are not authority and do not bypass ACLs/reviewer acceptance/security policy.
- recursive/mutating AI commands remain blocked inside try.
