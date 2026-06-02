#!/usr/bin/env bash
# queuemgr.sh compatibility shim.
# Legacy text/menu QueueManager is disabled; the supported manager is the Python panel manager.

_queue_manager() {
    queue mgr panel "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"
    export QUEUEBASH_ALLOW_NONINTERACTIVE=1
    # shellcheck source=/dev/null
    source "$script_dir/queuebash.sh"
    queue mgr panel "$@"
fi
