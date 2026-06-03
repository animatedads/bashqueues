#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
examples = {
    "schemas/display_resource/display_resource.example.json": "queuebash.display_resource.v1",
    "schemas/display_resource/xml_resource.example.json": "queuebash.xml_resource.v1",
}
for rel, schema in examples.items():
    data = json.loads((root / rel).read_text())
    assert data["schema"] == schema, (rel, data.get("schema"))
    assert data["execution"] == "never", rel
    assert data["json_contract_source"] is False, rel
    assert data["secret_rendering_allowed"] is False, rel
    assert "QID" in data["tokens"], rel

xml_meta = json.loads((root / "schemas/display_resource/xml_resource.example.json").read_text())
assert xml_meta["allow_dtd"] is False
assert xml_meta["allow_external_entities"] is False
print("PASS display_xml_resource_json_contract_static")
