#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
# Use the repository dev root for this display-only smoke so the test does not
# spend most of its budget bootstrapping bundled assets/policies into a fresh root.
export QUEUEBASH_ROOT="${QUEUEBASH_ROOT:-$PWD/.queuebash}"

source queuebash.sh >/dev/null 2>&1

check_resource() {
  local name="$1" expected="$2" out
  out="$(_queue_resource_fetch_i18nl_command --name "$name" --lang lang_eng)"
  printf '%s\n' "$out" | grep -q "$expected"
}

# Keep this smoke bounded: static coverage verifies every wave2 resource and
# dispatch hook; this runtime smoke verifies the i18n display fetch/render path.
check_resource key-provider-help.txt 'queue key-provider lookup'
check_resource cloud-help.txt 'queue cloud - unified cloud broker front'
