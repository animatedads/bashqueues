#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "FAIL: $*" >&2; exit 1; }

[[ -f queuebash.sh ]] || fail "run from repository root"
[[ -f docs/JOB_RESOLUTION_INVENTORY.md ]] || fail "missing job resolution inventory doc"

grep -Eq 'QUEUEBASH_VERSION="0\.[0-9]+\.[0-9]+"' queuebash.sh || fail "queuebash version string missing/malformed"
grep -Eq 'WIZARD_VERSION="0\.[0-9]+\.[0-9]+"' bin/queue-policy-wizard || fail 'wizard version string missing/malformed'

doc="docs/JOB_RESOLUTION_INVENTORY.md"

grep -q 'This document inventories' "$doc" || fail "doc does not describe inventory purpose"
grep -q 'does not extract helpers and does not change command behaviour' "$doc" || fail "doc must state no behaviour change"
grep -q '_queue_find_jobs "\$target"' "$doc" || fail "doc missing _queue_find_jobs primitive"
grep -q '_queue_exact_name_count' "$doc" || fail "doc missing exact-name primitive"
grep -q '_queue_print_matches' "$doc" || fail "doc missing print-matches primitive"
grep -q '_queue_resolve_job_operand TARGET MODE' "$doc" || fail "doc missing future helper sketch"

for token in \
  '`deps`, `dependencies`' \
  '`explain`' \
  '`status job` / `_queue_status_job`' \
  '`show`' \
  '`tail`, `follow`' \
  '`stream`' \
  '`metrics`, `unit`, `metric`' \
  '`pids`, `pid`, `ps`' \
  '`hooks`, `hook`' \
  '`onsuccess`, `on-success`, `onok`, `onfailure`, `on-failure`, `onfail`' \
  '`priority`, `prio`, `dynamic-prio`' \
  '`cancel`, `kill`' \
  '`pause`, `hold`, `delete`, `del`, `rm`, `remove`' \
  '`unpause`, `resume`, `release`' \
  '`undelete`, `undel`, `restore`' \
  '`resubmit`, `retry`'; do
  grep -Fq "$token" "$doc" || fail "inventory missing command branch: $token"
done

for class in \
  'read-only group allowed' \
  'single job required' \
  'mutating group allowed by exact name' \
  'mutating strict with force' \
  'state-scoped mutating group allowed by exact name' \
  'state-filtered mutating clone'; do
  grep -Fq "$class" "$doc" || fail "inventory missing classification: $class"
done

# Inventory-only release: the future helper must be documented but not implemented yet.
if grep -q '^_queue_resolve_job_operand()' queuebash.sh; then
  fail "inventory release must not implement _queue_resolve_job_operand yet"
fi

# The existing dispatcher patterns should still be present for the next package to refactor.
grep -q '_queue_find_jobs "\$target"' queuebash.sh || fail "queue dispatcher no longer contains expected target lookup pattern"
grep -q 'ambiguous QID prefix' queuebash.sh || fail "queue dispatcher no longer contains ambiguity diagnostics"

echo "PASS internal_refactor_job_resolution_inventory_static"
