#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
provider = (root / "providers.d/cloud_broker/cloud_broker_provider.sh").read_text(encoding="utf-8")
queue = (root / "queuebash.sh").read_text(encoding="utf-8")

def require(text: str, needle: str) -> None:
    if needle not in text:
        raise SystemExit(f"missing {needle!r}")

require(provider, "queuebash.cloud_broker.job_intent.v1")
require(provider, "broker_explain")
require(provider, "live_api_calls")
require(provider, "dispatch_binding")
require(provider, "cloud_resource_claim")
require(provider, "cloud_provision_call")
require(provider, "cloud_infra_call")
require(queue, "queue cloud broker job-intent")
print("cloud broker job intent json contract: ok")
