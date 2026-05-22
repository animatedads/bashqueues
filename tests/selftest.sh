#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp"

queue submit testls -- echo one >/dev/null
queue submit testls -- echo two >/dev/null
queue submit failer -- definitely_not_a_command_12345 >/dev/null

queue priority testls 100 >/dev/null
queue --dryrun pause testls >/dev/null
queue pause testls >/dev/null
queue unpause testls >/dev/null

queue run --workers 2 >/dev/null || true

queue resubmit failer >/dev/null
queue --dryrun cancel failer >/dev/null || true
queue stats >/dev/null
queue version >/dev/null
queue events --tail 10 >/dev/null

echo "bashqueues selftest: OK"


# Retry behaviour
mkdir -p "$tmp/retry"
cat > "$tmp/retry/flaky.sh" <<'EOS'
#!/usr/bin/env bash
count_file="$1"
count="$(cat "$count_file" 2>/dev/null || echo 0)"
count=$((count + 1))
echo "$count" > "$count_file"
[[ "$count" -ge 2 ]]
EOS
chmod +x "$tmp/retry/flaky.sh"
queue submit retryonce --retries 1 --backoff 0 -- "$tmp/retry/flaky.sh" "$tmp/retry/count" >/dev/null
queue run >/dev/null || true
queue run >/dev/null || true
grep -q '^2$' "$tmp/retry/count"



# Detached worker behaviour
queue submit slowish -- bash -c 'sleep 0.2; echo detached-ok' >/dev/null
queue start --workers 1 >/tmp/qb_start_test.out
grep -q 'Detached workers started' /tmp/qb_start_test.out
for i in $(seq 1 30); do
    if queue list --state done | grep -q slowish; then
        break
    fi
    sleep 0.1
done
queue list --state done | grep -q slowish
