# queue dev introspection tools

`queue dev` exposes a small metaprogramming surface for maintaining bashqueues
without fragile grep/sed edits. It is intended for dogfooding, scripted
validation, and AI-assisted maintenance.

## Commands

```bash
queue dev functions [--json] [prefix]
queue dev locate FUNCTION [--json]
queue dev extract FUNCTION [--json]
queue dev scope [--json] [--prefix PREFIX]
queue dev patch --file FILE --function FUNCTION --source SOURCE [--json]
```

## Locate

`queue dev locate FUNCTION --json` uses Bash `extdebug` / `declare -F` to return
the file and starting line for a loaded function.

```json
{"function":"_queue_worker","file":"/path/queuebash.sh","line_start":412}
```

## Extract

`queue dev extract FUNCTION --json` uses `declare -f` so callers receive the
complete function body without guessing where it ends.

## Patch

`queue dev patch` replaces one function in a Bash file with the contents of a
source file. It writes a timestamped backup, builds a temporary patched file, and
runs `bash -n` before replacing the target. If syntax validation fails, the target
file is not changed.

Example:

```bash
queue dev patch \
  --file queuebash.sh \
  --function _queue_worker \
  --source /tmp/new_queue_worker.sh \
  --json
```

The patcher is deliberately function-scoped. It is not a general arbitrary text
replacement tool.

## Comment

`queue dev comment` inserts a standard AI patch marker immediately above a
function and can append the same reasoning to `CHANGELOG.md`.

```bash
queue dev comment \
  --file queuebash.sh \
  --function _queue_worker \
  --message "Explain why this patch exists" \
  --changelog \
  --json
```

Timestamps are generated with `TZ=Europe/London` so they line up with the normal
operator timeline.

## Diff

`queue dev diff` compares a live file with the newest semantic patch backup made
by `queue dev patch`. With `--function`, the output is restricted to that
function body.

```bash
queue dev diff --file queuebash.sh --function _queue_worker --json
```

The JSON includes `status`, `lines_added`, `lines_removed`, and `diff_summary`.

## Strip / rollback

`queue dev strip` restores one function from the newest patch backup and prunes
adjacent `# [AI-PATCH ...]` comments left above that function.

```bash
queue dev strip --file queuebash.sh --function _queue_worker --json
```

This is intentionally function-scoped: it rolls back one semantic unit without
throwing away unrelated edits elsewhere in the file.

## Python panel developer mode

`queuemgr_panel.py` also supports a non-curses AST/inspect developer interface:

```bash
python3 queuemgr_panel.py --dev functions
python3 queuemgr_panel.py --dev locate main
python3 queuemgr_panel.py --dev extract main
python3 queuemgr_panel.py --dev patch TARGET /tmp/replacement.py
```

The Python patcher parses the whole file with `ast.parse()` before writing, so a
syntax-invalid replacement is rejected without modifying the panel.
