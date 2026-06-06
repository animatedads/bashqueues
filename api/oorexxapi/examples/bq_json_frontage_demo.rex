/* Bob31 BashQueues ooRexx JSON frontage smoke demo */

say "================================================================"
say "  BashQueues ooRexx JSON frontage — Bob31 merged Claude API"
say "================================================================"
say ""

q = .BashQueues~user()
say "Connected: " q
say "Root:      " q~root
say "Version:  " q~version
say ""

say "-- stats --"
stats = q~stats
if stats == .nil then call fail "stats", q
say "schema: " stats~getSchema
say "total:  " stats~getTotal
states = stats~getStates
if states \== .nil then do
  do s over states~allIndexes
    say "  " || s~left(14) states[s]
  end
end
say ""

say "-- list --"
jobs = q~list~json
if jobs == .nil then call fail "list", q
say "jobs: " jobs~count
shown = 0
do job over jobs
  shown = shown + 1
  say "  " || job~getQid~left(50) job~getState~left(12) job~getName
  if shown >= 5 then leave
end
say ""

say "-- submit --"
opts = .Directory~new
opts["priority"] = 10
job = q~submit("oorexx-json-frontage-demo", "/bin/echo hello from oorexx json frontage", opts)
if job == .nil then call fail "submit", q
qid = job~getQid
say "submitted qid: " qid
say "state:         " job~getState
say ""

say "-- explain --"
detail = q~explain(qid)
if detail == .nil then call fail "explain", q
say "name:  " detail~getName
say "state: " detail~getState
say "fields:" detail~fields~items
say ""

say "-- dev functions --"
fns = q~dev~functions~json
if fns == .nil then call fail "dev functions", q
say "functions exposed: " fns~count
say ""

say "Demo complete."
exit 0

fail:
  use arg where, q
  say "FAILED during" where
  if q \== .nil then say "Last error:" q~lastError
  else say "Last error:" .local["bq.last_error"]
  exit 1

::requires "BashQueues.cls"
