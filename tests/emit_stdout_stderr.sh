#!/usr/bin/env bash
set -euo pipefail
echo "STDOUT: hello from stdout"
echo "STDERR: hello from stderr" >&2
echo "STDOUT: args: $*"
echo "STDERR: pwd: $PWD" >&2
exit 0
