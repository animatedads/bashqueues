/* ============================================================
 * tests/test_connect.rex
 * Test: connectivity, surface discovery, version, health
 * ============================================================ */

say "TEST: connect"
q = .BashQueues~user()
if q == .nil then call fail "BashQueues~user() returned nil"
say "  PASS connected:" q

say "TEST: version"
v = q~version()
if v = "" then call fail "version returned empty"
say "  PASS version:" v

say "TEST: surface loaded"
surf = q~_surface
if \surf~loaded then call fail "surface not loaded"
say "  PASS surface:" surf~string
say "  namespaces:"
do ns over surf~namespaces
  say "    queue" ns
end

say "TEST: health"
h = q~health
if h == .nil then call fail "health returned nil"
say "  PASS health:" h~string

say ""
say "ALL connect tests passed."
exit 0

fail:
  parse arg what
  say "  FAIL:" what
  say "  last error:" .local["bq.last_error"]
  exit 1

::requires "BashQueues.cls"
