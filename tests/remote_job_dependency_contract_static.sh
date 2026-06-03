#!/usr/bin/env bash
set -euo pipefail
must_have() { grep -R -- "$1" "$2" >/dev/null || { echo "missing $1 in $2" >&2; exit 1; }; }
must_not_have() { grep -R -- "$1" "$2" >/dev/null && { echo "forbidden $1 in $2" >&2; exit 1; } || true; }
must_have "queuebash.remote_dependency.v1" docs/REMOTE_JOB_DEPENDENCIES.md
must_have "waiting_remote" docs/REMOTE_JOB_DEPENDENCIES.md
must_have "pre-dispatch gate" docs/REMOTE_JOB_DEPENDENCIES.md
must_have "fail closed" docs/REMOTE_JOB_DEPENDENCIES.md
must_have "queue explain" docs/REMOTE_JOB_DEPENDENCIES.md
must_have "ACL" docs/REMOTE_DEPENDENCY_SECURITY_MODEL.md
must_have "signature" docs/REMOTE_DEPENDENCY_SECURITY_MODEL.md
must_have "QUEUEBASH_REMOTE_DEPENDENCY_ALLOW_SSH=0" policies.d/remote-dependency/default.env.example
must_have "QUEUEBASH_REMOTE_DEPENDENCY_ALLOW_UNAUTHENTICATED_HTTP=0" policies.d/remote-dependency/default.env.example
must_have "QUEUEBASH_REMOTE_DEPENDENCY_ALLOW_WORKER_POLLING=0" policies.d/remote-dependency/default.env.example
must_have "queuebash.remote_dependency.request.v1" schemas/remote_dependency/request.example.json
must_have "queuebash.remote_dependency.v1" schemas/remote_dependency/waiting.example.json
must_have "queuebash.remote_dependency.v1" schemas/remote_dependency/satisfied.example.json
must_not_have "ssh " providers.d/remote_dependency
must_not_have "curl " providers.d/remote_dependency
must_not_have "wget " providers.d/remote_dependency
must_not_have "eval " providers.d/remote_dependency
must_not_have "nc " providers.d/remote_dependency
[[ -x providers.d/remote_dependency/remote_dependency_provider.sh ]]
[[ -x providers.d/remote_dependency/remote_dependency_fixture.py ]]
echo "remote job dependency contract static checks passed"
