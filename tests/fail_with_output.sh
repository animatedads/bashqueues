#!/usr/bin/env bash
set -euo pipefail
echo "STDOUT: about to fail"
echo "STDERR: failing intentionally" >&2
exit 23
