# Queue dev AI sessions

`queue dev ai` is an LLM-oriented development activity ledger. It is not an AI
provider, not `queue ask`, and not an authority source. It exists so AI-assisted
maintenance can be bounded, auditable, resumable, and able to learn operational
lessons without relying on chat memory.

## Commands

```text
queue dev ai discover [--json]
queue dev ai session start --agent NAME --role ROLE --task TEXT [--base BASE] [--tag TAG...] [--json]
queue dev ai session lessons [--session SESSION_ID] [--json]
queue dev ai try --session SESSION_ID --intent TEXT [--timeout SEC] [--lesson ID] [--confirm-lesson ID] -- COMMAND...
queue dev ai lesson --session SESSION_ID --try TRY_ID --ok|--fail|--warn --text TEXT [--match GLOB] [--precheck COMMAND] [--json]
queue dev ai session stop --session SESSION_ID --status done|blocked|failed|abandoned --summary TEXT [--next TEXT] [--json]
queue dev ai session list [--json] [--active] [--agent NAME] [--session SESSION_ID] [--tries]
```

## Storage

Sessions are stored under the queue dev root:

```text
.queuebash/dev/ai_sessions/
  AIS-.../
    session.json
    tries.jsonl
    lessons.jsonl
    evidence.jsonl
    summary.md
```

Global lessons are stored as independent files, not a shared monolithic JSONL:

```text
.queuebash/dev/ai_lessons.d/AIL-....json
```

The directory-scanned lesson store is deliberate. It lets parallel patch streams
add lessons without colliding on a single file and lets a new AI session load the
current lesson set at session start.

## Safety boundaries

`queue dev ai try` actually executes commands, but only from a bounded allowlist:

- selected `queue dev` introspection/validation commands
- `bash -n FILE`
- `python3 -m py_compile FILE`
- tests under `tests/`
- `df -h`, `du`, `unzip -l`, and bounded unzip operations

It must not become a generic shell, sudo bridge, network client, or provider API
executor. Lessons guide behaviour but do not grant authority, bypass ACLs, or
replace reviewer acceptance.


## 0.18.93 reconciliation note

`queue dev ai try` may run allowlisted `queue dev ...` commands. Since `queue` is normally a sourced shell function rather than a standalone executable, the queue-dev dispatcher passes `QUEUEBASH_SCRIPT_PATH` into `bin/queue-dev-ai`. The helper then runs allowlisted `queue ...` tries through a bounded `bash -lc` subprocess that sources that script before invoking `queue`. This is required for dogfooding read-only AI commands such as `queue dev ai discover` and `queue dev ai session lessons`. Mutating or recursive AI commands such as `queue dev ai try`, `queue dev ai lesson`, and `queue dev ai learn` remain blocked inside `try`.
