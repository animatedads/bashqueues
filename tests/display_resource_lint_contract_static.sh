#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

test -x bin/queue-display-resource-lint.py
grep -q 'queuebash.display_resource_lint.v1' bin/queue-display-resource-lint.py
grep -q 'secret_rendering_allowed' bin/queue-display-resource-lint.py
grep -q 'json_contract_source' bin/queue-display-resource-lint.py
grep -q 'none-lint-only' bin/queue-display-resource-lint.py
grep -q 'DOCTYPE\|ENTITY\|xml-stylesheet' bin/queue-display-resource-lint.py

# The helper must remain a read-only linter: no eval/source/shell execution path.
if grep -Eq '(^|[^A-Za-z_])(eval|source)[[:space:]]*\(' bin/queue-display-resource-lint.py; then
  echo "display resource linter must not eval/source resource content" >&2
  exit 1
fi
if grep -Eq 'subprocess|os\.system|Popen|check_call|check_output|run\(' bin/queue-display-resource-lint.py; then
  echo "display resource linter must not shell out" >&2
  exit 1
fi

# Docs must describe that lint is evidence only, not rendering/authority.
grep -q 'not a renderer' docs/QUEUE_DISPLAY_RESOURCES.md
grep -q 'not become provider authority' docs/QUEUE_XML_RESOURCES.md

echo "PASS display_resource_lint_contract_static"
