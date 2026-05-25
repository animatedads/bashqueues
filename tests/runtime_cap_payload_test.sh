#!/usr/bin/env bash
#
# bashqueues runtime-cap test payload
#
# This deliberately does two things a secured class should object to:
#
#   1. opens a TCP listener on port 61000
#   2. spawns a child shell which writes "hello world" to a unique file in $HOME
#
# Expected secured behaviour:
#   - runtime:no_network_tools may catch nc/socat/python networking helpers
#   - runtime:only_local_sockets should catch non-local socket binding
#   - runtime:only_port should catch port 61000 if it is not allow-listed
#   - runtime:no_spawn_shell should catch the child /bin/sh
#   - strict sandbox may also block HOME writes
#

set -euo pipefail

PORT="${1:-61000}"
STAMP="$(date +%Y%m%d_%H%M%S)_$$"
OUTFILE="${HOME}/bashqueues_runtime_cap_test_${STAMP}.txt"

server_pid=""

cleanup() {
    if [[ -n "${server_pid}" ]] && kill -0 "${server_pid}" 2>/dev/null; then
        kill "${server_pid}" 2>/dev/null || true
        wait "${server_pid}" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

echo "runtime-cap-test: starting"
echo "runtime-cap-test: port=${PORT}"
echo "runtime-cap-test: outfile=${OUTFILE}"

start_tcp_server() {
    if command -v nc >/dev/null 2>&1; then
        # Bind to 0.0.0.0 deliberately so localhost-only socket policy can catch it.
        while true; do
            printf 'bashqueues runtime cap test server\n' | nc -l -p "${PORT}" -s 0.0.0.0
        done
        return
    fi

    if command -v ncat >/dev/null 2>&1; then
        while true; do
            printf 'bashqueues runtime cap test server\n' | ncat -l 0.0.0.0 "${PORT}"
        done
        return
    fi

    if command -v socat >/dev/null 2>&1; then
        socat "TCP-LISTEN:${PORT},bind=0.0.0.0,reuseaddr,fork" SYSTEM:'printf "bashqueues runtime cap test server\n"'
        return
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "${PORT}" <<'PY'
import socket
import sys

port = int(sys.argv[1])
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", port))
s.listen(5)

while True:
    conn, _addr = s.accept()
    with conn:
        conn.sendall(b"bashqueues runtime cap test server\n")
PY
        return
    fi

    echo "runtime-cap-test: no tcp helper found; cannot open test server" >&2
    return 1
}

start_tcp_server &
server_pid="$!"

echo "runtime-cap-test: server_pid=${server_pid}"

# Give the watchdog a moment to see the listener.
sleep 2

# Spawn an actual child shell deliberately.
# This should be caught by runtime:no_spawn_shell.
(
    /bin/sh -c "printf '%s\n' 'hello world' > '${OUTFILE}'"
)

echo "runtime-cap-test: child shell completed"

# Stay alive briefly so runtime socket caps have time to inspect us.
sleep 20

echo "runtime-cap-test: finished"
