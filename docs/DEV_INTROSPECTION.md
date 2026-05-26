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
queue dev comment --file FILE --function FUNCTION --message TEXT [--changelog] [--json]
queue dev diff --file FILE [--function FUNCTION] [--json]
queue dev strip --file FILE --function FUNCTION [--json]
queue dev symbols --file FILE [--function FUNCTION] [--json]
queue dev symbols --function FUNCTION [--json]
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

## Symbols

`queue dev symbols` builds a lightweight static symbol table for Bash code. It is
intended to help automated maintainers find constants, variable definitions,
references, string literals, and the function scopes that contain them without
falling back to fragile grep/sed scans.

Examples:

```bash
queue dev symbols --file queuebash.sh --function _queue_dev_patch --json
queue dev symbols --function _queue_worker --json
```

The JSON output includes:

- `functions`: discovered Bash function ranges
- `variables`: definitions, references, scope classification, and function membership
- `constants`: uppercase or readonly-style variables
- `strings`: string literals with line and function context

The analyser is intentionally conservative. Bash variables assigned inside a
function without `local` are reported as `global-write`, because Bash makes those
visible outside the function unless explicitly declared local.

## Python panel developer mode

`queuemgr_panel.py` also supports a non-curses AST/inspect developer interface:

```bash
python3 queuemgr_panel.py --dev functions
python3 queuemgr_panel.py --dev locate main
python3 queuemgr_panel.py --dev extract main
python3 queuemgr_panel.py --dev patch TARGET /tmp/replacement.py
python3 queuemgr_panel.py --dev symbols [TARGET]
```

The Python patcher parses the whole file with `ast.parse()` before writing, so a
syntax-invalid replacement is rejected without modifying the panel. The Python `symbols` command uses the built-in AST to report functions, classes, variables, constants, and string literals.

## Concurrency and backup lifecycle

Mutating developer commands are serialized with an OS file lock next to the target file:

```bash
<target>.dev.lock
```

The following commands take the lock before reading, patching, or writing the target:

- `queue dev patch`
- `queue dev comment`
- `queue dev strip`
- `queue dev rollback`

`queue dev patch` and the Python panel `--dev patch` flow now build the replacement in a temporary file, validate syntax before committing it, verify the backup is readable/non-empty, and then atomically replace the target with `mv`/`os.replace`. Concurrent readers should therefore see either the old complete file or the new complete file, not a partially written file.

Backup growth is bounded by:

```bash
QUEUEBASH_DEV_MAX_BACKUPS=20
```

The newest backups for each target file are retained and older `*.bak.*` files are pruned after successful mutating operations.


## `queue dev flow` — static execution-path graph

`queue dev flow` provides a lightweight static execution-path graph for Bash
files and loaded functions. It is intended for AI-assisted impact analysis before
patching a function.

Usage:

```bash
queue dev flow --file queuebash.sh --function _queue_dev_patch --json
queue dev flow --function _queue_dev_patch --json
```

The JSON output contains:

- `nodes`: function nodes, branch nodes, and terminal `return`/`exit` nodes.
- `edges`: `call`, `recursive-call`, `branch`, `case-pattern`, and `terminal`
  edges.
- `branches`: concise branch records with line numbers and source snippets.
- `summary`: counts for functions, branches, calls, edges, and terminals.

When `--file FILE --function FUNCTION` is used, the whole file is analysed so
other functions remain visible as possible callees, while the output is scoped to
the requested function. Heredoc bodies are masked during analysis; this avoids
false Bash branches from embedded Python, JSON, SQL, or other inline payloads.
