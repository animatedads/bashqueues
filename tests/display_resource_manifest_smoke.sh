#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 tests/display_resource_manifest_json_contract_static.py >/tmp/display_resource_manifest_json.out
grep -q 'PASS display_resource_manifest_json_contract_static' /tmp/display_resource_manifest_json.out

# The manifest is metadata-only: every referenced example resource should exist,
# and fallback-required English examples should have a fallback peer.
awk -F '\t' 'NF && $1 !~ /^#/ {print $1 "\t" $2 "\t" $3 "\t" $4}' resources.d/display/manifest.example.tsv resources.d/xml/manifest.example.tsv | while IFS=$'\t' read -r rtype name lang fallback_required; do
  case "$rtype" in
    display) path="resources.d/display/$lang/$name" ;;
    xml) path="resources.d/xml/$lang/$name" ;;
    *) echo "unknown resource type in manifest: $rtype" >&2; exit 1 ;;
  esac
  test -f "$path" || { echo "manifest references missing resource: $path" >&2; exit 1; }
  if [[ "$fallback_required" == "yes" && "$lang" != "fallback" ]]; then
    case "$rtype" in
      display) fb="resources.d/display/fallback/$name" ;;
      xml) fb="resources.d/xml/fallback/$name" ;;
    esac
    test -f "$fb" || { echo "manifest fallback missing: $fb" >&2; exit 1; }
  fi
done

echo "PASS display_resource_manifest_smoke"
