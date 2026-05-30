# Queue dev file registry

`queue dev files` records files touched by a development stream. It is intended
for multistream Bob/AI work where a reviewer needs to know which files were
opened, why they were edited, what their baseline checksum was, and which
functions changed.

Commands:

```text
queue dev files begin --file FILE --purpose TEXT [--location TEXT] [--function NAME...] [--json]
queue dev files finish --file FILE [--purpose TEXT] [--function NAME...] [--json]
queue dev files add --file FILE --purpose TEXT [--location TEXT] [--function NAME...] [--json]
queue dev files remove --file FILE [--reason TEXT] [--json]
queue dev files list [--all] [--json]
queue dev files changed [--all] [--json]
queue dev files scan [--all] [--json]
queue dev files path [--json]
```

The normal edit lifecycle is:

```text
1. begin: copy the file to a private baseline backup and record old file/function MD5s
2. edit: change the working-tree file
3. test: run focused internal tests
4. finish: compute new file/function MD5s and changed-function metadata
5. patchset create: export changed files and merge checks
```

The registry is append/audit oriented. `remove` marks a registry entry removed;
it does not delete source files or patch evidence.

## Multistream safety

For changed functions the registry records:

```json
{"function":"name","old_md5":"...","new_md5":"..."}
```

Patch-set merge scripts use the old function MD5s as preconditions. If the target
file differs from the original baseline, the script can still permit review only
when every changed function still has the expected old MD5. This lets unrelated
parallel edits in the same file be detected instead of blindly overwritten.

## Registry MD5 scan

`queue dev files scan` refreshes the current size, file MD5, and function metadata for all tracked files that still exist. It does not create a new baseline and it does not convert a missing baseline MD5 into an unchanged state. A tracked file with no old MD5 remains new/unbaselined/changed until explicitly resolved by a later lifecycle decision.

New files added with `queue dev files add` are therefore included by `queue dev files changed` and by `queue dev patchset create`, even when their baseline MD5 is `null`.
