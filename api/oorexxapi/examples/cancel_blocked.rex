/* ============================================================
 * examples/cancel_blocked.rex
 *
 * Cancel queued jobs matching an optional name filter.
 *
 * Usage:
 *   rexx cancel_blocked.rex              -- cancel ALL pending jobs
 *   rexx cancel_blocked.rex oorexx       -- jobs whose name contains "oorexx"
 *   rexx cancel_blocked.rex badjob       -- jobs whose name contains "badjob"
 * ============================================================ */

parse arg nameFilter
nameFilter = nameFilter~strip

q = .BashQueues~user()
say "Connected:" q
if nameFilter = "" then say "Filter:   (all pending)"
else say "Filter:   " || nameFilter
say ""

jobs = q~list~json
if jobs == .nil then do
  say "Could not retrieve job list."
  exit 1
end

say "Total jobs found:" jobs~count
cancelled = 0
skipped   = 0

do job over jobs
  state = job~getState
  qid   = job~getQid
  name  = job~getName

  if state \= "pending" & state \= "pol_blocked" then do
    skipped = skipped + 1
    iterate
  end

  if nameFilter \= "" & name~pos(nameFilter) = 0 then do
    skipped = skipped + 1
    iterate
  end

  say "  cancelling" qid "  [" || name || "]"
  q~cancel(qid)
  cancelled = cancelled + 1
end

say ""
say "Done.  Cancelled:" cancelled "  Skipped:" skipped

::requires "BashQueues.cls"
