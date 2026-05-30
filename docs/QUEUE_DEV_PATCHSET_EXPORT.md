# Queue dev patch-set export

`queue dev patchset create` exports a self-contained review bundle from the dev
file registry.

```text
queue dev patchset create --output PATCHSET.zip [--registry FILE] [--json]
```

The zip contains only changed files and review material:

```text
manifest.json
files/<changed paths>
diffs/<changed paths>.diff
baseline/<baseline paths>
review_diff.sh
apply_patchset.sh
scripts/check_preconditions.py
scripts/apply_files.py
```

`manifest.json` uses schema `queuebash.dev_patchset.v1` and includes old/new file
MD5s plus per-function old/new MD5s for changed functions. `review_diff.sh`
prints precondition status and diffs. `apply_patchset.sh` refuses to copy files
unless preconditions pass.

The bundle is designed for reviewers who do not want two full codebases open side
by side. The diffs and checksums travel with the changed files.

## New-file preconditions

Patch-set manifests may contain entries where `file_old_md5` is `null`. That means the file is new or unbaselined and must still be exported as changed. `apply_patchset.sh` accepts a missing target path for such entries, accepts an already-present target only when it already has the expected new MD5, and refuses to overwrite a conflicting pre-existing target.
