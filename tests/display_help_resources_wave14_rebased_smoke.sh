#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
# shellcheck disable=SC1091
source ./queuebash.sh
queue code help | grep -q 'Code signing commands'
queue code sign --help | grep -q 'Sign queuebash code-signature targets'
queue code verify --help | grep -q 'Verify code signatures'
queue code audit --help | grep -q 'Audit code-signature coverage'
queue code trust --help | grep -q 'Trust a public key'
