#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

bash -n queuebash.sh

grep -Eq 'QUEUEBASH_VERSION="0\.18\.[0-9]+"' queuebash.sh
grep -q '_queue_inject_global_json_arg' queuebash.sh
grep -q 'queuebash.submit_result.v1' queuebash.sh
grep -q 'Bob28 global JSON passthrough hardening' README.md
grep -q 'Bob28 global JSON passthrough hardening' CHANGELOG.md
