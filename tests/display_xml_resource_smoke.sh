#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'INNER_PY'
from pathlib import Path
import re
import xml.etree.ElementTree as ET

root = Path.cwd()
xml_files = [
    root / "resources.d/xml/lang_eng/job-card.example.xml",
    root / "resources.d/xml/fallback/job-card.example.xml",
]
for path in xml_files:
    text = path.read_text()
    if "<!DOCTYPE" in text.upper() or "<!ENTITY" in text.upper():
        raise SystemExit(f"DTD/entity declaration forbidden: {path}")
    if re.search(r"\$\{|\$\(|`", text):
        raise SystemExit(f"shell-style expansion forbidden: {path}")
    ET.fromstring(text)

resource_text = (root / "resources.d/display/lang_eng/status-panel.example.txt").read_text()
if re.search(r"\$\{|\$\(|`", resource_text):
    raise SystemExit("shell-style expansion forbidden in display example")
if "SECRET" in resource_text.upper() or "PASSWORD" in resource_text.upper():
    raise SystemExit("secret-looking token forbidden in display example")
print("PASS display_xml_resource_smoke")
INNER_PY
