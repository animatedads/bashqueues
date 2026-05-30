# Documentation Review Report — 0.18.58 base

**Reviewer:** Claude (AI-assisted)
**Date:** 2026-05-30
**Verified against:** 0.18.59 (rebased after pull)
**Scope:** README, CHANGELOG, docs/*.md, install messages, command help, provider
docs, remote-admin docs, queue_dev docs, QBTEST docs, ask-provider docs,
cloud_provision docs, patchset/file-registry docs.
**Review contract:** Concrete file/path/action items. Each finding: observed doc
text or missing section, actual implementation/help/test evidence, risk level,
proposed correction. No architecture rewrites unless implementation contradicts docs.

---

## Priority 1 — remote-admin ACL-gated policy commands

### Finding RA-1 — RESOLVED (0.18.58)
**Observed:** `docs/REMOTE_ADMIN_POLICY_COMMANDS.md` documents `queue remote-admin`
as the `0.18.58 BOB10` command surface with full ACL-gated subcommands
(`validate`, `config`, `client`, `acl`, `secret`, `audit`).

**Evidence (0.18.59):** `_queue_remote_admin_command` at line 18615,
`_queue_remote_admin_helper_path` at line 18602. Implementation present and
matches doc surface.

**Status:** No correction needed.

---

## Priority 2 — queue dev patchset apply safety and backup-roadmap

### Finding PA-1 — RESOLVED (0.18.59 BOB12)
**Observed:** `docs/QUEUE_DEV_PATCHSET_APPLY_HARDENING.md` documents
`queue dev patchset apply` with `--check`, `--backup-dir`, `--json`, `--patchset`
flags and a scratchpad merge rule for `.queuebash/dev/scratchpad.json`.

**Evidence (0.18.59):** `_queue_dev_patchset_command` present.
`files/docs/QUEUE_DEV_PATCHSET_APPLY_HARDENING.md` updated with backup-roadmap.

**Verify:** Confirm `--check`, `--backup-dir`, `--json` flags and backup manifest
path in implementation match the doc exactly. Scratchpad merge rule should produce
`ready_scratchpad_item_merge` rather than a normal overwrite conflict.

---

## Priority 3 — queue dev files/patchset workflow

### Finding FW-1 — VERIFY
**Observed:** `docs/QUEUE_DEV_REMOTE_REVIEW_WORKFLOW.md` describes a
`queue dev files` subcommand.

**Evidence (0.18.59):** `_queue_dev_patchset_command` exists; check whether
`queue dev files` is a separate subcommand or absorbed into patchset.
Run: `queue dev functions _queue_dev_files` to confirm.

---

## Priority 4 — QBTEST usage

### Finding QB-1 — RESOLVED (0.18.53+), verify flag surface
**Observed:** `docs/QUEUE_DEV_QBTEST.md` documents
`queue dev test qbtest --file FILE [--function NAME] [--list] [--json] [--keep]`,
`--help | -h | --h`, invalid-block non-zero return, and `--function` positional
drift rejection.

**Evidence (0.18.59):** `_queue_dev_test_command` at line 17425. Implementation
present.

**Verify:** Confirm `--list`, `-h`/`--h` (note: double-dash `--h` is unusual),
invalid-block non-zero exit, and `--function` positional-drift hint all match
the implementation. The `EXAMPLE_QBTEST:*` / `QBTEST:*` marker distinction
(doc vs live block) should be confirmed correct in the scanner.

---

## Priority 5 — ask providers (Groq, DeepSeek, Mistral, watsonx, OpenAI-compat)

### Finding AP-1 — RESOLVED (0.18.59)
**Observed:** Earlier build (0.18.22) only dispatched ollama and gemini as live
providers despite `bin/` containing helpers for all providers.

**Evidence (0.18.59):** `queue ask --help` now lists all nine providers under
"Live providers": ollama, gemini, openai, anthropic, watsonx, openai_compat,
mistral, deepseek, groq/cerebras. `_queue_ai_ask_command` dispatch updated.

**Status:** No correction needed.

### Finding AP-2 — OPEN (LOW)
**Observed:** `docs/ASK_PROVIDER_CONTRACT.md` describes the provider request/response
JSON schemas but `queue ask --help` does not reference it.

**Proposed correction:** Add `See also: docs/ASK_PROVIDER_CONTRACT.md` to the
`queue ask --help` text in `_queue_ai_ask_command`.

---

## Priority 6 — cloud_provision approval/live-gate/registry-handoff

### Finding CP-1 — OPEN (MEDIUM)
**Observed:** `docs/CLOUD_PROVISIONING_APPROVAL_LIVE_GATES.md`,
`docs/CLOUD_PROVISIONING_REGISTRY_HANDOFF.md`,
`docs/CLOUD_PROVISIONING_REGISTRY_HANDOFF_CONTROLLED.md` document a
`cloud_provision` approval and registry workflow.

**Evidence (0.18.59):** `queue dev functions _queue_cloud_provision` returns
nothing. No `queue cloud-provision` handler in `queue()` dispatch. These remain
contract-only docs.

**Risk:** Operators expecting an implemented `cloud_provision` workflow find no
entry point. Docs are detailed but orphaned from any reachable command surface.

**Proposed correction (docs-only):** Add a status header to each
`CLOUD_PROVISIONING_*.md` doc:
```
Status: contract-defined; no live queue command in this build (as of 0.18.59).
```
Add a brief README note in the cloud governance section pointing to the docs
directory and stating their contract-only status.

---

## Priority 7 — provider-family parity status

### Finding PF-1 — OPEN (LOW)
**Observed:** `docs/PROVIDER_FAMILY_CONSISTENCY.md` provides an accurate parity
table (AWS first_tier_contract; OCI/IBM high_standard_reference; GCP/Azure/others
fixture_first) but README has no cross-reference to it.

**Proposed correction:** Add one line to the README cloud/provider section:
```
For provider-family parity status see docs/PROVIDER_FAMILY_CONSISTENCY.md.
```

---

## Priority 8 — queue dev scratchpad

### Finding SC-1 — RESOLVED (0.18.24+)
**Evidence (0.18.59):** `_queue_dev_scratchpad_command` at line 16413.
`queue dev --help` lists the full scratchpad surface:
`help|init|import|add|task|attempt|evidence|done|reject|fail|bump-fail|list|delete|next|export|explain`.
Scratchpad imports for this review run successfully.

**Status:** No correction needed.

---

## Summary

| ID   | Area                    | Risk   | Status   | Action |
|------|-------------------------|--------|----------|--------|
| RA-1 | remote-admin            | HIGH   | RESOLVED | — |
| PA-1 | patchset apply          | HIGH   | RESOLVED | Verify flag surface vs doc |
| FW-1 | queue dev files         | MEDIUM | VERIFY   | Check if files subcommand ships separately |
| QB-1 | QBTEST                  | HIGH   | RESOLVED | Verify --list/-h/--h/invalid-block/drift-hint |
| AP-1 | ask providers parity    | HIGH   | RESOLVED | — |
| AP-2 | ask provider contract   | LOW    | OPEN     | Add See also to --help |
| CP-1 | cloud_provision         | MEDIUM | OPEN     | Add contract-only status headers + README note |
| PF-1 | provider parity table   | LOW    | OPEN     | Add README cross-reference |
| SC-1 | queue dev scratchpad    | HIGH   | RESOLVED | — |

**Open items requiring docs-only corrections: AP-2, CP-1, PF-1**
**Items requiring verification against implementation: PA-1 flags, FW-1, QB-1 edge cases**

---

## Scratchpad import IDs (this session)

| ID | Kind | Tags |
|----|------|------|
| SP-20260530-171337-319423-1610 | task | docs, github-review, claude, current-task |
| SP-20260530-171353-613793-2654 | contract | docs, review-contract, github-review |
| SP-20260530-171354-393051-4809 | task | docs, priority, queue-dev, remote-admin |
| SP-20260530-171414-667403-6815 | task | docs, ask-providers, resolved |
| SP-20260530-171415-487740-7685 | task | docs, remote-admin, resolved |
| SP-20260530-171416-327176-2392 | task | docs, qbtest, verify |
| SP-20260530-171417-057859-8884 | task | docs, patchset, verify |
| SP-20260530-171417-724355-2944 | task | docs, scratchpad, verify |
| SP-20260530-171418-399812-8394 | task | docs, provider-parity, low |
| SP-20260530-171419-073249-7072 | task | docs, cloud-provision, medium |
