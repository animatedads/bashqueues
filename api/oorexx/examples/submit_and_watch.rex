/* ============================================================
 * examples/submit_and_watch.rex
 *
 * Submit a job and poll until it reaches a terminal state.
 *
 * Usage:
 *   rexx submit_and_watch.rex "job-name" "-- /path/to/command"
 *   rexx submit_and_watch.rex "echo-test" "-- /bin/echo hello"
 * ============================================================ */

parse arg jobName jobCmd
jobName = jobName~strip
jobCmd  = jobCmd~strip

if jobName = "" then do
  say "Usage: rexx submit_and_watch.rex name -- command"
  exit 2
end

q = .BashQueues~user()

/* ── Submit ──────────────────────────────────────────────── */
opts = .Directory~new
opts["priority"] = 10
say "Submitting:" jobName jobCmd
job = q~submit(jobName, jobCmd, opts)
if job == .nil then do
  say "Submit failed:" .local["bq.last_error"]
  exit 1
end

qid = job~getQid
say "Submitted:  " qid
say "State:      " job~getState
say ""

/* ── Poll ────────────────────────────────────────────────── */
terminalStates = .Set~of("done", "failed", "cancelled", "interrupted", "deleted")
maxWait  = 60        /* seconds */
interval = 3
elapsed  = 0

say "Waiting for terminal state (max" maxWait "s)..."
do while elapsed < maxWait
  call SysSleep interval
  elapsed = elapsed + interval

  detail = q~explain(qid)
  if detail == .nil then iterate

  state = detail~getState
  say "  " || elapsed~right(3) || "s  state:" state

  if terminalStates~hasIndex(state~lower) then do
    say ""
    say "Terminal state reached:" state
    say "Exit code:" detail~getExitCode
    leave
  end
end

if elapsed >= maxWait then
  say "Timed out after" maxWait "seconds"

/* ── Final explain ───────────────────────────────────────── */
say ""
say "Final state:"
detail = q~explain(qid)
if detail \== .nil then do
  do f over detail~fields
    val = detail~raw[f]
    if val \== .nil then say "  " || f~left(22) val~string~left(55)
  end
end

::requires "BashQueues.cls"
