#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "display xml resource contract static: $*" >&2; exit 1; }

test -f docs/QUEUE_DISPLAY_RESOURCES.md || fail "missing display resource doc"
test -f docs/QUEUE_XML_RESOURCES.md || fail "missing XML resource doc"

grep -q 'Bob18 display/XML contract extension' docs/QUEUE_DISPLAY_RESOURCES.md || fail "display doc lacks Bob18 extension"
grep -q 'JSON output remains locale-independent' docs/QUEUE_DISPLAY_RESOURCES.md || fail "display doc lacks JSON boundary"
grep -q 'must never render secret values' docs/QUEUE_XML_RESOURCES.md || fail "XML doc lacks secrets boundary"
grep -q 'not a provider contract' docs/QUEUE_XML_RESOURCES.md || fail "XML doc lacks provider boundary"

for file in   resources.d/display/lang_eng/status-panel.example.txt   resources.d/display/fallback/status-panel.example.txt   resources.d/xml/lang_eng/job-card.example.xml   resources.d/xml/fallback/job-card.example.xml   schemas/display_resource/display_resource.example.json   schemas/display_resource/xml_resource.example.json; do
  test -f "$file" || fail "missing $file"
done

grep -q '{{QID}}' resources.d/display/lang_eng/status-panel.example.txt || fail "display example lacks QID token"
grep -q '{{JOB_NAME}}' resources.d/xml/lang_eng/job-card.example.xml || fail "XML example lacks JOB_NAME token"
grep -q 'queuebash.display.xml.job_card.v1' resources.d/xml/lang_eng/job-card.example.xml || fail "XML example lacks schema marker"

grep -q 'queuebash.display_resource.v1' schemas/display_resource/display_resource.example.json || fail "display schema example missing schema"
grep -q 'queuebash.xml_resource.v1' schemas/display_resource/xml_resource.example.json || fail "XML schema example missing schema"
grep -q '"secret_rendering_allowed": false' schemas/display_resource/display_resource.example.json || fail "display schema does not forbid secret rendering"
grep -q '"secret_rendering_allowed": false' schemas/display_resource/xml_resource.example.json || fail "XML schema does not forbid secret rendering"
