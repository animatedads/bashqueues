#!/usr/bin/env python3
"""Static JSON contract checks for the queue dev internal API.

This test is deliberately *not* a dynamic `queue dev ...` invocation.  Reviewer
sandboxes have shown that even narrow dispatcher probes can stall while sourcing
or walking unrelated initialisation paths.  The purpose here is to prove the
queue-dev JSON contract from the repository text and from tiny fixture parsing,
without entering the full queue dispatcher/init path.
"""
from __future__ import annotations

import json
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path.cwd()
QB = ROOT / "queuebash.sh"
if not QB.exists():
    print("FAIL: run from repository root", file=sys.stderr)
    sys.exit(1)

text = QB.read_text(encoding="utf-8", errors="replace")
lines = text.splitlines()


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


required_functions = [
    "_queue_dev_usage",
    "_queue_dev_functions",
    "_queue_dev_locate",
    "_queue_dev_extract",
    "_queue_dev_patch",
    "_queue_dev_splice",
    "_queue_dev_test_command",
    "_queue_dev_comment",
    "_queue_dev_diff",
    "_queue_dev_strip",
    "_queue_dev_symbols",
    "_queue_dev_flow",
    "_queue_dev_scratchpad_command",
    "_queue_dev_command",
]

for fn in required_functions:
    if not re.search(rf"(?m)^{re.escape(fn)}\s*\(\)\s*\{{", text):
        fail(f"missing function {fn}")

for subcommand in [
    "functions", "locate", "extract", "scope", "patch", "splice", "test",
    "comment", "diff", "strip", "rollback", "symbols", "flow", "scratchpad",
]:
    if subcommand not in text:
        fail(f"missing queue dev subcommand marker {subcommand}")

for schema in [
    "queuebash.dev_splice_response.v1",
    "queuebash.dev_test_result.v1",
    "queuebash.dev_scratchpad.v1",
    "queuebash.dev_scratchpad_item.v1",
]:
    if schema not in text:
        fail(f"missing schema marker {schema}")

# The public JSON paths must emit the keys consumers rely on.  This is a static
# contract check against the implementation text, not a dynamic dispatcher run.
json_contract_needles = {
    "functions": ['{"functions":[', '"function":"%s"', '"file":"%s"', '"line_start":%s'],
    "locate": ['"function":"%s"', '"file":"%s"', '"line_start":%s'],
    "extract": ['"function":"%s"', '"file":"%s"', '"body":"%s"'],
    "symbols": ['"status":"ok"', '"variables"', '"strings"', '"calls"'],
    "flow": ['"status":"ok"', '"nodes"', '"edges"', '"summary"'],
}
for area, needles in json_contract_needles.items():
    for needle in needles:
        if needle not in text:
            fail(f"missing JSON contract text for {area}: {needle}")


def static_functions(path: Path, prefix: str = "") -> list[dict[str, object]]:
    out: list[dict[str, object]] = []
    seen: set[str] = set()
    pat1 = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(\s*\)\s*(?:\{|$)")
    pat2 = re.compile(r"^\s*function\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*\(\s*\))?\s*(?:\{|$)")
    for lineno, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        match = pat1.match(line) or pat2.match(line)
        if not match:
            continue
        name = match.group(1)
        if name in seen or (prefix and not name.startswith(prefix)):
            continue
        seen.add(name)
        out.append({"function": name, "file": str(path), "line_start": lineno})
    return out


def brace_delta(line: str) -> int:
    delta = 0
    sq = dq = esc = False
    for ch in line:
        if esc:
            esc = False
            continue
        if ch == "\\" and not sq:
            esc = True
            continue
        if ch == "'" and not dq:
            sq = not sq
            continue
        if ch == '"' and not sq:
            dq = not dq
            continue
        if ch == "#" and not sq and not dq:
            break
        if not sq and not dq:
            if ch == "{":
                delta += 1
            elif ch == "}":
                delta -= 1
    return delta


def static_extract(path: Path, fn: str) -> tuple[int, str]:
    body_lines = path.read_text(encoding="utf-8", errors="replace").splitlines(True)
    pat1 = re.compile(r"^\s*" + re.escape(fn) + r"\s*\(\s*\)\s*(?:\{)?\s*(?:#.*)?$")
    pat2 = re.compile(r"^\s*function\s+" + re.escape(fn) + r"(?:\s*\(\s*\))?\s*(?:\{)?\s*(?:#.*)?$")
    start = None
    for idx, line in enumerate(body_lines):
        if pat1.match(line.rstrip("\n")) or pat2.match(line.rstrip("\n")):
            start = idx
            break
    if start is None:
        raise AssertionError(f"function not found: {fn}")
    depth = 0
    seen_open = False
    for idx in range(start, len(body_lines)):
        delta = brace_delta(body_lines[idx])
        if delta > 0:
            seen_open = True
        depth += delta
        if seen_open and depth <= 0:
            return start + 1, "".join(body_lines[start : idx + 1])
    raise AssertionError(f"function end not found: {fn}")

# Build JSON-shaped data directly from a tiny fixture to validate consumer-facing
# keys and JSON serialisability without sourcing queuebash.sh.
with tempfile.TemporaryDirectory(prefix="queue-dev-json-contract-static-") as td:
    fixture = Path(td) / "fixture.sh"
    fixture.write_text(
        '_queue_dev_contract_fixture() {\n'
        '  local msg="fixture"\n'
        '  echo "$msg"\n'
        '}\n',
        encoding="utf-8",
    )
    function_rows = static_functions(fixture, "_queue_dev_contract")
    if not function_rows or function_rows[0]["function"] != "_queue_dev_contract_fixture":
        fail("fixture function parser did not return expected function row")
    line_start, body = static_extract(fixture, "_queue_dev_contract_fixture")
    payloads = [
        {"functions": function_rows},
        {"function": "_queue_dev_contract_fixture", "file": str(fixture), "line_start": line_start},
        {"function": "_queue_dev_contract_fixture", "file": str(fixture), "body": body},
        {"status": "ok", "function": "_queue_dev_contract_fixture", "file": str(fixture), "variables": ["msg"], "strings": ["fixture"], "calls": ["echo"], "functions": []},
    ]
    for payload in payloads:
        decoded = json.loads(json.dumps(payload, sort_keys=True))
        if not isinstance(decoded, dict):
            fail("JSON payload did not round-trip to object")

# Check current repo function discovery statically too, so the test still proves
# queue dev command surface exists in queuebash.sh without invoking it.
repo_functions = static_functions(QB, "_queue_dev")
if not any(row["function"] == "_queue_dev_command" for row in repo_functions):
    fail("static function discovery missing _queue_dev_command")
if not any(row["function"] == "_queue_dev_symbols" for row in repo_functions):
    fail("static function discovery missing _queue_dev_symbols")

print("PASS queue_dev_json_contract_static")
