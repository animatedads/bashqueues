#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="${QUEUEBASH_ROOT:-$PWD/.queuebash}"
source queuebash.sh >/dev/null 2>&1

check_resource() {
  local name="$1" expected="$2" out
  out="$(_queue_resource_fetch_i18nl_command --name "$name" --lang lang_eng)"
  printf '%s\n' "$out" | grep -Fq "$expected"
}

check_resource clean-logs-help.txt 'queue clean-logs [options]'
check_resource health-help.txt 'queue health [--fix] [--deep]'
check_resource queue-dev-help.txt 'queue dev patchset create --output ZIP'
check_resource profile-interrogate-help.txt 'queue profile interrogate run NAME'
