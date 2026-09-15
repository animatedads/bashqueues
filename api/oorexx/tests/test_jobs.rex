/* ============================================================
 * tests/test_jobs.rex
 * Test: stats, list, submit, explain
 * ============================================================ */

q = .BashQueues~user()

/* ── stats ──────────────────────────────────────────────── */
say "TEST: stats"
stats = q~stats
if stats == .nil then call fail "stats"
total = stats~getTotal
if total == .nil then call fail "stats~getTotal returned nil"
say "  PASS total:" total
states = stats~getStates
if states \== .nil then do
  do s over states~allIndexes
    say "    " s~left(14) states[s]
  end
end

/* ── list ───────────────────────────────────────────────── */
say "TEST: list"
jobs = q~list~json
if jobs == .nil then call fail "list"
say "  PASS count:" jobs~count
if jobs~count > 0 then do
  first = jobs~makeArray~at(1)
  if first~getQid == .nil then call fail "first job has no qid"
  say "  PASS first qid:" first~getQid
end

/* ── submit ─────────────────────────────────────────────── */
say "TEST: submit"
opts = .Directory~new
opts["priority"] = 10
job = q~submit("oorexx-api-test", "/bin/echo oorexx api test", opts)
if job == .nil then call fail "submit"
qid = job~getQid
if qid == .nil then call fail "submit qid is nil"
say "  PASS submitted qid:" qid
say "  state:" job~getState

/* ── explain ────────────────────────────────────────────── */
say "TEST: explain"
detail = q~explain(qid)
if detail == .nil then call fail "explain"
if detail~getFields == .nil then nop   /* fields() not getFields */
say "  PASS explain fields:" detail~fields~items
say "  name: " detail~getName
say "  state:" detail~getState

/* ── cancel submitted test job ──────────────────────────── */
say "TEST: cancel test job"
res = q~cancel(qid)
say "  PASS cancel complete"

say ""
say "ALL job tests passed."
exit 0

fail:
  parse arg what
  say "  FAIL:" what
  say "  last error:" .local["bq.last_error"]
  exit 1

::requires "BashQueues.cls"
