#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
# shellcheck disable=SC1091
source ./queuebash.sh

overdir --help | grep -Fq 'overdir [--dryrun]'
overfiles --help | grep -Fq 'overfiles [--dryrun]'
queue status --help | grep -Fq 'queue status <qid-or-exact-job-name>'
queue tail --help | grep -Fq 'queue tail <qid-or-exact-job-name>'
