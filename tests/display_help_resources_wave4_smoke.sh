#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/queuebash-wave4-smoke.XXXXXX")"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
mkdir -p "$QUEUEBASH_ROOT/empty-source"/{classes,assets.d,caps.d,reporters.d,policies.d,envs.d}
export QUEUEBASH_CLASS_SOURCE_DIR="$QUEUEBASH_ROOT/empty-source/classes"
export QUEUEBASH_PLUGIN_SOURCE_DIR="$QUEUEBASH_ROOT/empty-source/assets.d"
export QUEUEBASH_CAP_PLUGIN_SOURCE_DIR="$QUEUEBASH_ROOT/empty-source/caps.d"
export QUEUEBASH_REPORTER_PLUGIN_SOURCE_DIR="$QUEUEBASH_ROOT/empty-source/reporters.d"
export QUEUEBASH_POLICY_SOURCE_DIR="$QUEUEBASH_ROOT/empty-source/policies.d"
export QUEUEBASH_ENV_SOURCE_DIR="$QUEUEBASH_ROOT/empty-source/envs.d"
unset QUEUEBASH_AI_LIVE_ENABLED || true

# shellcheck disable=SC1091
source ./queuebash.sh >/dev/null

out="$(queue ask --help)"
grep -Fq 'queue ask [--provider NAME]' <<<"$out"
grep -Fq 'Local Ollama:' <<<"$out"
out="$(queue dev splice --help)"
grep -Fq 'queue dev splice --file FILE --after TEXT --insert TEXT' <<<"$out"
out="$(queue dev scratchpad help)"
grep -Fq 'queue dev scratchpad add --kind KIND' <<<"$out"
out="$(queue dev test --help)"
grep -Fq 'DEV_TEST_RUNNER' <<<"$out"
