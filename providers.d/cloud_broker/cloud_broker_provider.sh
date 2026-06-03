#!/usr/bin/env bash
# Provider-neutral cloud broker explainer.
# This composes local cloud_* provider evidence only. It performs no live cloud API calls.
set -euo pipefail

_json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

_bool_json() { [[ "${1:-0}" == 1 ]] && printf true || printf false; }

_here_dir() { cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P; }
_repo_root() { cd "$(_here_dir)/../.." && pwd -P; }

_find_helper() {
    local rel="$1" root
    root="$(_repo_root)"
    if [[ -x "$root/$rel" ]]; then printf '%s\n' "$root/$rel"; return 0; fi
    return 1
}

_run_json_or_null() {
    local out rc
    set +e
    out=$("$@" 2>/dev/null)
    rc=$?
    set -e
    if [[ -n "$out" ]]; then
        printf '%s' "$out"
    else
        printf 'null'
    fi
    return 0
}

_usage() {
    cat <<'USAGE'
Usage:
  cloud_broker_provider.sh explain --capability CAP --profile PROFILE [--provider NAME] [--region REGION] [--service SERVICE] [--estimated-hourly-usd N] [--monthly-budget-usd N] [--json]
  cloud_broker_provider.sh job-intent --job-file FILE [--json]
  cloud_broker_provider.sh self-test [--json]

This is a broker-front explainer only. It reads/wraps local cloud provider
contracts and emits normalized evidence. It performs no cloud API calls, no
provisioning, no destruction, and no queue dispatch/job lifecycle binding.
USAGE
}

_emit_json() {
    python3 - "$@" <<'PY'
import json, sys
pairs=sys.argv[1:]
out={}
for p in pairs:
    k,v=p.split('=',1)
    try:
        out[k]=json.loads(v)
    except Exception:
        out[k]=v
print(json.dumps(out, sort_keys=True, separators=(',',':')))
PY
}

_explain() {
    local capability="" profile="" provider="" region="" service="compute" est="" budget="" json=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --capability) capability="${2:-}"; shift 2 ;;
            --profile) profile="${2:-}"; shift 2 ;;
            --provider) provider="${2:-}"; shift 2 ;;
            --region) region="${2:-}"; shift 2 ;;
            --service) service="${2:-compute}"; shift 2 ;;
            --estimated-hourly-usd) est="${2:-}"; shift 2 ;;
            --monthly-budget-usd) budget="${2:-}"; shift 2 ;;
            --json|-j) json=1; shift ;;
            --help|-h) _usage; return 0 ;;
            *) echo "cloud broker explain: unknown argument: $1" >&2; return 2 ;;
        esac
    done
    [[ -n "$capability" && -n "$profile" ]] || { echo "cloud broker explain requires --capability and --profile" >&2; return 2; }

    local signals resource provision infra
    signals="$(_find_helper providers.d/cloud_signals/cloud_signals_provider.sh 2>/dev/null || true)"
    resource="$(_find_helper providers.d/cloud_resource/cloud_resource_provider.sh 2>/dev/null || true)"
    provision="$(_find_helper providers.d/cloud_provision/cloud_provision.sh 2>/dev/null || true)"
    infra="$(_find_helper providers.d/cloud_infra/cloud_infra.sh 2>/dev/null || true)"

    if [[ "$json" -eq 0 ]]; then
        echo "queue cloud broker explain"
        echo "capability: $capability"
        echo "profile:    $profile"
        [[ -n "$provider" ]] && echo "provider:   $provider"
        [[ -n "$region" ]] && echo "region:     $region"
        echo "service:    $service"
        echo "decision:   review"
        echo "note:       broker front only; use --json for machine-readable evidence"
        return 0
    fi

    local signals_json='null' resource_json='null' provision_json='null' infra_json='null'
    if [[ -n "$signals" && -n "$provider" && -n "$region" ]]; then
        if [[ -n "$est" ]]; then
            if [[ -n "$budget" ]]; then
                signals_json="$(_run_json_or_null "$signals" explain --provider "$provider" --region "$region" --service "$service" --estimated-hourly-usd "$est" --monthly-budget-usd "$budget" --json)"
            else
                signals_json="$(_run_json_or_null "$signals" explain --provider "$provider" --region "$region" --service "$service" --estimated-hourly-usd "$est" --json)"
            fi
        else
            signals_json="$(_run_json_or_null "$signals" availability-check --provider "$provider" --region "$region" --service "$service" --json)"
        fi
    fi
    if [[ -n "$resource" ]]; then
        local rargs=(explain --json)
        [[ -n "$provider" ]] && rargs+=(--provider "$provider")
        [[ -n "$region" ]] && rargs+=(--region "$region")
        resource_json="$(_run_json_or_null "$resource" "${rargs[@]}")"
    fi
    if [[ -n "$provision" ]]; then
        provision_json="$(_run_json_or_null "$provision" templates --json)"
    fi
    if [[ -n "$infra" ]]; then
        infra_json="$(_run_json_or_null "$infra" list --json)"
    fi

    python3 - "$capability" "$profile" "$provider" "$region" "$service" "$signals_json" "$resource_json" "$provision_json" "$infra_json" <<'PY'
import json, sys
capability, profile, provider, region, service = sys.argv[1:6]
raw = sys.argv[6:10]
def load(s):
    s=(s or "").strip()
    if not s or s == "null":
        return None
    # If a helper ever emits more than one line, use the first valid JSON object.
    for line in s.splitlines():
        line=line.strip()
        if not line:
            continue
        try:
            return json.loads(line)
        except Exception:
            continue
    return None

def dedupe_refs(refs):
    out=[]
    seen=set()
    for ref in refs:
        if not isinstance(ref, dict):
            continue
        key=(str(ref.get("id", "")), str(ref.get("uri", "")), str(ref.get("type", "")))
        if key in seen:
            continue
        seen.add(key)
        out.append(ref)
    return out

def collect_policy_references(*items):
    refs=[]
    def walk(x):
        if isinstance(x, dict):
            pr=x.get("policy_references")
            if isinstance(pr, list):
                refs.extend([r for r in pr if isinstance(r, dict)])
            for v in x.values():
                if isinstance(v, (dict, list)):
                    walk(v)
        elif isinstance(x, list):
            for v in x:
                if isinstance(v, (dict, list)):
                    walk(v)
    for item in items:
        walk(item)
    return dedupe_refs(refs)

components={
    "cloud_signals": load(raw[0]),
    "cloud_resource": load(raw[1]),
    "cloud_provision": load(raw[2]),
    "cloud_infra": load(raw[3])
}
policy_refs=collect_policy_references(*components.values())
obj={
  "schema":"queuebash.cloud_broker.explain.v1",
  "status":"ok",
  "decision":"review",
  "capability":capability,
  "profile":profile,
  "provider":provider,
  "region":region,
  "service":service,
  "non_mutating":True,
  "live_api_calls":False,
  "dispatch_binding":False,
  "components":components,
  "policy_references":policy_refs,
  "policy_reference_mode":"local_policy_links_only",
  "policy_reference_note":"Policy references are local regulatory/corporate evidence pointers for decision review; they are not legal advice and do not prove compliance by themselves.",
  "next_steps":[
    "review provider/region/legal/cost evidence and linked regulatory/corporate policy references",
    "check or claim cloud_resource capacity where appropriate",
    "create cloud_provision plan if capacity does not exist",
    "use cloud_infra lifecycle helpers only through gated dry-run/live policy"
  ],
  "exit_code":0
}
print(json.dumps(obj, sort_keys=True, separators=(",",":")))
PY
}


_job_value() {
    local file="$1" key="$2" line value
    line="$(grep -m1 "^${key}=" "$file" 2>/dev/null || true)"
    [[ -n "$line" ]] || return 1
    value="${line#*=}"
    value="${value%\'}"; value="${value#\'}"
    value="${value%\"}"; value="${value#\"}"
    printf '%s\n' "$value"
}

_job_intent() {
    local job_file="" json=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --job-file) job_file="${2:-}"; shift 2 ;;
            --json|-j) json=1; shift ;;
            --help|-h) _usage; return 0 ;;
            *) echo "cloud broker job-intent: unknown argument: $1" >&2; return 2 ;;
        esac
    done
    [[ -n "$job_file" ]] || { echo "cloud broker job-intent requires --job-file FILE" >&2; return 2; }
    [[ -f "$job_file" ]] || { echo "cloud broker job-intent: job file not found: $job_file" >&2; return 1; }

    local job_id job_name uses profile capability provider region service est budget policy_refs explain_json
    job_id="$(_job_value "$job_file" JOB_ID 2>/dev/null || basename "$job_file" .job)"
    job_name="$(_job_value "$job_file" JOB_NAME 2>/dev/null || true)"
    uses="$(_job_value "$job_file" USES_CLOUD 2>/dev/null || echo 0)"
    profile="$(_job_value "$job_file" CLOUD_PROFILE 2>/dev/null || true)"
    capability="$(_job_value "$job_file" CLOUD_CAPABILITY 2>/dev/null || true)"
    provider="$(_job_value "$job_file" CLOUD_PROVIDER 2>/dev/null || true)"
    region="$(_job_value "$job_file" CLOUD_REGION 2>/dev/null || true)"
    service="$(_job_value "$job_file" CLOUD_SERVICE 2>/dev/null || echo compute)"
    est="$(_job_value "$job_file" CLOUD_ESTIMATED_HOURLY_USD 2>/dev/null || true)"
    budget="$(_job_value "$job_file" CLOUD_MONTHLY_BUDGET_USD 2>/dev/null || true)"
    policy_refs="$(_job_value "$job_file" CLOUD_POLICY_REFERENCES 2>/dev/null || true)"

    if [[ "$json" -eq 0 ]]; then
        echo "queue cloud broker job-intent"
        echo "job:        $job_id"
        [[ -n "$job_name" ]] && echo "name:       $job_name"
        if [[ "$uses" != "1" ]]; then
            echo "uses-cloud: no"
            echo "decision:   not_applicable"
            return 0
        fi
        echo "uses-cloud: yes"
        echo "profile:    $profile"
        echo "capability: $capability"
        [[ -n "$provider" ]] && echo "provider:   $provider"
        [[ -n "$region" ]] && echo "region:     $region"
        echo "binding:    advisory-only"
        return 0
    fi

    if [[ "$uses" != "1" ]]; then
        python3 - "$job_id" "$job_name" <<'PYJOBNONE'
import json, sys
print(json.dumps({
  "schema":"queuebash.cloud_broker.job_intent.v1",
  "status":"ok",
  "decision":"not_applicable",
  "job":{"id":sys.argv[1],"name":sys.argv[2]},
  "uses_cloud":False,
  "broker_explain":None,
  "non_mutating":True,
  "dispatch_binding":False,
  "exit_code":0
}, sort_keys=True, separators=(",",":")))
PYJOBNONE
        return 0
    fi
    [[ -n "$profile" && -n "$capability" ]] || { echo "cloud broker job-intent: cloud job intent missing CLOUD_PROFILE or CLOUD_CAPABILITY" >&2; return 1; }

    local args=(--capability "$capability" --profile "$profile" --service "${service:-compute}" --json)
    [[ -n "$provider" ]] && args+=(--provider "$provider")
    [[ -n "$region" ]] && args+=(--region "$region")
    [[ -n "$est" ]] && args+=(--estimated-hourly-usd "$est")
    [[ -n "$budget" ]] && args+=(--monthly-budget-usd "$budget")
    explain_json="$(_explain "${args[@]}")"
    python3 - "$job_id" "$job_name" "$profile" "$capability" "$provider" "$region" "${service:-compute}" "$est" "$budget" "$policy_refs" "$explain_json" <<'PYJOBINTENT'
import json, sys
job_id, job_name, profile, capability, provider, region, service, est, budget, policy_refs, explain_raw = sys.argv[1:12]
try:
    explain=json.loads(explain_raw)
except Exception:
    explain={"schema":"queuebash.error.v1","status":"error","error":"invalid broker explain output"}
obj={
  "schema":"queuebash.cloud_broker.job_intent.v1",
  "status":"ok",
  "decision":"review",
  "job":{"id":job_id,"name":job_name},
  "uses_cloud":True,
  "intent":{
    "profile":profile,
    "capability":capability,
    "provider":provider,
    "region":region,
    "service":service,
    "estimated_hourly_usd":est,
    "monthly_budget_usd":budget,
    "policy_references_raw":policy_refs
  },
  "broker_explain":explain,
  "non_mutating":True,
  "live_api_calls":False,
  "dispatch_binding":False,
  "cloud_resource_claim":False,
  "cloud_provision_call":False,
  "cloud_infra_call":False,
  "note":"Job cloud intent is advisory broker evidence only; it is not bound to dispatch or resource claim lifecycle.",
  "exit_code":0
}
print(json.dumps(obj, sort_keys=True, separators=(",",":")))
PYJOBINTENT
}

case "${1:-help}" in
    help|--help|-h|"") _usage ;;
    explain) shift; _explain "$@" ;;
    job-intent|intent) shift; _job_intent "$@" ;;
    self-test) shift || true; _explain --capability vm --profile gdpr-compute --provider aws --region eu-west-2 --service compute --estimated-hourly-usd 0.50 --json ;;
    *) echo "cloud_broker_provider.sh: unknown command: ${1:-}" >&2; _usage >&2; exit 2 ;;
esac
