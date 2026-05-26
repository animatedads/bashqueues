#!/usr/bin/env bash
# bashqueues asset plugin: docker / podman container checks

queue_asset_facilities() {
    cat <<'FACILITIES'
docker:container_count	Check at most N containers with a given name pattern are running
docker:healthy	Check a container's health check is in healthy state
docker:image_age	Check a local image is not older than N days
docker:image_exists	Check a named image:tag exists locally
docker:network_exists	Check a named network exists
docker:no_privileged	Check no currently running container uses --privileged
docker:not_running	Check a named container is not running
docker:registry_reachable	Check a registry host responds without requiring auth
docker:running	Check a named container is running
docker:volume_exists	Check a named volume exists
FACILITIES
}

queue_asset_hints() {
    cat <<'HINTS'
docker:running	target=container name or ID prefix	params=tool=docker|podman timeout=5	example=queue_class_shared_asset docker running "myapp-api"	notes=Blocks unless the named container is in running state. Falls back to podman if docker absent.
docker:not_running	target=container name or ID prefix	params=tool=docker|podman timeout=5	example=queue_class_shared_asset docker not_running "migration-worker"	notes=Anti-prerequisite. Passes when no container with that name is running or exists.
docker:healthy	target=container name	params=tool=docker|podman accept_starting=0 timeout=5	example=queue_class_shared_asset docker healthy "myapp-api"	notes=Blocks unless container health check reports healthy. Containers with no HEALTHCHECK also block.
docker:image_exists	target=image:tag	params=tool=docker|podman timeout=10	example=queue_class_shared_asset docker image_exists "python:3.12-slim"	notes=Blocks unless the image and tag exist in the local image store.
docker:image_age	target=image:tag	params=max_days=30 tool=docker|podman timeout=10	example=queue_class_shared_asset docker image_age "python:3.12-slim" max_days=14	notes=Blocks if the local image is older than max_days. Forces a pull step rather than silent staleness.
docker:volume_exists	target=volume name	params=tool=docker|podman timeout=5	example=queue_class_shared_asset docker volume_exists "pgdata"	notes=Blocks unless the named Docker/Podman volume exists.
docker:network_exists	target=network name	params=tool=docker|podman timeout=5	example=queue_class_shared_asset docker network_exists "backend"	notes=Blocks unless the named network exists.
docker:container_count	target=name pattern	params=max=1 tool=docker|podman timeout=5	example=queue_class_shared_asset docker container_count "worker" max=3	notes=Blocks when more than max containers matching the name pattern are running.
docker:registry_reachable	target=registry host	params=port=443 timeout=5	example=queue_class_shared_asset docker registry_reachable "registry.example.com"	notes=Blocks if the registry HTTPS endpoint is unreachable. Does not require authentication.
docker:no_privileged	target=system	params=tool=docker|podman timeout=5	example=queue_class_shared_asset docker no_privileged system	notes=Security gate. Blocks if any currently running container uses --privileged.
HINTS
}

queue_asset_param() {
    local key="$1"; shift || true
    local p
    for p in "$@"; do
        case "$p" in "$key="*) printf '%s\n' "${p#*=}"; return 0 ;; esac
    done
    return 1
}

_docker_tool() {
    local want
    want="$(queue_asset_param tool "$@" || true)"
    if [[ -n "$want" ]]; then
        command -v "$want" >/dev/null 2>&1 || { printf 'asset_check_blocked: docker tool_missing=%s\n' "$want"; return 1; }
        printf '%s\n' "$want"; return 0
    fi
    command -v docker >/dev/null 2>&1 && { printf 'docker\n'; return 0; }
    command -v podman >/dev/null 2>&1 && { printf 'podman\n'; return 0; }
    printf 'asset_check_blocked: docker tool_missing=docker|podman\n'; return 1
}

_docker_timeout() { queue_asset_param timeout "$@" || echo 5; }

queue_asset_check_docker_running() {
    local token="$1" name="$2"; shift 2 || true
    local tool out to
    tool="$(_docker_tool "$@")" || { echo "$tool"; return 1; }
    to="$(_docker_timeout "$@")"
    out="$(timeout "$to" "$tool" inspect --format='{{.State.Running}}' "$name" 2>/dev/null || true)"
    [[ "$out" == "true" ]] && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: docker:running container_not_running name=$name"; return 1
}

queue_asset_check_docker_not_running() {
    local token="$1" name="$2"; shift 2 || true
    local tool out to rc
    tool="$(_docker_tool "$@")" || { echo "$tool"; return 1; }
    to="$(_docker_timeout "$@")"
    out="$(timeout "$to" "$tool" inspect --format='{{.State.Running}}' "$name" 2>/dev/null)"; rc=$?
    if [[ $rc -ne 0 || "$out" != "true" ]]; then echo "asset_check_ok: $token"; return 0; fi
    echo "asset_check_blocked: docker:not_running container_is_running name=$name"; return 1
}

queue_asset_check_docker_healthy() {
    local token="$1" name="$2"; shift 2 || true
    local tool status to accept
    tool="$(_docker_tool "$@")" || { echo "$tool"; return 1; }
    to="$(_docker_timeout "$@")"; accept="$(queue_asset_param accept_starting "$@" || echo 0)"
    status="$(timeout "$to" "$tool" inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$name" 2>/dev/null || true)"
    [[ "$status" == "healthy" ]] && { echo "asset_check_ok: $token"; return 0; }
    [[ "$status" == "starting" && "$accept" == "1" ]] && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: docker:healthy status=${status:-none} name=$name"; return 1
}

queue_asset_check_docker_image_exists() {
    local token="$1" image="$2"; shift 2 || true
    local tool to
    tool="$(_docker_tool "$@")" || { echo "$tool"; return 1; }
    to="$(queue_asset_param timeout "$@" || echo 10)"
    if timeout "$to" "$tool" image inspect "$image" --format='{{.Id}}' >/dev/null 2>&1; then echo "asset_check_ok: $token"; return 0; fi
    echo "asset_check_blocked: docker:image_exists missing image=$image"; return 1
}

queue_asset_check_docker_image_age() {
    local token="$1" image="$2"; shift 2 || true
    local tool to max created epoch now age_days
    tool="$(_docker_tool "$@")" || { echo "$tool"; return 1; }
    to="$(queue_asset_param timeout "$@" || echo 10)"; max="$(queue_asset_param max_days "$@" || echo 30)"
    [[ "$max" =~ ^[0-9]+$ ]] || { echo "asset_check_blocked: docker:image_age invalid max_days=$max"; return 1; }
    created="$(timeout "$to" "$tool" image inspect "$image" --format='{{.Created}}' 2>/dev/null || true)"
    [[ -n "$created" ]] || { echo "asset_check_blocked: docker:image_age image_missing_or_unreadable image=$image"; return 1; }
    epoch="$(date -d "$created" +%s 2>/dev/null || true)"
    [[ -n "$epoch" ]] || { echo "asset_check_blocked: docker:image_age cannot_parse_created image=$image"; return 1; }
    now="$(date +%s)"; age_days=$(( (now - epoch) / 86400 ))
    (( age_days <= max )) && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: docker:image_age image=$image age_days=$age_days max_days=$max"; return 1
}

queue_asset_check_docker_volume_exists() {
    local token="$1" vol="$2"; shift 2 || true
    local tool to
    tool="$(_docker_tool "$@")" || { echo "$tool"; return 1; }
    to="$(_docker_timeout "$@")"
    if timeout "$to" "$tool" volume inspect "$vol" >/dev/null 2>&1; then echo "asset_check_ok: $token"; return 0; fi
    echo "asset_check_blocked: docker:volume_exists missing volume=$vol"; return 1
}

queue_asset_check_docker_network_exists() {
    local token="$1" net="$2"; shift 2 || true
    local tool to
    tool="$(_docker_tool "$@")" || { echo "$tool"; return 1; }
    to="$(_docker_timeout "$@")"
    if timeout "$to" "$tool" network inspect "$net" >/dev/null 2>&1; then echo "asset_check_ok: $token"; return 0; fi
    echo "asset_check_blocked: docker:network_exists missing network=$net"; return 1
}

queue_asset_check_docker_container_count() {
    local token="$1" pat="$2"; shift 2 || true
    local tool to max count
    tool="$(_docker_tool "$@")" || { echo "$tool"; return 1; }
    to="$(_docker_timeout "$@")"; max="$(queue_asset_param max "$@" || echo 1)"
    [[ "$max" =~ ^[0-9]+$ ]] || { echo "asset_check_blocked: docker:container_count invalid max=$max"; return 1; }
    count="$(timeout "$to" "$tool" ps --filter "name=$pat" --format='{{.Names}}' 2>/dev/null | awk 'NF{n++} END{print n+0}')"
    (( count <= max )) && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: docker:container_count pattern=$pat count=$count max=$max"; return 1
}

queue_asset_check_docker_registry_reachable() {
    local token="$1" host="$2"; shift 2 || true
    local port to code
    port="$(queue_asset_param port "$@" || echo 443)"; to="$(_docker_timeout "$@")"
    [[ -n "$host" && "$port" =~ ^[0-9]+$ ]] || { echo "asset_check_blocked: docker:registry_reachable requires host and numeric port"; return 1; }
    if command -v curl >/dev/null 2>&1; then
        code="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout "$to" --max-time "$to" "https://$host:$port/v2/" 2>/dev/null || echo 000)"
        [[ "$code" == "200" || "$code" == "401" ]] && { echo "asset_check_ok: $token"; return 0; }
    else
        timeout "$to" bash -c ">/dev/tcp/$host/$port" 2>/dev/null && { echo "asset_check_ok: $token"; return 0; }
    fi
    echo "asset_check_blocked: docker:registry_reachable unreachable host=$host port=$port"; return 1
}

queue_asset_check_docker_no_privileged() {
    local token="$1" _target="$2"; shift 2 || true
    local tool to ids line bad=""
    tool="$(_docker_tool "$@")" || { echo "$tool"; return 1; }
    to="$(_docker_timeout "$@")"
    ids="$(timeout "$to" "$tool" ps -q 2>/dev/null || true)"
    [[ -z "$ids" ]] && { echo "asset_check_ok: $token"; return 0; }
    while IFS= read -r line; do
        [[ "$line" == *" true" ]] && { bad="$line"; break; }
    done < <(printf '%s\n' "$ids" | xargs -r "$tool" inspect --format='{{.Name}} {{.HostConfig.Privileged}}' 2>/dev/null)
    [[ -z "$bad" ]] && { echo "asset_check_ok: $token"; return 0; }
    echo "asset_check_blocked: docker:no_privileged privileged_container=${bad%% *}"; return 1
}
