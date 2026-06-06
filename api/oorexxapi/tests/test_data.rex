/* ============================================================
 * tests/test_data.rex
 * Test: BQData GET/HAS/fields, BQCollection filter/iterate
 * ============================================================ */

q = .BashQueues~user()

/* ── BQData from stats ──────────────────────────────────── */
say "TEST: BQData field access"
stats = q~stats
if stats == .nil then call fail "stats"
if \stats~isA(.BQData) then call fail "stats should be BQData"

/* GET prefix */
total = stats~getTotal
say "  PASS getTotal:" total

/* HAS prefix */
if \stats~hasTotal then call fail "hasTotal should be true"
say "  PASS hasTotal: 1"
if stats~hasNonsenseField then call fail "hasNonsenseField should be false"
say "  PASS hasNonsenseField: 0"

/* fields() */
flds = stats~fields
if flds == .nil then call fail "fields() returned nil"
say "  PASS fields count:" flds~items
do f over flds
  say "    " f
end

/* raw() */
raw = stats~raw
if \raw~isA(.Directory) then call fail "raw() should return Directory"
say "  PASS raw is Directory"

/* ── BQCollection from list ─────────────────────────────── */
say "TEST: BQCollection"
jobs = q~list~json
if jobs == .nil then call fail "list"

say "  count:" jobs~count

/* iterate */
shown = 0
do job over jobs
  if \job~isA(.BQData) then call fail "collection item should be BQData"
  shown = shown + 1
  if shown = 1 then
    say "  PASS first item qid:" job~getQid
  if shown >= 3 then leave
end

/* filter */
say "TEST: BQCollection~filter"
done = jobs~filter("state", "done")
if \done~isA(.BQCollection) then call fail "filter should return BQCollection"
say "  PASS done jobs:" done~count

cancelled = jobs~filter("state", "cancelled")
say "  PASS cancelled jobs:" cancelled~count

/* ── camelCase to snake_case conversion ─────────────────── */
say "TEST: camelCase field resolution"
if jobs~count > 0 then do
  first = jobs~makeArray~at(1)
  /* getJobId should resolve to job_id if present */
  qidDirect = first~getQid
  say "  PASS getQid:" qidDirect
  /* getName should resolve to name */
  nameVal = first~getName
  say "  PASS getName:" nameVal
end

say ""
say "ALL data tests passed."
exit 0

fail:
  parse arg what
  say "  FAIL:" what
  say "  last error:" .local["bq.last_error"]
  exit 1

::requires "BashQueues.cls"
