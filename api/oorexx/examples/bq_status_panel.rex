#!/usr/bin/env rexx
/*
 * Minimal status-panel style example.
 * Inspired by the uploaded ooRexx TUI examples, but deliberately does not
 * depend on the full TUI framework. This keeps the BashQueues API portable
 * and JSON-first.
 */

signal on syntax name fail
signal on novalue name fail

::requires "../BashQueues.cls"

q = .BashQueues~user
stats = q~stats
if stats == .nil then do
  say "stats failed:" q~lastError
  exit 1
end

call line "BashQueues status panel"
call kv "root", q~root
call kv "schema", stats~getSchema
call kv "total", stats~getTotal

states = stats~at("states")
if states \== .nil then do
  call line "states"
  do state over states~allIndexes
    call kv "  " || state, states[state]
  end
end

exit 0

line: procedure
  parse arg text
  say ""
  say "================================================================"
  say "  " || text
  say "================================================================"
  return

kv: procedure
  parse arg key, value
  say key~left(18) || " : " || value
  return

fail:
  say "FAILED in bq_status_panel.rex"
  say condition("C") condition("D")
  exit 99
