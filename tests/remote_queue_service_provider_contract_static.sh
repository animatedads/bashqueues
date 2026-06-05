#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -Eq 'QUEUEBASH_VERSION="0\.18\.(28|29|30|31|32|33|34|35|36|37|38|39|4[0-9]|([5-9][0-9]|[1-9][0-9][0-9]))"' queuebash.sh || fail 'version does not preserve remote service line at 0.18.28 or newer'
grep -q '0.18.28 - remote queue service provider contract' CHANGELOG.md || fail 'changelog entry missing'
grep -q '0.18.28 remote queue service provider contract' README.md || fail 'README remote service entry missing'

for f in docs/REMOTE_QUEUE_SERVICE_PROVIDER.md examples/providers/remote-queue.env.example; do
  [[ -f "$f" ]] || fail "missing $f"
done

doc=docs/REMOTE_QUEUE_SERVICE_PROVIDER.md
example=examples/providers/remote-queue.env.example

grep -q 'queuebash.remote_queue_service.v1' "$doc" || fail 'service schema missing'
grep -q 'queuebash.remote_queue_policy_request.v1' "$doc" || fail 'policy request schema missing'
grep -q 'queuebash.remote_queue_policy_response.v1' "$doc" || fail 'policy response schema missing'
grep -q 'queue-remote-policy-check' "$doc" || fail 'policy helper missing'
grep -q 'No returned value is evaluated as shell' "$doc" || fail 'no-shell policy output rule missing'
grep -q 'not a shell' "$doc" || fail 'not-shell contract missing'
grep -q 'generic `/run`, `/exec`, `/shell`, `/command`, or `/cmd` endpoints' "$doc" || fail 'generic endpoint ban missing'
grep -q 'process.ps' "$doc" || fail 'process.ps operation missing'
grep -q 'process.kill' "$doc" || fail 'process.kill operation missing'
grep -q 'session process registry' "$doc" || fail 'session process registry missing'
grep -q 'PID 1' "$doc" || fail 'PID 1 rejection missing'
grep -q 'queue dev patch' "$doc" || fail 'queue dev patch operation missing'
grep -q 'queue dev splice' "$doc" || fail 'queue dev splice operation missing'
grep -q 'queue dev test' "$doc" || fail 'queue dev test operation missing'
grep -q 'auth-gated\|Authentication proves' "$doc" || fail 'auth gate missing'
grep -q 'policy-gated\|policy decides' "$doc" || fail 'policy gate missing'
grep -q 'fail-closed' "$doc" || fail 'fail-closed rule missing'
grep -q 'audit event' "$doc" || fail 'audit event contract missing'
grep -q '/etc/queuebash/policy/providers.d/remote-queue.env' "$doc" || fail 'canonical config path missing'
grep -q '/usr/libexec/queuebash/providers/remote-queue' "$doc" || fail 'canonical helper path missing'
grep -q '/var/lib/queuebash/remote-queue/sessions' "$doc" || fail 'canonical session path missing'
grep -q '/var/log/queuebash/remote-queue-audit.jsonl' "$doc" || fail 'canonical audit path missing'

if grep -R '/etc/bashqueues' "$doc" "$example" >/dev/null; then
  fail 'remote service docs/examples must not introduce /etc/bashqueues namespace drift'
fi

grep -q 'QUEUE_REMOTE_ALLOW_GENERIC_SHELL=0' "$example" || fail 'example must disable generic shell'
grep -q 'QUEUE_REMOTE_ALLOW_HOST_PS=0' "$example" || fail 'example must disable host ps'
grep -q 'QUEUE_REMOTE_ALLOW_HOST_KILL=0' "$example" || fail 'example must disable host kill'
grep -q 'QUEUE_REMOTE_FAIL_CLOSED=1' "$example" || fail 'example must fail closed'
grep -q 'QUEUE_REMOTE_REQUIRE_POLICY=1' "$example" || fail 'example must require policy'
grep -q 'process.ps process.kill' "$example" || fail 'example must include scoped process operations'

# Contract package must not mutate the accepted runner into a generic shell endpoint.
if grep -Eq 'op == "(run|exec|shell|command|cmd)"|operation == "(run|exec|shell|command|cmd)"|"/run"' bin/queue-dev-runner.py; then
  fail 'generic command endpoint found in remote runner'
fi

if [[ -e assets.d/net_usage.sh ]]; then
  fail 'assets.d/net_usage.sh must remain absent'
fi
[[ -f caps.d/net_usage.sh ]] || fail 'caps.d/net_usage.sh may remain present and is expected in this package'

echo '[PASS] remote queue service provider contract static checks pass'
