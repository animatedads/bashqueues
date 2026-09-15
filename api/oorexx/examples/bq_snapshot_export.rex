#!/usr/bin/env rexx
/*
 * Snapshot example.
 * The uploaded serializer examples are useful ooRexx reference material, but
 * bashq's public interchange should stay JSON. This writes raw queue JSON to
 * a file for later inspection by ooRexx, Python, jq, or shell tools.
 */

signal on syntax name fail
signal on novalue name fail

::requires "../BashQueues.cls"

outfile = "queue_snapshot.json"
if arg() > 0 then outfile = arg(1)

q = .BashQueues~user
raw = q~raw("list --json")
if raw = "" then do
  say "list failed:" q~lastError
  exit 1
end

s = .Stream~new(outfile)
s~open("WRITE REPLACE")
rc = s~lineout(raw)
s~close

say "wrote" outfile
exit 0

fail:
  say "FAILED in bq_snapshot_export.rex"
  say condition("C") condition("D")
  exit 99
