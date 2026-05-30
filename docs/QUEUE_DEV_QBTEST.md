# queue dev QBTEST embedded function tests

`queue dev test qbtest` runs small function-level tests embedded directly in source
comments. The tests are stored as base64 so they do not confuse shell or Python
parsers and so they can travel with the function during review.

## Command

```bash
queue dev test qbtest --file FILE [--function NAME] [--language bash|python] [--timeout SEC] [--list] [--json] [--keep]
queue dev test qbtest --help | -h | --h
```

Use `--function NAME` to filter embedded tests for a single function. A bare
positional function name after `--file` is rejected with a hint so accidental
argument drift remains visible.

The command is deliberately bounded. It does not create acceptance records and it
does not mutate scratchpad state. A failed, no-match, invalid, or timed-out block
returns non-zero. `--keep` preserves the temporary decoded test directory for
debugging only; normal runs clean it automatically.

## Comment block format

```bash
# QBTEST:BEGIN name=my-real-test function=my_function language=bash
# QBTEST:B64
# <base64 encoded real test snippet>
# QBTEST:END
```

Documentation examples in help text use escaped `EXAMPLE_QBTEST:*` markers rather
than live `QBTEST:*` markers. This prevents the scanner from executing placeholder
documentation as a real embedded test, the same defensive trick as keeping sample
Python triple-quote content out of executable parser paths.

Metadata keys are parsed from the `QBTEST:BEGIN` line:

- `name` gives the test a stable human-readable name.
- `function` links the block to the function under test.
- `language` is `bash` or `python`; when omitted it is inferred from the file extension.

## Bash behaviour

For `language=bash`, the runner sources the target file and then sources the decoded
test snippet in the same shell. The snippet can call the function directly.

Example decoded snippet:

```bash
out="$(add_one 41)"
[[ "$out" == "42" ]]
```

## Python behaviour

For `language=python`, the runner imports the target file as a temporary module and
executes the decoded snippet. The snippet receives these globals:

- `module`: the imported target module.
- `target`: the named function, or `None` when no function was named.
- `QBTEST_SOURCE_FILE`: absolute source path.
- `QBTEST_FUNCTION`: function name from metadata or the filter.

Example decoded snippet:

```python
assert target(40, 2) == 42
assert module.add(1, 2) == 3
```

## JSON contract

JSON output uses schema:

```text
queuebash.dev_qbtest_result.v1
```

Each result records the test id, source line, language, function, name, status,
exit code, duration, and bounded stdout/stderr tails.

## Safety boundaries

QBTEST is a development helper. It is not a production job runner, does not bypass
policy, does not mark work accepted, and does not replace focused integration or
provider contract tests. It is intended for function-local regression checks and
AI-assisted maintenance workflows.
