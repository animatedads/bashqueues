# Queue dev AI lessons

AI lessons are operational memory attached to observed tries. They are designed
for repeated tool-use learning: what command was attempted, what happened, what
should be checked next time, and whether a future matching try should warn or
block until acknowledged.

## Lesson lifecycle

1. Start a session.
2. Run a bounded `queue dev ai try -- COMMAND...`.
3. Attach a lesson with `queue dev ai lesson --ok`, `--fail`, or `--warn`.
4. Future sessions scan `.queuebash/dev/ai_lessons.d/*.json`.
5. Matching active warning lessons block a future try until the AI runs a
   lesson-directed precheck, confirms the lesson, or overrides it with a reason.

## Example

```text
queue dev ai session start --agent bob14 --role provider-family --task "apply patch" --json
queue dev ai try --session AIS-... --intent "inspect archive" -- unzip -l file.zip
queue dev ai lesson --session AIS-... --try AIT-... --fail \
  --text "Check disk space and extracted archive size before unzipping large archives." \
  --match "unzip *.zip*" \
  --precheck "df -h . && unzip -l {{ZIPFILE}} | tail -1" \
  --json
```

The next matching unzip try is blocked by the active lesson until addressed.

## Acceptance boundary

Lessons are evidence and guidance. A matched lesson is not acceptance, an
override is not approval, and lesson confirmation must not bypass policy,
remote-admin ACLs, dual control, or reviewer authority.


## 0.18.93 reconciliation note

`queue dev ai try` may run allowlisted `queue dev ...` commands. Since `queue` is normally a sourced shell function rather than a standalone executable, the queue-dev dispatcher passes `QUEUEBASH_SCRIPT_PATH` into `bin/queue-dev-ai`. The helper then runs allowlisted `queue ...` tries through a bounded `bash -lc` subprocess that sources that script before invoking `queue`. This is required for dogfooding read-only AI commands such as `queue dev ai discover` and `queue dev ai session lessons`. Mutating or recursive AI commands such as `queue dev ai try`, `queue dev ai lesson`, and `queue dev ai learn` remain blocked inside `try`.
