# queue dev merge-plan

`queue dev merge-plan` is a bounded, read-only merge intelligence tool for Bob the Merger.
It inspects one or more `queue dev patchset create` zip files and emits a merge report,
JSON plan, collision list, release reconciliation proposal, scratchpad item-merge warnings,
delivery evidence cleanup recommendations, and validation plan.

It does **not** apply patches. It does **not** auto-resolve conflicts. It does **not** unzip
whole patchsets by default.

## Usage

```bash
queue dev merge-plan \
  --base ./bashqueues \
  --patchset bob10.patchset.zip \
  --patchset bob11.patchset.zip \
  --target-version 0.18.82 \
  --json > merge-plan.json

queue dev merge-plan --base ./bashqueues --patchset A.zip --patchset B.zip
queue dev merge-plan explain merge-plan.json
queue dev merge-plan summary merge-plan.json --json
```

Accepted arguments:

```text
--base DIR
--patchset ZIP          may be repeated
--full-delivery ZIP     reserved for future full-delivery analysis
--target-version VER    optional release recommendation
--json
--human
--extract-dir DIR       reserved; v1 reads from zip central directory
--max-bytes N           default bounded member read limit
--keep-workdir          reserved
--extract-all           reserved and not used by v1
```

## Space safety

Default behaviour:

1. Read the zip central directory.
2. Discover patchset root by locating `manifest.json` with sibling `files/`, `baseline/`, or `diffs/`.
3. Read `manifest.json` directly from the zip.
4. Read only touched `files/`, matching `baseline/`, and relevant `diffs/` members up to `--max-bytes`.
5. Never unpack a whole patchset unless a later explicit mode adds that behaviour.

JSON includes extraction statistics:

```json
{
  "zip_bytes": 123456,
  "members_scanned": 42,
  "members_extracted": 6,
  "extracted_bytes": 18321,
  "space_safety": "bounded"
}
```

## Analysis model

Each patchset entry is classified as one of:

```text
add_file
modify_file
delete_file
scratchpad_item_merge
docs_update
test_update
provider_update
policy_update
queuebash_function_update
queuebash_dispatch_update
release_identity_update
delivery_evidence
unknown
```

For `queuebash.sh`, v1 performs bounded static function-boundary analysis and records that
it used `static_fallback_used`. Later versions may call `queue dev functions`, `queue dev
symbols`, `queue dev flow`, and `queue dev extract` when a working target tree is available.
If a dev command fails or times out, the JSON contract requires `failed_or_timeout` plus the
static fallback reason.

Function analysis reports:

```text
function added / modified / deleted
calls
called_by
globals
recommended QBTEST command
```

## Collision classes

The planner distinguishes:

```text
clean_add
same_file_different_area
same_function_same_change
same_function_different_change
same_function_conflict
function_and_caller_changed
dispatcher_overlap
help_inventory_overlap
docs_release_overlap
scratchpad_same_item
scratchpad_distinct_items
test_only_overlap
delivery_evidence_overlap
```

High-risk function and dispatcher overlaps are marked `manual_review_required` or
`conflict_requires_merger` rather than auto-applied.

## Release identity and version overlaps

Version numbers are ledger claims, not compatibility proof. `queue dev merge-plan` reports
competing README, CHANGELOG, and `QUEUEBASH_VERSION` claims as:

```text
release_identity_overlap
version_overlap_policy = ledger_overlap_not_runtime_conflict
```

The tool proposes a target heading and changelog bullets, but Bob the Merger chooses the final
release identity.

## Scratchpad and delivery evidence

Scratchpad handling is item-level only. The tool must never recommend replacing
`.queuebash/dev/scratchpad.json` wholesale.

Root-level delivery evidence such as `merge_manifest*.json`, `validation*.log`, `cleanup*.log`,
and `notes*.md` is classified as cleanup/relocation material and should move under:

```text
.queuebash/dev/deliveries/<delivery-id>/
```

## Non-goals for v1

```text
No automatic conflict resolution.
No full tree unzip by default.
No automatic write to the target tree.
No semantic AI judgement.
No live provider calls.
No dispatch refactor.
No scratchpad wholesale merge.
No assuming newer version number means newer code.
```

## Nightmare fixture hardening

`queue dev merge-plan` must normalize patchset dialects before planning. Known
inputs include canonical `entries[]` manifests, `files[]` manifests with
`change_type`, and `files[]` manifests with `action=add|update`. Unsupported
manifest shapes must produce `manifest_warnings` and must never be silently
accepted as successful zero-entry patchsets.

A zip may also be a patchset container containing one or more inner patchset
zips. The planner treats that as bounded zip inspection: it reads the container
central directory, opens only inner zip members within `--max-bytes`, and reports
`container_member` for the expanded child patchsets.

Generic `.py` and `.sh` files are analysed with the bounded static parser so
fixtures such as `merge_test.py` and `merge_test.sh` can report same-path and
same-function collisions around functions such as `main_test_function`, even
when the patchsets were not generated by the same Bob or manifest schema.
