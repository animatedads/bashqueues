# 0.18.50 Bob the Merger repaired full delivery

This package repairs the round2 full-delivery bounce and then applies the next merge inventory against the current Bob Merger master.

## Reviewer blockers repaired

- Removed Python cache debris from the package.
- Repaired `queue dev patchset inspect --target` behaviour for new/unbaselined files by avoiding unrequested whole-file function precondition bundles. This keeps JSON bounded and deterministic unless `--function` was explicitly requested.

## Additional patchsets merged

- Bob11 OpenAI-compatible local/private ask-provider pack.
- Bob10 cloud resource reconcile enhancement.
- Bob2 repaired static version-pin cleanup where still applicable.
- Bob2 static version-pin policy guard.

## Version policy

Ledger and version-number overlaps are expected merger hits. Runtime version is `0.18.50` here because accepted runtime/provider command surface was added. The Bob2 `0.18.51` guard is recorded as a static-test policy guard only and is not treated as a runtime bump.
