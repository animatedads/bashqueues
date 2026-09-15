/* ============================================================
 * examples/list_by_state.rex
 *
 * List jobs filtered by state with a summary.
 *
 * Usage:
 *   rexx list_by_state.rex              -- list all jobs
 *   rexx list_by_state.rex pending      -- pending only
 *   rexx list_by_state.rex done         -- done only
 *   rexx list_by_state.rex failed       -- failed only
 * ============================================================ */

parse arg stateFilter
stateFilter = stateFilter~strip~lower

q = .BashQueues~user()

jobs = q~list~json
if jobs == .nil then do
  say "Could not retrieve job list:" .local["bq.last_error"]
  exit 1
end

/* tally by state */
tally = .Directory~new
do job over jobs
  s = job~getState~lower
  if tally~hasIndex(s) then tally[s] = tally[s] + 1
  else tally[s] = 1
end

say "Total:" jobs~count
do s over tally~allIndexes
  say "  " s~left(14) tally[s]
end
say ""

/* filter and display */
if stateFilter \= "" then
  say "Jobs in state:" stateFilter
else
  say "All jobs:"

do job over jobs
  if stateFilter \= "" & job~getState~lower \= stateFilter then iterate
  say "  " job~getQid~left(52) ,
      job~getName~left(30) ,
      "state:" job~getState~left(12) ,
      "pri:" job~getPriority
end

::requires "BashQueues.cls"
