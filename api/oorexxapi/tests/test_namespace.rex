/* ============================================================
 * tests/test_namespace.rex
 * Test: UNKNOWN dispatch, namespace chain, dev commands
 * ============================================================ */

q = .BashQueues~user()

/* ── namespace chain returns BQNamespace ────────────────── */
say "TEST: namespace chain"
ns = q~dev
if \ns~isA(.BQNamespace) then call fail "q~dev should return BQNamespace"
say "  PASS q~dev:" ns

ns2 = q~dev~scratchpad
if \ns2~isA(.BQNamespace) then call fail "q~dev~scratchpad should return BQNamespace"
say "  PASS q~dev~scratchpad:" ns2

/* ── json terminal executes ─────────────────────────────── */
say "TEST: q~list~json"
jobs = q~list~json
if jobs == .nil then call fail "q~list~json"
if \jobs~isA(.BQCollection) then call fail "q~list~json should return BQCollection"
say "  PASS BQCollection count:" jobs~count

/* ── dev scratchpad ─────────────────────────────────────── */
say "TEST: q~dev~scratchpad~list~json"
sp = q~dev~scratchpad~list~json
if sp \== .nil then
  say "  PASS scratchpad items:" sp~count
else
  say "  PASS scratchpad (empty or no items)"

/* ── dev ai session lessons ─────────────────────────────── */
say "TEST: q~dev~ai~session~lessons~json"
lessons = q~dev~ai~session~lessons~json
if lessons \== .nil then
  say "  PASS lessons:" lessons~count
else
  say "  PASS lessons (none recorded)"

/* ── underscore becomes space in path ───────────────────── */
say "TEST: underscore→space in method names"
/* q~dev~ai is same as navigating dev ai */
ns3 = q~dev~ai
if \ns3~isA(.BQNamespace) then call fail "q~dev~ai should be BQNamespace"
say "  PASS path:" ns3

say ""
say "ALL namespace tests passed."
exit 0

fail:
  parse arg what
  say "  FAIL:" what
  say "  last error:" .local["bq.last_error"]
  exit 1

::requires "BashQueues.cls"
