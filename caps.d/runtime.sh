#!/usr/bin/env bash
# Runtime cap plugin for bashqueues.
#
# This cap does not decide whether a job is runnable. It publishes runtime
# monitoring facilities that are enforced by queuebash.sh after the payload has
# started. The worker uses /proc and, where available, lsof -p to detect process
# behaviour that static analysis cannot prove safe.


_queue_cap_runtime_caps_normalise() {
    local caps="${1:-${RUNTIME_CAPS:-}}"
    caps="${caps//_/-}"
    caps="${caps//,/ }"
    caps="${caps//;/ }"
    caps="${caps//|/ }"
    printf '%s\n' "$caps" | awk '{for (i=1;i<=NF;i++) if ($i != "") print $i}' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

_queue_cap_runtime_has() {
    local want="$1" cap
    for cap in $(_queue_cap_runtime_caps_normalise "${RUNTIME_CAPS:-}" 2>/dev/null); do
        [[ "$cap" == "$want" ]] && return 0
    done
    return 1
}

queue_cap_facilities() {
    echo "runtime:no_spawn_shell Blocks jobs that spawn a child shell such as sh/bash/zsh/ksh"
    echo "runtime:no_network_tools Blocks curl/wget/nc/socat/ssh-style network tools at runtime"
    echo "runtime:no_network_sockets Uses lsof -p to block jobs that open any INET socket"
    echo "runtime:only_local_sockets Uses lsof -p to allow only localhost-bound/localhost-targeted INET sockets"
    echo "runtime:only_port Uses lsof -p to allow only listed/ranged TCP/UDP service ports"
}

queue_cap_candidate_runtime_no_spawn_shell() {
    _queue_cap_runtime_has no-spawn-shell || return 0
    printf 'runtime\tno-spawn-shell\truntime:no_spawn_shell\tinterval=%s\n' "${RUNTIME_CAP_INTERVAL:-1}"
}

queue_cap_candidate_runtime_no_network_tools() {
    _queue_cap_runtime_has no-network-tools || return 0
    printf 'runtime\tno-network-tools\truntime:no_network_tools\tinterval=%s\n' "${RUNTIME_CAP_INTERVAL:-1}"
}

queue_cap_candidate_runtime_no_network_sockets() {
    _queue_cap_runtime_has no-network-sockets || return 0
    printf 'runtime\tno-network-sockets\truntime:no_network_sockets\tinterval=%s tool=lsof\n' "${RUNTIME_CAP_INTERVAL:-1}"
}

queue_cap_candidate_runtime_only_local_sockets() {
    _queue_cap_runtime_has only-local-sockets || return 0
    printf 'runtime\tonly-local-sockets\truntime:only_local_sockets\tinterval=%s tool=lsof policy=localhost-only\n' "${RUNTIME_CAP_INTERVAL:-1}"
}

queue_cap_candidate_runtime_only_port() {
    _queue_cap_runtime_has only-port || return 0
    printf 'runtime\tonly-port\truntime:only_port\tinterval=%s tool=lsof ports=%s\n' "${RUNTIME_CAP_INTERVAL:-1}" "${RUNTIME_CAP_PORTS:-unset}"
}
