#!/usr/bin/env bash
# bashqueues asset plugin: ibm_finops
# IBM Cloud FinOps cache gates for regulated/sovereign workloads.
#
# Contract-only in 0.18.12: this asset reads local cache/health files written by
# an external collector or future queue job. It never calls IBM Cloud APIs from
# the worker preflight path and never requires live credentials for static tests.

queue_asset_facilities() {
    cat <<'FACILITIES'
ibm_finops:cost_cache_fresh	Blocks dispatch unless the local IBM FinOps cache is present and fresh enough
ibm_finops:budget_remaining	Blocks dispatch unless the local IBM FinOps cache reports enough budget remaining
ibm_finops:spend_below	Blocks dispatch unless cached IBM spend for a scope/period is below a threshold
ibm_finops:anomaly_free	Blocks dispatch when the local IBM FinOps health stream reports unacceptable anomalies
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
ibm_finops:cost_cache_fresh	target=scope-or-_	params=cache_file=/etc/queuebash/finops/ibm_cost_cache.json max_age_seconds=86400 allow_user_cache=0	example=queue_class_shared_asset ibm_finops cost_cache_fresh account cache_file=/etc/queuebash/finops/ibm_cost_cache.json	notes=Reads local cache metadata only. No IBM API calls in worker preflight.
ibm_finops:budget_remaining	target=budget-name	params=min_remaining=100 cache_file=/etc/queuebash/finops/ibm_cost_cache.json	example=queue_class_shared_asset ibm_finops budget_remaining finreg min_remaining=100	notes=Reads .budgets.<name>.remaining or KEY=value cache lines.
ibm_finops:spend_below	target=scope	params=max_spend=1000 period=month cache_file=/etc/queuebash/finops/ibm_cost_cache.json	example=queue_class_shared_asset ibm_finops spend_below account max_spend=5000 period=month	notes=Reads cached spend for a scope/period; collector is out of scope for 0.18.12.
ibm_finops:anomaly_free	target=scope-or-_	params=health_file=/etc/queuebash/finops/ibm_finops.health block_on=error|warn missing=block	example=queue_class_shared_asset ibm_finops anomaly_free account block_on=error	notes=Health file may be plain ok/warn/error or KEY=value with severity=.
EOF_HINTS
}

queue_asset_param() {
    local key="$1" p
    shift || true
    for p in "$@"; do
        case "$p" in
            "$key="*) printf '%s\n' "${p#*=}"; return 0 ;;
        esac
    done
    return 1
}

_queue_asset_ibm_finops_number() {
    [[ "${1:-}" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

_queue_asset_ibm_finops_ge() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a+0 >= b+0) }'; }
_queue_asset_ibm_finops_le() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a+0 <= b+0) }'; }

_queue_asset_ibm_finops_cache_default() {
    if [[ -n "${QUEUEBASH_IBM_FINOPS_CACHE:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_IBM_FINOPS_CACHE"
    elif [[ -n "${QUEUEBASH_ROOT:-}" && -f "$QUEUEBASH_ROOT/policies.d/finops/ibm_cost_cache.json" ]]; then
        printf '%s\n' "$QUEUEBASH_ROOT/policies.d/finops/ibm_cost_cache.json"
    elif [[ -f /etc/queuebash/finops/ibm_cost_cache.json ]]; then
        printf '%s\n' /etc/queuebash/finops/ibm_cost_cache.json
    else
        printf '%s\n' /etc/queuebash/finops/ibm_cost_cache.json
    fi
}

_queue_asset_ibm_finops_health_default() {
    if [[ -n "${QUEUEBASH_IBM_FINOPS_HEALTH:-}" ]]; then
        printf '%s\n' "$QUEUEBASH_IBM_FINOPS_HEALTH"
    elif [[ -n "${QUEUEBASH_ROOT:-}" && -f "$QUEUEBASH_ROOT/policies.d/finops/ibm_finops.health" ]]; then
        printf '%s\n' "$QUEUEBASH_ROOT/policies.d/finops/ibm_finops.health"
    elif [[ -f /etc/queuebash/finops/ibm_finops.health ]]; then
        printf '%s\n' /etc/queuebash/finops/ibm_finops.health
    else
        printf '%s\n' /etc/queuebash/finops/ibm_finops.health
    fi
}

_queue_asset_ibm_finops_under_user_root() {
    local path="$1" root="${QUEUEBASH_ROOT:-}"
    [[ -n "$root" ]] || return 1
    case "$path" in "$root"|"$root"/*) return 0 ;; *) return 1 ;; esac
}

_queue_asset_ibm_finops_file_allowed() {
    local file="$1" allow_user="${2:-0}" label="${3:-cache}"
    [[ -n "$file" ]] || { echo "asset_check_blocked: ibm_finops ${label}_required"; return 1; }
    [[ -r "$file" ]] || { echo "asset_check_blocked: ibm_finops ${label}_unreadable file=$file"; return 1; }
    if _queue_asset_ibm_finops_under_user_root "$file" && [[ "$allow_user" != "1" && "${allow_user,,}" != "true" && "${allow_user,,}" != "yes" ]]; then
        echo "asset_check_blocked: ibm_finops ${label}_under_queue_root_requires_allow_user_cache file=$file"
        return 1
    fi
    return 0
}

_queue_asset_ibm_finops_json_or_kv() {
    # _queue_asset_ibm_finops_json_or_kv FILE KEY
    # JSON path support is intentionally tiny: top-level dot paths and one map key.
    local file="$1" key="$2"
    python3 - "$file" "$key" <<'PY' 2>/dev/null || awk -F= -v key="$key" '$1==key {print $2; found=1; exit} END{if(!found) exit 1}' "$file" 2>/dev/null
import json, sys
path, key = sys.argv[1], sys.argv[2]
with open(path, encoding='utf-8', errors='replace') as f:
    text = f.read().strip()
if not text:
    raise SystemExit(1)
try:
    data = json.loads(text)
except Exception:
    raise SystemExit(2)
cur = data
for part in key.split('.'):
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        raise SystemExit(1)
if isinstance(cur, (dict, list)):
    print(json.dumps(cur, sort_keys=True))
else:
    print(cur)
PY
}

_queue_asset_ibm_finops_file_age_seconds() {
    local file="$1" now mtime
    now="$(date +%s 2>/dev/null || true)"
    mtime="$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || true)"
    [[ "$now" =~ ^[0-9]+$ && "$mtime" =~ ^[0-9]+$ ]] || return 1
    echo $((now - mtime))
}

queue_asset_check_ibm_finops_cost_cache_fresh() {
    local token="$1" scope="$2"; shift 2 || true
    local cache_file allow_user max_age age ts_now ts_epoch
    cache_file="$(queue_asset_param cache_file "$@" || true)"
    cache_file="${cache_file:-$(_queue_asset_ibm_finops_cache_default)}"
    allow_user="$(queue_asset_param allow_user_cache "$@" || echo 0)"
    max_age="$(queue_asset_param max_age_seconds "$@" || echo "${QUEUEBASH_IBM_FINOPS_MAX_AGE_SECONDS:-86400}")"
    _queue_asset_ibm_finops_number "$max_age" || { echo "asset_check_blocked: ibm_finops:cost_cache_fresh invalid_max_age_seconds=$max_age"; return 1; }
    _queue_asset_ibm_finops_file_allowed "$cache_file" "$allow_user" cache || return 1

    ts_epoch="$(_queue_asset_ibm_finops_json_or_kv "$cache_file" generated_at_epoch || true)"
    if [[ "$ts_epoch" =~ ^[0-9]+$ ]]; then
        ts_now="$(date +%s 2>/dev/null || echo 0)"
        age=$((ts_now - ts_epoch))
    else
        age="$(_queue_asset_ibm_finops_file_age_seconds "$cache_file" || echo 999999999)"
    fi

    if _queue_asset_ibm_finops_le "$age" "$max_age"; then
        echo "asset_check_ok: $token scope=${scope:-_} cache=$cache_file age_seconds=$age"
        return 0
    fi
    echo "asset_check_blocked: ibm_finops:cost_cache_fresh scope=${scope:-_} age_seconds=$age max_age_seconds=$max_age cache=$cache_file"
    return 1
}

queue_asset_check_ibm_finops_budget_remaining() {
    local token="$1" budget="$2"; shift 2 || true
    local cache_file allow_user min_remaining remaining key
    [[ -n "$budget" && "$budget" != "_" ]] || { echo "asset_check_blocked: ibm_finops:budget_remaining budget_required"; return 1; }
    cache_file="$(queue_asset_param cache_file "$@" || true)"
    cache_file="${cache_file:-$(_queue_asset_ibm_finops_cache_default)}"
    allow_user="$(queue_asset_param allow_user_cache "$@" || echo 0)"
    min_remaining="$(queue_asset_param min_remaining "$@" || echo 0)"
    _queue_asset_ibm_finops_number "$min_remaining" || { echo "asset_check_blocked: ibm_finops:budget_remaining invalid_min_remaining=$min_remaining"; return 1; }
    _queue_asset_ibm_finops_file_allowed "$cache_file" "$allow_user" cache || return 1
    key="budgets.$budget.remaining"
    remaining="$(_queue_asset_ibm_finops_json_or_kv "$cache_file" "$key" || _queue_asset_ibm_finops_json_or_kv "$cache_file" "budget_${budget}_remaining" || true)"
    _queue_asset_ibm_finops_number "$remaining" || { echo "asset_check_blocked: ibm_finops:budget_remaining missing_or_invalid_remaining budget=$budget cache=$cache_file"; return 1; }
    if _queue_asset_ibm_finops_ge "$remaining" "$min_remaining"; then
        echo "asset_check_ok: $token budget=$budget remaining=$remaining min_remaining=$min_remaining"
        return 0
    fi
    echo "asset_check_blocked: ibm_finops:budget_remaining budget=$budget remaining=$remaining min_remaining=$min_remaining"
    return 1
}

queue_asset_check_ibm_finops_spend_below() {
    local token="$1" scope="$2"; shift 2 || true
    local cache_file allow_user max_spend period spend key
    scope="${scope:-account}"
    period="$(queue_asset_param period "$@" || echo month)"
    max_spend="$(queue_asset_param max_spend "$@" || true)"
    [[ -n "$max_spend" ]] || max_spend="${1:-}"
    _queue_asset_ibm_finops_number "$max_spend" || { echo "asset_check_blocked: ibm_finops:spend_below invalid_max_spend=$max_spend"; return 1; }
    cache_file="$(queue_asset_param cache_file "$@" || true)"
    cache_file="${cache_file:-$(_queue_asset_ibm_finops_cache_default)}"
    allow_user="$(queue_asset_param allow_user_cache "$@" || echo 0)"
    _queue_asset_ibm_finops_file_allowed "$cache_file" "$allow_user" cache || return 1
    key="spend.$scope.$period"
    spend="$(_queue_asset_ibm_finops_json_or_kv "$cache_file" "$key" || _queue_asset_ibm_finops_json_or_kv "$cache_file" "spend_${scope}_${period}" || true)"
    _queue_asset_ibm_finops_number "$spend" || { echo "asset_check_blocked: ibm_finops:spend_below missing_or_invalid_spend scope=$scope period=$period cache=$cache_file"; return 1; }
    if _queue_asset_ibm_finops_le "$spend" "$max_spend"; then
        echo "asset_check_ok: $token scope=$scope period=$period spend=$spend max_spend=$max_spend"
        return 0
    fi
    echo "asset_check_blocked: ibm_finops:spend_below scope=$scope period=$period spend=$spend max_spend=$max_spend"
    return 1
}

queue_asset_check_ibm_finops_anomaly_free() {
    local token="$1" scope="$2"; shift 2 || true
    local health_file allow_user block_on missing severity
    health_file="$(queue_asset_param health_file "$@" || true)"
    health_file="${health_file:-$(_queue_asset_ibm_finops_health_default)}"
    allow_user="$(queue_asset_param allow_user_cache "$@" || echo 0)"
    block_on="$(queue_asset_param block_on "$@" || echo error)"
    missing="$(queue_asset_param missing "$@" || echo block)"
    if [[ ! -r "$health_file" ]]; then
        if [[ "${missing,,}" == "ok" ]]; then
            echo "asset_check_ok: $token scope=${scope:-_} health_missing_allowed file=$health_file"
            return 0
        fi
        echo "asset_check_blocked: ibm_finops:anomaly_free health_unreadable file=$health_file"
        return 1
    fi
    _queue_asset_ibm_finops_file_allowed "$health_file" "$allow_user" health || return 1
    severity="$(_queue_asset_ibm_finops_json_or_kv "$health_file" severity || awk -F= '/^severity=/ {print $2; found=1; exit} NF==1 {print $1; found=1; exit} END{if(!found) exit 1}' "$health_file" 2>/dev/null || echo unknown)"
    severity="${severity,,}"
    case "$severity:$block_on" in
        ok:*|none:*) echo "asset_check_ok: $token scope=${scope:-_} severity=$severity"; return 0 ;;
        warn:warn|warn:warning|warn:any|warning:warn|warning:any) echo "asset_check_blocked: ibm_finops:anomaly_free scope=${scope:-_} severity=$severity block_on=$block_on"; return 1 ;;
        error:*|critical:*|fail:*|failed:*) echo "asset_check_blocked: ibm_finops:anomaly_free scope=${scope:-_} severity=$severity block_on=$block_on"; return 1 ;;
        *) echo "asset_check_ok: $token scope=${scope:-_} severity=$severity block_on=$block_on"; return 0 ;;
    esac
}
