#!/usr/bin/env bash
# bashqueues asset plugin: Kubernetes checks via kubectl

queue_asset_facilities() {
    cat <<'FACILITIES'
k8s:configmap_exists	Check a named ConfigMap exists
k8s:deployment_ready	Check a deployment has the expected number of ready replicas
k8s:job_complete	Check a named Kubernetes Job is in Completed state
k8s:namespace_exists	Check a namespace exists
k8s:no_crashlooping	Check no pods matching a selector are in CrashLoopBackOff
k8s:node_ready	Check at least N nodes are in Ready state
k8s:pod_not_running	Check no pods matching a label selector are running
k8s:pod_running	Check at least N pods matching a label selector are running
k8s:pvc_bound	Check a PersistentVolumeClaim is in Bound state
k8s:reachable	Check the API server is reachable and responds
k8s:resource_quota_ok	Check namespace resource quota is below a threshold pct
k8s:secret_exists	Check a named Secret exists without reading values
FACILITIES
}

queue_asset_hints() {
    cat <<'HINTS'
k8s:reachable	target=system or context name	params=context= timeout=5	example=queue_class_shared_asset k8s reachable system	notes=Blocks unless the Kubernetes API server responds to /healthz.
k8s:deployment_ready	target=deployment name	params=namespace=default context= min_ready=1 timeout=10	example=queue_class_shared_asset k8s deployment_ready "api-server" namespace=production min_ready=2	notes=Blocks unless the deployment has at least min_ready ready replicas.
k8s:pod_running	target=label selector	params=namespace=default context= min_count=1 timeout=10	example=queue_class_shared_asset k8s pod_running "app=myapp" namespace=production min_count=1	notes=Blocks unless at least min_count matching pods are Running.
k8s:pod_not_running	target=label selector	params=namespace=default context= timeout=10	example=queue_class_shared_asset k8s pod_not_running "app=db-migration" namespace=production	notes=Anti-prerequisite. Blocks if matching pods are Running.
k8s:job_complete	target=job name	params=namespace=default context= timeout=10	example=queue_class_shared_asset k8s job_complete "db-migration" namespace=production	notes=Blocks unless the named Kubernetes Job has Complete=True.
k8s:node_ready	target=system	params=context= min_count=1 timeout=10	example=queue_class_shared_asset k8s node_ready system min_count=3	notes=Blocks unless at least min_count nodes report Ready=True.
k8s:pvc_bound	target=PVC name	params=namespace=default context= timeout=10	example=queue_class_shared_asset k8s pvc_bound "pgdata" namespace=production	notes=Blocks unless the PersistentVolumeClaim phase is Bound.
k8s:configmap_exists	target=ConfigMap name	params=namespace=default context= timeout=5	example=queue_class_shared_asset k8s configmap_exists "app-config" namespace=production	notes=Blocks unless the ConfigMap exists.
k8s:secret_exists	target=Secret name	params=namespace=default context= timeout=5	example=queue_class_shared_asset k8s secret_exists "app-token" namespace=production	notes=Only checks the Secret object exists; it never prints values.
k8s:namespace_exists	target=namespace name	params=context= timeout=5	example=queue_class_shared_asset k8s namespace_exists "production"	notes=Blocks unless the namespace exists.
k8s:resource_quota_ok	target=quota name	params=namespace=default context= max_pct=80 resource=cpu|memory|pods timeout=10	example=queue_class_shared_asset k8s resource_quota_ok "compute-quota" namespace=production resource=cpu max_pct=85	notes=Blocks when used quota percentage is at or above max_pct.
k8s:no_crashlooping	target=label selector	params=namespace=default context= timeout=10	example=queue_class_shared_asset k8s no_crashlooping "app=payment-service" namespace=production	notes=Blocks if any matching pod has a container waiting in CrashLoopBackOff.
HINTS
}

queue_asset_param() { local key="$1"; shift || true; local p; for p in "$@"; do case "$p" in "$key="*) printf '%s\n' "${p#*=}"; return 0;; esac; done; return 1; }
_k8s_need() { command -v kubectl >/dev/null 2>&1 || { echo 'asset_check_blocked: k8s tool_missing=kubectl'; return 1; }; }
_k8s_timeout() { queue_asset_param timeout "$@" || echo 10; }
_k8s_base_opts() { :; }

queue_asset_check_k8s_reachable() {
    local token="$1" target="$2"; shift 2 || true; _k8s_need || return 1
    local ctx to opts=(); ctx="$(queue_asset_param context "$@" || true)"; [[ -z "$ctx" && "$target" != system ]] && ctx="$target"; to="$(queue_asset_param timeout "$@" || echo 5)"
    [[ -n "$ctx" ]] && opts+=(--context="$ctx")
    if timeout "$to" kubectl "${opts[@]}" get --raw=/healthz >/dev/null 2>&1; then echo "asset_check_ok: $token"; return 0; fi
    echo "asset_check_blocked: k8s:reachable context=${ctx:-current}"; return 1
}
queue_asset_check_k8s_deployment_ready() {
    local token="$1" name="$2"; shift 2 || true; _k8s_need || return 1
    local ctx ns min to ready opts=(); ctx="$(queue_asset_param context "$@" || true)"; ns="$(queue_asset_param namespace "$@" || echo default)"; min="$(queue_asset_param min_ready "$@" || echo 1)"; to="$(_k8s_timeout "$@")"
    [[ -n "$ctx" ]] && opts+=(--context="$ctx"); opts+=(--namespace="$ns")
    ready="$(timeout "$to" kubectl "${opts[@]}" get deployment "$name" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"; ready="${ready:-0}"
    [[ "$ready" =~ ^[0-9]+$ && "$ready" -ge "$min" ]] && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: k8s:deployment_ready name=$name namespace=$ns ready=$ready min_ready=$min"; return 1
}
queue_asset_check_k8s_pod_running() {
    local token="$1" sel="$2"; shift 2 || true; _k8s_need || return 1
    local ctx ns min to count opts=(); ctx="$(queue_asset_param context "$@" || true)"; ns="$(queue_asset_param namespace "$@" || echo default)"; min="$(queue_asset_param min_count "$@" || echo 1)"; to="$(_k8s_timeout "$@")"
    [[ -n "$ctx" ]] && opts+=(--context="$ctx"); opts+=(--namespace="$ns")
    count="$(timeout "$to" kubectl "${opts[@]}" get pods -l "$sel" --field-selector=status.phase=Running -o name 2>/dev/null | awk 'NF{n++} END{print n+0}')"
    (( count >= min )) && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: k8s:pod_running selector=$sel namespace=$ns count=$count min_count=$min"; return 1
}
queue_asset_check_k8s_pod_not_running() {
    local token="$1" sel="$2"; shift 2 || true; _k8s_need || return 1
    local ctx ns to count opts=(); ctx="$(queue_asset_param context "$@" || true)"; ns="$(queue_asset_param namespace "$@" || echo default)"; to="$(_k8s_timeout "$@")"
    [[ -n "$ctx" ]] && opts+=(--context="$ctx"); opts+=(--namespace="$ns")
    count="$(timeout "$to" kubectl "${opts[@]}" get pods -l "$sel" --field-selector=status.phase=Running -o name 2>/dev/null | awk 'NF{n++} END{print n+0}')"
    (( count == 0 )) && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: k8s:pod_not_running selector=$sel namespace=$ns count=$count"; return 1
}
queue_asset_check_k8s_job_complete() {
    local token="$1" name="$2"; shift 2 || true; _k8s_need || return 1
    local ctx ns to st opts=(); ctx="$(queue_asset_param context "$@" || true)"; ns="$(queue_asset_param namespace "$@" || echo default)"; to="$(_k8s_timeout "$@")"
    [[ -n "$ctx" ]] && opts+=(--context="$ctx"); opts+=(--namespace="$ns")
    st="$(timeout "$to" kubectl "${opts[@]}" get job "$name" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || true)"
    [[ "$st" == True ]] && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: k8s:job_complete name=$name namespace=$ns status=${st:-unknown}"; return 1
}
queue_asset_check_k8s_node_ready() {
    local token="$1" _target="$2"; shift 2 || true; _k8s_need || return 1
    local ctx min to count opts=(); ctx="$(queue_asset_param context "$@" || true)"; min="$(queue_asset_param min_count "$@" || echo 1)"; to="$(_k8s_timeout "$@")"
    [[ -n "$ctx" ]] && opts+=(--context="$ctx")
    count="$(timeout "$to" kubectl "${opts[@]}" get nodes -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c '^True$' || true)"
    (( count >= min )) && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: k8s:node_ready count=$count min_count=$min"; return 1
}
queue_asset_check_k8s_pvc_bound() {
    local token="$1" name="$2"; shift 2 || true; _k8s_need || return 1
    local ctx ns to phase opts=(); ctx="$(queue_asset_param context "$@" || true)"; ns="$(queue_asset_param namespace "$@" || echo default)"; to="$(_k8s_timeout "$@")"
    [[ -n "$ctx" ]] && opts+=(--context="$ctx"); opts+=(--namespace="$ns")
    phase="$(timeout "$to" kubectl "${opts[@]}" get pvc "$name" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    [[ "$phase" == Bound ]] && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: k8s:pvc_bound name=$name namespace=$ns phase=${phase:-unknown}"; return 1
}
queue_asset_check_k8s_configmap_exists() { local token="$1" name="$2"; shift 2 || true; _k8s_need || return 1; local ctx ns to opts=(); ctx="$(queue_asset_param context "$@" || true)"; ns="$(queue_asset_param namespace "$@" || echo default)"; to="$(queue_asset_param timeout "$@" || echo 5)"; [[ -n "$ctx" ]] && opts+=(--context="$ctx"); opts+=(--namespace="$ns"); if timeout "$to" kubectl "${opts[@]}" get configmap "$name" -o name >/dev/null 2>&1; then echo "asset_check_ok: $token"; return 0; fi; echo "asset_check_blocked: k8s:configmap_exists name=$name namespace=$ns"; return 1; }
queue_asset_check_k8s_secret_exists() { local token="$1" name="$2"; shift 2 || true; _k8s_need || return 1; local ctx ns to opts=(); ctx="$(queue_asset_param context "$@" || true)"; ns="$(queue_asset_param namespace "$@" || echo default)"; to="$(queue_asset_param timeout "$@" || echo 5)"; [[ -n "$ctx" ]] && opts+=(--context="$ctx"); opts+=(--namespace="$ns"); if timeout "$to" kubectl "${opts[@]}" get secret "$name" -o name >/dev/null 2>&1; then echo "asset_check_ok: $token"; return 0; fi; echo "asset_check_blocked: k8s:secret_exists name=$name namespace=$ns"; return 1; }
queue_asset_check_k8s_namespace_exists() { local token="$1" ns="$2"; shift 2 || true; _k8s_need || return 1; local ctx to opts=(); ctx="$(queue_asset_param context "$@" || true)"; to="$(queue_asset_param timeout "$@" || echo 5)"; [[ -n "$ctx" ]] && opts+=(--context="$ctx"); if timeout "$to" kubectl "${opts[@]}" get namespace "$ns" -o name >/dev/null 2>&1; then echo "asset_check_ok: $token"; return 0; fi; echo "asset_check_blocked: k8s:namespace_exists namespace=$ns"; return 1; }
queue_asset_check_k8s_resource_quota_ok() {
    local token="$1" name="$2"; shift 2 || true; _k8s_need || return 1
    local ctx ns to max res json pct opts=(); ctx="$(queue_asset_param context "$@" || true)"; ns="$(queue_asset_param namespace "$@" || echo default)"; to="$(_k8s_timeout "$@")"; max="$(queue_asset_param max_pct "$@" || echo 80)"; res="$(queue_asset_param resource "$@" || echo pods)"
    [[ -n "$ctx" ]] && opts+=(--context="$ctx"); opts+=(--namespace="$ns")
    json="$(timeout "$to" kubectl "${opts[@]}" get resourcequota "$name" -o json 2>/dev/null || true)"; [[ -n "$json" ]] || { echo "asset_check_blocked: k8s:resource_quota_ok quota_missing name=$name namespace=$ns"; return 1; }
    pct="$(printf '%s' "$json" | python3 -c 'import json,sys,re; res=sys.argv[1]; d=json.load(sys.stdin); used=d.get("status",{}).get("used",{}).get(res,"0"); hard=d.get("status",{}).get("hard",{}).get(res,"0"); q=lambda v: float(re.match(r"([0-9.]+)",str(v)).group(1)) if re.match(r"([0-9.]+)",str(v)) else 0.0; h=q(hard); print(int((q(used)/h)*100) if h else 100)' "$res" 2>/dev/null || true)"
    [[ "$pct" =~ ^[0-9]+$ ]] || pct=100
    (( pct < max )) && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: k8s:resource_quota_ok name=$name namespace=$ns resource=$res pct=$pct max_pct=$max"; return 1
}
queue_asset_check_k8s_no_crashlooping() {
    local token="$1" sel="$2"; shift 2 || true; _k8s_need || return 1
    local ctx ns to out opts=(); ctx="$(queue_asset_param context "$@" || true)"; ns="$(queue_asset_param namespace "$@" || echo default)"; to="$(_k8s_timeout "$@")"
    [[ -n "$ctx" ]] && opts+=(--context="$ctx"); opts+=(--namespace="$ns")
    out="$(timeout "$to" kubectl "${opts[@]}" get pods -l "$sel" -o jsonpath='{range .items[*]}{.status.containerStatuses[*].state.waiting.reason}{"\n"}{end}' 2>/dev/null || true)"
    grep -q 'CrashLoopBackOff' <<<"$out" && { echo "asset_check_blocked: k8s:no_crashlooping selector=$sel namespace=$ns"; return 1; }
    echo "asset_check_ok: $token"
}
