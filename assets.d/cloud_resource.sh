#!/usr/bin/env bash
# bashqueues asset plugin: cloud_resource
# Reads normalized cloud resource provider JSON. Does not claim resources or call cloud APIs.

queue_asset_facilities() {
    cat <<'FACILITIES'
cloud_resource:available	Blocks dispatch unless a matching unclaimed cloud resource is present in the registry
cloud_resource:platform_parity	Documents/blocks on known platform parity gaps from the local parity matrix
FACILITIES
}

queue_asset_hints() {
    cat <<'EOF_HINTS'
cloud_resource:available	target=provider or _	params=type=TYPE region=REGION compliance=LABEL class=CLASS min_cpu=N min_mem_gb=N registry=/path provider_script=/path	example=queue_class_shared_asset cloud_resource available oci type=vm region=uk-london compliance=gdpr min_cpu=4 min_mem_gb=16	notes=Read-only preflight. It checks provider-neutral file registry availability and does not claim or provision.
cloud_resource:platform_parity	target=provider or all	params=require=first_class|governance|finops|itar matrix_file=/path	example=queue_class_shared_asset cloud_resource platform_parity aws require=first_class	notes=Blocks when the platform parity matrix says required coverage is missing.
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

_queue_asset_cloud_resource_script() {
    local s
    s="$(queue_asset_param provider_script "$@" || true)"
    if [[ -n "$s" ]]; then printf '%s\n' "$s"; return 0; fi
    if [[ -n "${QUEUEBASH_CLOUD_RESOURCE_PROVIDER_SCRIPT:-}" ]]; then printf '%s\n' "$QUEUEBASH_CLOUD_RESOURCE_PROVIDER_SCRIPT"; return 0; fi
    if [[ -n "${QUEUEBASH_PLUGIN_SOURCE_DIR:-}" && -x "$QUEUEBASH_PLUGIN_SOURCE_DIR/../providers.d/cloud_resource/cloud_resource_provider.sh" ]]; then
        printf '%s\n' "$QUEUEBASH_PLUGIN_SOURCE_DIR/../providers.d/cloud_resource/cloud_resource_provider.sh"; return 0
    fi
    if [[ -x "./providers.d/cloud_resource/cloud_resource_provider.sh" ]]; then
        printf '%s\n' "./providers.d/cloud_resource/cloud_resource_provider.sh"; return 0
    fi
    printf '%s\n' "providers.d/cloud_resource/cloud_resource_provider.sh"
}

queue_asset_check_cloud_resource_available() {
    local token="$1" provider="$2"; shift 2 || true
    local script registry type region compliance class_name min_cpu min_mem_gb args out rc
    script="$(_queue_asset_cloud_resource_script "$@")"
    registry="$(queue_asset_param registry "$@" || true)"
    type="$(queue_asset_param type "$@" || queue_asset_param resource_type "$@" || true)"
    region="$(queue_asset_param region "$@" || true)"
    compliance="$(queue_asset_param compliance "$@" || true)"
    class_name="$(queue_asset_param class "$@" || true)"
    min_cpu="$(queue_asset_param min_cpu "$@" || echo 0)"
    min_mem_gb="$(queue_asset_param min_mem_gb "$@" || echo 0)"

    [[ -x "$script" ]] || { echo "asset_check_blocked: cloud_resource:available provider_script_missing=$script"; return 1; }
    args=(check-matching --json --min-cpu "$min_cpu" --min-mem-gb "$min_mem_gb")
    [[ -n "$registry" ]] && args+=(--registry "$registry")
    [[ -n "$provider" && "$provider" != "_" ]] && args+=(--provider "$provider")
    [[ -n "$type" ]] && args+=(--resource-type "$type")
    [[ -n "$region" ]] && args+=(--region "$region")
    [[ -n "$compliance" ]] && args+=(--compliance "$compliance")
    [[ -n "$class_name" ]] && args+=(--class "$class_name")

    set +e
    out="$($script "${args[@]}" 2>/dev/null)"
    rc=$?
    set -e
    if [[ $rc -eq 0 && "$out" == *'"decision": "allow"'* || $rc -eq 0 && "$out" == *'"decision":"allow"'* ]]; then
        echo "asset_check_ok: $token"
        return 0
    fi
    echo "asset_check_blocked: cloud_resource:available no_matching_resource provider=${provider:-_} type=${type:-_} region=${region:-_} compliance=${compliance:-_}"
    return 1
}

queue_asset_check_cloud_resource_platform_parity() {
    local token="$1" provider="$2"; shift 2 || true
    local require matrix_file status
    require="$(queue_asset_param require "$@" || echo first_class)"
    matrix_file="$(queue_asset_param matrix_file "$@" || true)"
    matrix_file="${matrix_file:-${QUEUEBASH_CLOUD_PLATFORM_PARITY_FILE:-policies.d/cloud-resource/platform-parity.json}}"
    [[ -r "$matrix_file" ]] || { echo "asset_check_blocked: cloud_resource:platform_parity matrix_missing=$matrix_file"; return 1; }
    status="$(python3 - "$matrix_file" "$provider" "$require" <<'PY' 2>/dev/null
import json, sys
m=json.load(open(sys.argv[1], encoding='utf-8'))
provider=sys.argv[2]
require=sys.argv[3]
items=m.get('platforms', {})
if provider == 'all':
    bad=[p for p,d in items.items() if not d.get(require, False)]
    print('ok' if not bad else 'missing:' + ','.join(bad))
else:
    d=items.get(provider, {})
    print('ok' if d.get(require, False) else 'missing:' + provider)
PY
)"
    if [[ "$status" == ok ]]; then
        echo "asset_check_ok: $token provider=$provider require=$require"
        return 0
    fi
    echo "asset_check_blocked: cloud_resource:platform_parity $status require=$require"
    return 1
}
