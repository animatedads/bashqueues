# 0.18.91 BOB15 queue-dev-ai session lessons merge

Merged Bob14 queue-dev-ai session/try/lesson contract onto Bob15 0.18.90 command JSON wave 3 base.

Bob15 verified the exposed function path:
- `queue dev functions` finds `_queue_dev_command` and `_queue_dev_merge_plan_command`.
- `queue dev extract _queue_dev_command --file queuebash.sh` shows `ai|llm-session|ai-session` delegating to `bin/queue-dev-ai`.
- `queue dev ai discover --json` reports the bounded AI development-session contract.
- `queue dev ai session start`, `try`, `lesson`, `session lessons`, and `session stop` work.

A package-local AI lesson was recorded under `.queuebash/dev/ai_lessons.d/` using the new interface. It is informational (`severity=info`) and does not block future tries.

Boundaries preserved:
- not an AI provider
- not an authority source
- lessons do not bypass ACL/reviewer/security policy
- `try` command execution remains allowlisted and timeout-bounded
