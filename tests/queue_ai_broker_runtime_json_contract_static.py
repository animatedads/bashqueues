#!/usr/bin/env python3
"""AI broker runtime JSON contract checks.

The broker contract intentionally covers several independent behaviours: provider
catalog output, profile health gates, local health-cache operations, health-event filter/report operations, and
live-call gating/fallback evidence.  Running all of those in one mutable temp
root made later assertions order-dependent and made slow sandbox subprocess
startup look like a feature hang.  The default entrypoint now runs bounded stages
in fresh subprocesses; each stage uses its own temporary health cache and event
journal.
"""
import json
import os
import pathlib
import subprocess
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
cmd = [str(root / "bin/queue-ai-broker")]
STAGES = ("catalog_profile", "health_cache", "health_event_filters", "live_paths")


def base_env(tmp: pathlib.Path) -> dict:
    env = os.environ.copy()
    env["QUEUEBASH_AI_BROKER_HEALTH_CACHE"] = str(tmp / "health-cache.json")
    env["QUEUEBASH_AI_BROKER_HEALTH_EVENTS"] = str(tmp / "health-events.jsonl")
    return env


def load(args, env, timeout=30):
    out = subprocess.check_output(cmd + args, cwd=root, text=True, env=env, timeout=timeout)
    return json.loads(out)


def write_profile(path: pathlib.Path, content: str) -> None:
    path.write_text(content.strip() + "\n", encoding="utf-8")


def stage_catalog_profile() -> None:
    with tempfile.TemporaryDirectory(prefix="queue-ai-broker-json-contract.catalog.") as td:
        tmp = pathlib.Path(td)
        env = base_env(tmp)
        providers = load(["providers", "--json"], env)
        assert providers["schema"] == "queuebash.ai_broker.providers.v1"
        assert isinstance(providers.get("providers"), list) and providers["providers"]
        models = load(["models", "--json"], env)
        assert models["schema"] == "queuebash.ai_broker.models.v1"
        assert isinstance(models.get("models"), list) and models["models"]
        health = load(["health", "--json"], env)
        assert health["schema"] == "queuebash.ai_broker.health.v1"
        explain = load(["explain", "--profile", "balanced", "--capability", "chat,json", "--json"], env)
        assert explain["schema"] == "queuebash.ai_broker.explain.v1"
        assert explain["decision"] == "allow"
        assert explain["selected"]["provider"]
        assert "policy_links" in explain
        assert explain["policy_links"]["applicable"] is True
        assert explain["policy_links"]["combined"]["regulatory"]
        assert explain["policy_links"]["combined"]["corporate"]
        assert explain["policy_links"]["combined"]["regulatory"][0]["id"] == "UK_GDPR"
        assert explain["policy_links"]["combined"]["regulatory"][0].get("uri") == "policy://regulatory/uk-gdpr"
        assert "health_summary" in explain
        assert explain["health_summary"]["selected_state"] in ("available", "healthy", "degraded")
        assert isinstance(explain["health_summary"]["candidate_by_health"], dict)
        assert "health_policy" in explain["health_summary"]
        assert isinstance(explain["health_summary"]["health_policy"].get("allowed_states"), list)

        blocked_health_env = dict(env)
        blocked_health_env["QUEUEBASH_AI_PROFILE_FILE"] = str(tmp / "blocked-health.env")
        write_profile(pathlib.Path(blocked_health_env["QUEUEBASH_AI_PROFILE_FILE"]), '''
AI_PROFILE_NAME="blocked-health"
AI_CAPABILITIES="chat json"
AI_PROVIDER_ORDER="openai_compat ollama gemini anthropic mistral deepseek groq cerebras baseten watsonx"
AI_ALLOW_CLOUD=1
AI_ALLOW_LOCAL=1
AI_FALLBACK_ENABLED=1
AI_HEALTH_REQUIRED=1
AI_ALLOWED_HEALTH_STATES="available healthy degraded"
AI_BLOCKED_HEALTH_STATES="available healthy degraded"
AI_ALLOW_DEGRADED_FALLBACK=1
AI_MAX_COST_PER_REQUEST_GBP="999"
AI_REQUIRE_JSON_MODE=0
''')
        blocked_health = load(["explain", "--profile", "blocked-health", "--capability", "chat", "--json"], blocked_health_env)
        assert blocked_health["decision"] == "deny", blocked_health
        assert any(any(str(reason).startswith("health_profile_blocked_") for reason in item.get("reasons", [])) for item in blocked_health.get("rejected", [])), blocked_health
        assert blocked_health["health_summary"]["health_policy"]["explicit_blocked"] is True

        allowed_degraded_env = base_env(tmp / "allowed-degraded")
        pathlib.Path(allowed_degraded_env["QUEUEBASH_AI_BROKER_HEALTH_CACHE"]).parent.mkdir(parents=True, exist_ok=True)
        allowed_degraded_env["QUEUEBASH_AI_PROFILE_FILE"] = str(tmp / "allowed-degraded.env")
        write_profile(pathlib.Path(allowed_degraded_env["QUEUEBASH_AI_PROFILE_FILE"]), '''
AI_PROFILE_NAME="allowed-degraded"
AI_CAPABILITIES="chat json"
AI_PROVIDER_ORDER="openai_compat ollama gemini anthropic mistral deepseek groq cerebras baseten watsonx"
AI_ALLOW_CLOUD=1
AI_ALLOW_LOCAL=1
AI_FALLBACK_ENABLED=1
AI_HEALTH_REQUIRED=1
AI_ALLOWED_HEALTH_STATES="degraded"
AI_BLOCKED_HEALTH_STATES=""
AI_ALLOW_DEGRADED_FALLBACK=1
AI_MAX_COST_PER_REQUEST_GBP="999"
AI_REQUIRE_JSON_MODE=0
''')
        load(["health", "--provider", "openai_compat", "--model", "local-model", "--set-state", "degraded", "--reason", "profile allow degraded", "--json"], allowed_degraded_env)
        allowed_degraded = load(["explain", "--profile", "allowed-degraded", "--capability", "chat", "--json"], allowed_degraded_env)
        assert allowed_degraded["decision"] == "allow", allowed_degraded
        assert allowed_degraded["selected"]["health_state"] == "degraded", allowed_degraded
        assert allowed_degraded["health_summary"]["health_policy"]["allowed_states"] == ["degraded"]

        # Profile health-gate probes deliberately mutate broker health state. The
        # balanced chat probe uses the original clean stage env so gate-specific
        # health state cannot leak into the broader advisory contract assertion.
        chat = load(["chat", "--profile", "balanced", "--message", "hello", "--json"], env)
        assert chat["schema"] == "queuebash.ai_broker.response.v1"
        assert chat["ok"] is True
        assert chat["live_call_performed"] is False
        assert chat["provider_execution"] == "broker_selection_only_no_live_call"
        assert chat["policy_links"]["applicable"] is True
        assert chat["policy_links"]["combined"]["audit"]
        assert "health_summary" in chat and chat["health_summary"]["selected_state"]


def write_event_fixture(path: pathlib.Path, events: list) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(event, sort_keys=True) + "\n" for event in events), encoding="utf-8")


def health_event(action: str, provider: str = "", model: str = "", state: str = "", created_at: str = "2026-01-01T00:00:00Z", **extra) -> dict:
    event = {
        "schema": "queuebash.ai_broker.health_event.v1",
        "action": action,
        "provider": provider,
        "model": model,
        "state": state,
        "reason": extra.pop("reason", "contract fixture"),
        "created_at": created_at,
        "recorded": True,
    }
    event.update(extra)
    return event


def stage_health_cache() -> None:
    with tempfile.TemporaryDirectory(prefix="queue-ai-broker-json-contract.health-cache.") as td:
        tmp = pathlib.Path(td)
        env = base_env(tmp)
        ollama = load(["health", "--provider", "ollama", "--model", "llama3", "--set-state", "available", "--reason", "contract fallback candidate", "--json"], env)
        assert ollama["schema"] == "queuebash.ai_broker.health_update.v1"
        update = load(["health", "--provider", "openai_compat", "--model", "local-model", "--set-state", "timeout", "--reason", "contract timeout", "--cooldown-seconds", "60", "--json"], env)
        assert update["schema"] == "queuebash.ai_broker.health_update.v1"
        assert update["ok"] is True
        assert update["updated"]["state"] == "timeout"
        explain_timeout = load(["explain", "--profile", "balanced", "--capability", "chat", "--json"], env)
        assert any(
            "health_cooldown" in r.get("reasons", [])
            or "health_timeout" in r.get("reasons", [])
            or "health_profile_not_allowed_cooldown" in r.get("reasons", [])
            or "health_profile_not_allowed_timeout" in r.get("reasons", [])
            for r in explain_timeout.get("rejected", [])
        ), explain_timeout
        assert explain_timeout["selected"]["provider"] == "ollama"
        assert explain_timeout["health_summary"]["rejected_by_reason"]
        assert explain_timeout["health_summary"]["health_rejected_count"] >= 1
        restore = load(["health", "--provider", "openai_compat", "--model", "local-model", "--set-state", "available", "--reason", "contract restore", "--json"], env)
        assert restore["schema"] == "queuebash.ai_broker.health_update.v1"
        clear_one = load(["health", "--provider", "openai_compat", "--model", "local-model", "--clear", "--json"], env)
        assert clear_one["schema"] == "queuebash.ai_broker.health_clear.v1"
        assert clear_one["ok"] is True
        assert clear_one["removed_count"] == 1, clear_one
        expired = load(["health", "--provider", "openai_compat", "--model", "local-model", "--set-state", "timeout", "--reason", "expired cooldown contract", "--cooldown-seconds", "1", "--json"], env)
        assert expired["schema"] == "queuebash.ai_broker.health_update.v1"
        cache_path = pathlib.Path(env["QUEUEBASH_AI_BROKER_HEALTH_CACHE"])
        cache_data = json.loads(cache_path.read_text())
        for item in cache_data.get("entries", []):
            if item.get("provider") == "openai_compat" and item.get("model") == "local-model":
                item["cooldown_until_epoch"] = 1
                item["cooldown_until"] = "1970-01-01T00:00:01Z"
        cache_path.write_text(json.dumps(cache_data))
        pruned = load(["health", "--prune-expired", "--json"], env)
        assert pruned["schema"] == "queuebash.ai_broker.health_prune.v1"
        assert pruned["pruned_count"] >= 1, pruned
        clear_all = load(["health", "--clear-all", "--json"], env)
        assert clear_all["schema"] == "queuebash.ai_broker.health_clear.v1"
        assert clear_all["ok"] is True


def stage_health_event_filters() -> None:
    with tempfile.TemporaryDirectory(prefix="queue-ai-broker-json-contract.health-events.") as td:
        tmp = pathlib.Path(td)
        env = base_env(tmp)
        event_path = pathlib.Path(env["QUEUEBASH_AI_BROKER_HEALTH_EVENTS"])
        write_event_fixture(event_path, [
            health_event("update", "ollama", "llama3", "available", "2026-01-01T00:00:01Z"),
            health_event("update", "openai_compat", "local-model", "timeout", "2026-01-01T00:00:02Z", cooldown_seconds=60),
            health_event("clear", "openai_compat", "local-model", "", "2026-01-01T00:00:03Z", removed_count=1),
            health_event("prune_expired", "", "", "", "2026-01-01T00:00:04Z", pruned_count=1),
            health_event("clear_all", "", "", "", "2026-01-01T00:00:05Z", removed_count=1),
            health_event("update", "openai_compat", "local-model", "available", "2026-01-01T00:00:06Z"),
        ])
        events = load(["health", "--events", "--limit", "25", "--json"], env)
        assert events["schema"] == "queuebash.ai_broker.health_events.v1"
        assert events["ok"] is True
        assert events["event_count"] >= 4, events
        assert any(e.get("schema") == "queuebash.ai_broker.health_event.v1" for e in events.get("events", [])), events
        assert any(e.get("action") == "update" for e in events.get("events", [])), events
        filtered_events = load(["health", "--events", "--provider", "openai_compat", "--action", "update", "--summary", "--limit", "25", "--json"], env)
        assert filtered_events["schema"] == "queuebash.ai_broker.health_events.v1"
        assert filtered_events["filters"]["provider"] == "openai_compat", filtered_events
        assert filtered_events["filters"]["action"] == "update", filtered_events
        assert filtered_events["summary"]["event_count"] == filtered_events["event_count"], filtered_events
        assert filtered_events["summary"]["by_action"].get("update", 0) >= 1, filtered_events
        assert all(e.get("provider") == "openai_compat" and e.get("action") == "update" for e in filtered_events.get("events", [])), filtered_events
        pruned_events = load(["health", "--prune-events", "--max-events", "5", "--json"], env)
        assert pruned_events["schema"] == "queuebash.ai_broker.health_events_prune.v1"
        assert pruned_events["ok"] is True
        assert pruned_events["after_count"] <= 5, pruned_events
        prune_marker = load(["health", "--events", "--action", "prune_events", "--summary", "--json"], env)
        assert prune_marker["schema"] == "queuebash.ai_broker.health_events.v1"
        assert prune_marker["summary"]["by_action"].get("prune_events", 0) >= 1, prune_marker

def stage_live_paths() -> None:
    with tempfile.TemporaryDirectory(prefix="queue-ai-broker-json-contract.live.") as td:
        tmp = pathlib.Path(td)
        env = base_env(tmp)
        blocked = subprocess.run(cmd + ["chat", "--profile", "balanced", "--message", "blocked", "--live", "--json"], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, env=env, timeout=30)
        assert blocked.returncode != 0
        blocked_json = json.loads(blocked.stdout)
        assert blocked_json["schema"] == "queuebash.ai_broker.error.v1"
        assert blocked_json["reason"] == "live_ai_provider_not_enabled"
        assert "health_summary" in blocked_json

        feedback_root = tmp / "feedback"
        feedback_root.mkdir(parents=True, exist_ok=True)
        failing = feedback_root / "failing-provider"
        failing.write_text('''#!/usr/bin/env bash
set -euo pipefail
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --output-json) out="$2"; shift 2 ;;
    --request-json) shift 2 ;;
    *) shift ;;
  esac
done
printf '{"schema":"queuebash.ai_advisory.response.v1","ok":false,"status":"error","reason":"fixture rate limit 429"}\n' > "$out"
exit 9
''', encoding="utf-8")
        failing.chmod(0o755)
        ok = feedback_root / "ok-provider"
        ok.write_text('''#!/usr/bin/env bash
set -euo pipefail
req=""; out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --request-json) req="$2"; shift 2 ;;
    --output-json) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
python3 - "$req" "$out" <<'PYS'
import json, sys
req=json.load(open(sys.argv[1]))
json.dump({"schema":"queuebash.ai_advisory.response.v1","ok":True,"status":"ok","answer_markdown":"ok fallback","provider":req.get("provider"),"model":req.get("model")}, open(sys.argv[2], "w"))
PYS
''', encoding="utf-8")
        ok.chmod(0o755)
        env_fb = base_env(feedback_root)
        env_fb.update({
            "QUEUEBASH_AI_LIVE_ENABLED": "1",
            "QUEUEBASH_AI_OPENAI_COMPAT_HELPER": str(failing),
            "QUEUEBASH_AI_OLLAMA_HELPER": str(ok),
            "QUEUEBASH_AI_BROKER_HEALTH_FAILURE_COOLDOWN_SECONDS": "30",
        })
        subprocess.check_call([cmd[0], "health", "--provider", "openai_compat", "--model", "local-model", "--set-state", "available", "--json"], env=env_fb, stdout=subprocess.DEVNULL, timeout=30)
        subprocess.check_call([cmd[0], "health", "--provider", "ollama", "--model", "llama3", "--set-state", "available", "--json"], env=env_fb, stdout=subprocess.DEVNULL, timeout=30)
        live_fallback_feedback = load(["chat", "--profile", "balanced", "--message", "fallback feedback", "--live", "--json"], env_fb)
        assert live_fallback_feedback["schema"] == "queuebash.ai_broker.response.v1"
        assert live_fallback_feedback["fallback"]["used"] is True, live_fallback_feedback
        assert live_fallback_feedback["selected_provider"] == "ollama", live_fallback_feedback
        assert any(x.get("schema") == "queuebash.ai_broker.health_feedback.v1" for x in live_fallback_feedback.get("health_feedback", [])), live_fallback_feedback
        assert any(x.get("updated", {}).get("state") == "rate_limited" for x in live_fallback_feedback.get("health_feedback", [])), live_fallback_feedback
        feedback_events = load(["health", "--events", "--limit", "25", "--json"], env_fb)
        assert feedback_events["schema"] == "queuebash.ai_broker.health_events.v1"
        assert any(e.get("action") == "feedback" and e.get("state") == "rate_limited" for e in feedback_events.get("events", [])), feedback_events
        feedback_filtered = load(["health", "--events", "--provider", "openai_compat", "--action", "feedback", "--state", "rate_limited", "--summary", "--json"], env_fb)
        assert feedback_filtered["event_count"] >= 1, feedback_filtered
        assert feedback_filtered["summary"]["by_state"].get("rate_limited", 0) >= 1, feedback_filtered
        assert all(e.get("provider") == "openai_compat" and e.get("action") == "feedback" and e.get("state") == "rate_limited" for e in feedback_filtered.get("events", [])), feedback_filtered


def run_stage(stage: str) -> None:
    if stage == "catalog_profile":
        stage_catalog_profile()
    elif stage == "health_cache":
        stage_health_cache()
    elif stage == "health_event_filters":
        stage_health_event_filters()
    elif stage == "health_events":
        # Backward-compatible aggregate for older external callers.  The default
        # runner uses the smaller health_cache and health_event_filters stages so
        # CI can identify which half is slow or failed.
        stage_health_cache()
        stage_health_event_filters()
    elif stage == "live_paths":
        stage_live_paths()
    else:
        raise SystemExit(f"unknown stage: {stage}")


def main() -> int:
    if len(sys.argv) == 3 and sys.argv[1] == "--stage":
        run_stage(sys.argv[2])
        print(f"PASS queue_ai_broker_runtime_json_contract_static stage={sys.argv[2]}")
        return 0
    if len(sys.argv) != 1:
        raise SystemExit("usage: queue_ai_broker_runtime_json_contract_static.py [--stage NAME]")
    for stage in STAGES:
        # Each stage allocates a fresh temporary health cache/event journal, so the
        # default runner can execute them directly without cross-stage state leak.
        # Direct execution avoids sandbox-specific waits where a completed stage
        # process can remain alive briefly while descendant helper probes unwind.
        run_stage(stage)
        print(f"PASS queue_ai_broker_runtime_json_contract_static stage={stage}")
    print("PASS queue_ai_broker_runtime_json_contract_static")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
