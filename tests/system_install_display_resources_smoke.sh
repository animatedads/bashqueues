#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
share="$(mktemp -d)/share/bashqueues"
trap 'rm -rf "$QUEUEBASH_ROOT" "$(dirname "$(dirname "$share")")"' EXIT
mkdir -p "$share"
cp queuebash.sh "$share/queuebash.sh"
cp -a resources.d "$share/resources.d"

# shellcheck source=/dev/null
source "$share/queuebash.sh" >/dev/null 2>&1

help_out="$(queue help)"
printf '%s\n' "$help_out" | grep -q 'Usage:' || { echo 'installed-share queue help did not find display help resource' >&2; exit 1; }
printf '%s\n' "$help_out" | grep -q 'queue submit' || { echo 'installed-share queue help resource content looked incomplete' >&2; exit 1; }

targets="$(_queue_code_signature_targets "$share")"
printf '%s\n' "$targets" | grep -q '/resources.d/display/lang_eng/queue-help.txt' || {
  echo 'display help resources are not included in code signature target set' >&2
  printf '%s\n' "$targets" >&2
  exit 1
}
printf '%s\n' "$targets" | grep -q '/resources.d/xml/lang_eng/job-card.example.xml' || {
  echo 'xml display resources are not included in code signature target set' >&2
  printf '%s\n' "$targets" >&2
  exit 1
}
printf '%s\n' "$targets" | grep -q '/resources.d/display/manifest.example.tsv' || {
  echo 'display resource manifest is not included in code signature target set' >&2
  printf '%s\n' "$targets" >&2
  exit 1
}
printf '%s\n' "$targets" | grep -q '/resources.d/xml/manifest.example.tsv' || {
  echo 'xml resource manifest is not included in code signature target set' >&2
  printf '%s\n' "$targets" >&2
  exit 1
}

echo '[PASS] installed-share queue help resolves resources and signature target discovery includes display resources'
