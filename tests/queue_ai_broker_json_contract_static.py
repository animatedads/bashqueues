#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]

registry = json.loads((root / "policies.d/ai-broker/provider-registry.example.json").read_text())
assert registry["schema"] == "queuebash.ai.provider_registry.v1"
assert isinstance(registry.get("providers"), list) and registry["providers"]

required_model_fields = {
    "name", "aliases", "capabilities", "context_tokens", "supports_json",
    "supports_schema_json", "supports_tools", "supports_streaming",
    "cost_input_per_million", "cost_output_per_million", "health_state", "priority",
}
health_states = {
    "available", "degraded", "rate_limited", "auth_failed", "model_missing",
    "timeout", "disabled_by_policy", "disabled_by_cost", "cooldown",
}
seen = set()
for provider in registry["providers"]:
    assert provider.get("provider"), provider
    assert provider.get("location_type") in {"local", "cloud", "private"}, provider
    models = provider.get("models")
    assert isinstance(models, list) and models, provider
    for model in models:
        missing = required_model_fields - model.keys()
        assert not missing, (provider.get("provider"), model.get("name"), sorted(missing))
        assert model["health_state"] in health_states, model
        assert isinstance(model["capabilities"], list) and model["capabilities"], model
        seen.update(model["capabilities"])

for cap in ("chat", "json", "local", "high_quality"):
    assert cap in seen, cap

request = json.loads((root / "tests/fixtures/ai_broker/broker_request.example.json").read_text())
assert request["schema"] == "queuebash.ai.broker.request.v1"
assert request["operation"] == "chat"
assert "profile" in request
assert "capabilities" in request and "chat" in request["capabilities"]
assert request["constraints"]["max_cost_gbp"] >= 0

response = json.loads((root / "tests/fixtures/ai_broker/broker_response.example.json").read_text())
assert response["schema"] == "queuebash.ai.broker.response.v1"
assert response["ok"] is True
assert response["provider"]
assert response["fallback"]["used"] is True
assert "estimated_cost_gbp" in response["usage"]

print("PASS queue_ai_broker_json_contract_static")
