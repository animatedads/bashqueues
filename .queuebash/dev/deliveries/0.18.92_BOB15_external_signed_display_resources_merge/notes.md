# 0.18.92 BOB15 external signed display resources merge

Merged Bob12 external signed display-resource support onto Bob15 0.18.91 queue-dev-ai base.

Key points:
- Adds `docs/QUEUE_DISPLAY_RESOURCES.md`.
- Adds external display resources under `resources.d/display/`.
- Adds resource fetch/locale fallback support through `queue resource-fetch-i18nl` / `queue resources`.
- Adds display-resource static/no-shell-eval/smoke tests.
- Preserves command JSON contracts as structured locale-independent JSON.
- Display resources are non-executable presentation files only.

queue-dev-ai lessons recorded during merge:
- Sourced `queue` is a shell function; direct `queue dev ai try -- queue ...` does not inherit it.
- Use bounded `timeout ... bash -lc 'source ./queuebash.sh; queue ...'` for manual function probes.
- `queue dev ai try` is allowlisted and may reject wrapper commands; use it for allowlisted validations and record direct probes as evidence/lessons.
- Some smoke tests need realistic timeouts because sourcing queuebash installs bundled policy/resource trees in temporary roots.
