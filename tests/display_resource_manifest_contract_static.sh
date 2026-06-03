#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "display resource manifest contract static: $*" >&2; exit 1; }

for file in \
  docs/QUEUE_DISPLAY_RESOURCES.md \
  docs/QUEUE_XML_RESOURCES.md \
  resources.d/display/manifest.example.tsv \
  resources.d/xml/manifest.example.tsv \
  schemas/display_resource/resource_manifest.example.json \
  schemas/display_resource/resource_catalog.example.json; do
  test -f "$file" || fail "missing $file"
done

grep -q 'Display resource manifest/catalog contract' docs/QUEUE_DISPLAY_RESOURCES.md || fail "display doc lacks manifest contract"
grep -q 'XML manifest/catalog rules' docs/QUEUE_XML_RESOURCES.md || fail "XML doc lacks manifest rules"
grep -q $'display\tstatus-panel.example.txt\tlang_eng' resources.d/display/manifest.example.tsv || fail "display manifest lacks status panel lang_eng entry"
grep -q $'display\tstatus-panel.example.txt\tfallback' resources.d/display/manifest.example.tsv || fail "display manifest lacks status panel fallback entry"
grep -q $'xml\tjob-card.example.xml\tlang_eng' resources.d/xml/manifest.example.tsv || fail "XML manifest lacks job-card lang_eng entry"
grep -q $'xml\tjob-card.example.xml\tfallback' resources.d/xml/manifest.example.tsv || fail "XML manifest lacks job-card fallback entry"

for file in resources.d/display/manifest.example.tsv resources.d/xml/manifest.example.tsv; do
  grep -q $'\tfalse\tfalse\t' "$file" || fail "$file lacks false/false JSON+secret boundary"
  if grep -Eq '\$\(|`|\$\{|<!ENTITY|<!DOCTYPE|secret_value|provider_credentials|PASSWORD=|TOKEN=' "$file"; then
    fail "$file contains forbidden executable/secret-looking content"
  fi
done

grep -q 'queuebash.display_resource_manifest.v1' schemas/display_resource/resource_manifest.example.json || fail "missing manifest schema marker"
grep -q 'queuebash.display_resource_catalog.v1' schemas/display_resource/resource_catalog.example.json || fail "missing catalog schema marker"
grep -q '"secret_rendering_allowed": false' schemas/display_resource/resource_catalog.example.json || fail "catalog allows secret rendering"
grep -q '"json_contract_source": false' schemas/display_resource/resource_catalog.example.json || fail "catalog is marked as JSON contract source"
