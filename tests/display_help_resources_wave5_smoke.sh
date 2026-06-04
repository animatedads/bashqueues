#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/queuebash-wave5-smoke.XXXXXX")"
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

out="$(queue dev test qbtest --help)"
grep -Fq 'queue dev test qbtest --file FILE' <<<"$out"
grep -Fq 'EXAMPLE_QBTEST:BEGIN' <<<"$out"
out="$(queue dev test qbtest extract --help)"
grep -Fq 'queue dev test qbtest extract --file FILE --function NAME' <<<"$out"
out="$(queue dev test qbtest add --help)"
grep -Fq 'queue dev test qbtest add --file FILE --function NAME' <<<"$out"
out="$(queue dev validate --help)"
grep -Fq 'queue dev validate [--json]' <<<"$out"
out="$(queue dev scope-check --help)"
grep -Fq 'queue dev scope-check [--json]' <<<"$out"
