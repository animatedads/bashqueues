#!/usr/bin/env bash
# bashqueues asset plugin: grid_energy
# Grid FinOps / energy-aware scheduling gates driven by local market/carbon cache.
# No live grid API calls and no OT/ICS writes happen in worker preflight.

queue_asset_facilities() {
    cat <<'FACILITIES'
grid_energy:price_below	Blocks dispatch when local grid-energy cache price_per_kwh is above threshold
grid_energy:carbon_below	Blocks dispatch when local carbon_gco2_kwh is above threshold
grid_energy:negative_price	Allows dispatch only when local price_per_kwh is below zero
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
grid_energy:price_below	target=max price per kWh	params=cache_file=/path market=NAME zone=ZONE max_age_seconds=900 provider_script=/path	example=queue_class_shared_asset grid_energy price_below 0.15 cache_file=/var/cache/bashqueues/grid-energy/uk_eso_gb.json zone=GB	notes=Reads a local normalized grid energy cache. It does not call live grid APIs in worker preflight.
grid_energy:carbon_below	target=max gCO2/kWh	params=cache_file=/path market=NAME zone=ZONE max_age_seconds=900 provider_script=/path	example=queue_class_shared_asset grid_energy carbon_below 120 cache_file=/var/cache/bashqueues/grid-energy/entsoe_de_lu.json zone=DE_LU	notes=Blocks if cache is stale/missing or carbon intensity exceeds threshold.
grid_energy:negative_price	target=zone or _	params=cache_file=/path market=NAME max_age_seconds=900 provider_script=/path	example=queue_class_shared_asset grid_energy negative_price _ cache_file=/var/cache/bashqueues/grid-energy/nordpool_se3.json	notes=Used for batch jobs that should run only during zero/negative price events.
EOF_HINTS
}

queue_asset_param() {
    local key="$1" p
    shift || true
    for p in "$@"; do
        case "$p" in "$key="*) printf '%s\n' "${p#*=}"; return 0 ;; esac
    done
    return 1
}

_queue_asset_grid_energy_provider_script() {
    local s
    s="$(queue_asset_param provider_script "$@" || true)"
    if [[ -n "$s" ]]; then printf '%s\n' "$s"; return 0; fi
    if [[ -n "${QUEUEBASH_GRID_ENERGY_PROVIDER_SCRIPT:-}" ]]; then printf '%s\n' "$QUEUEBASH_GRID_ENERGY_PROVIDER_SCRIPT"; return 0; fi
    if [[ -n "${QUEUEBASH_PLUGIN_SOURCE_DIR:-}" && -x "$QUEUEBASH_PLUGIN_SOURCE_DIR/../providers.d/grid_energy/grid_energy_provider.sh" ]]; then
        printf '%s\n' "$QUEUEBASH_PLUGIN_SOURCE_DIR/../providers.d/grid_energy/grid_energy_provider.sh"; return 0
    fi
    if [[ -x "./providers.d/grid_energy/grid_energy_provider.sh" ]]; then
        printf '%s\n' "./providers.d/grid_energy/grid_energy_provider.sh"; return 0
    fi
    printf '%s\n' "providers.d/grid_energy/grid_energy_provider.sh"
}

_queue_asset_grid_energy_safe_token() {
    printf '%s' "${1:-unknown}" | sed 's#[^A-Za-z0-9_.-]#_#g'
}

_queue_asset_grid_energy_cache_file() {
    local target="$1"; shift || true
    local cache_file market zone
    cache_file="$(queue_asset_param cache_file "$@" || true)"
    if [[ -n "$cache_file" ]]; then printf '%s\n' "$cache_file"; return 0; fi
    market="$(queue_asset_param market "$@" || echo custom)"
    zone="$(queue_asset_param zone "$@" || echo "$target")"
    printf '/var/cache/bashqueues/grid-energy/%s_%s.json\n' "$(_queue_asset_grid_energy_safe_token "$market")" "$(_queue_asset_grid_energy_safe_token "$zone")"
}

_queue_asset_grid_energy_run() {
    local token="$1" facility="$2" target="$3"; shift 3 || true
    local script cache_file market zone max_age out rc args=()
    script="$(_queue_asset_grid_energy_provider_script "$@")"
    [[ -x "$script" ]] || { echo "asset_check_blocked: grid_energy:$facility provider_script_missing=$script"; return 1; }
    cache_file="$(_queue_asset_grid_energy_cache_file "$target" "$@")"
    market="$(queue_asset_param market "$@" || true)"
    zone="$(queue_asset_param zone "$@" || true)"
    max_age="$(queue_asset_param max_age_seconds "$@" || echo 900)"
    args=(evaluate --cache "$cache_file" --max-age-seconds "$max_age" --json)
    [[ -n "$market" ]] && args+=(--market "$market")
    [[ -n "$zone" ]] && args+=(--zone "$zone")
    case "$facility" in
        price_below) args+=(--max-price-per-kwh "$target") ;;
        carbon_below) args+=(--max-carbon-gco2-kwh "$target") ;;
        negative_price) args+=(--require-negative-price) ;;
    esac
    set +e
    out="$($script "${args[@]}" 2>/dev/null)"
    rc=$?
    set -e
    if [[ $rc -eq 0 && ( "$out" == *'"decision": "allow"'* || "$out" == *'"decision":"allow"'* ) ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: grid_energy:$facility decision=deny cache=$cache_file"
    return 1
}

queue_asset_check_grid_energy_price_below() {
    local token="$1" max_price="$2"; shift 2 || true
    _queue_asset_grid_energy_run "$token" price_below "$max_price" "$@"
}

queue_asset_check_grid_energy_carbon_below() {
    local token="$1" max_carbon="$2"; shift 2 || true
    _queue_asset_grid_energy_run "$token" carbon_below "$max_carbon" "$@"
}

queue_asset_check_grid_energy_negative_price() {
    local token="$1" zone_or_scope="${2:-_}"; shift 2 || true
    _queue_asset_grid_energy_run "$token" negative_price "$zone_or_scope" "$@"
}
