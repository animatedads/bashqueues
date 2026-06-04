# bashqueues policy namespace

## Canonical system policy root

The canonical installed system policy root is:

```text
/etc/queuebash/policies.d
```

This path must be reported consistently by:

- `install-system.sh --dryrun`
- `queue-policy-wizard --scope system --dryrun --json`
- queuebash shared policy resolution via `_queue_policy_shared_root`
- system installer signing and remote-listener verification paths
- operator documentation and static tests

The older plural `/etc/bashqueues/policies.d` path is legacy history only for new system policy writes. Operators should not split policy files across both trees.

## Compatibility guidance

If an older local experiment created `/etc/bashqueues/policies.d`, migrate intended site policy files into `/etc/queuebash/policies.d` and verify with:

```bash
install-system.sh --dryrun
queue-policy-wizard --scope system --dryrun --json
```

Both commands should report `/etc/queuebash/policies.d` as the system policy tree.

## User scope

User-scope policy wizard output remains queue-local:

```text
~/.queuebash/policies.d
```

User scope is for local development and personal queue roots. System scope is for shared/admin policy on installed hosts.

## Shell function versus installed wrapper

Before system install, `queue` is a shell function and only exists in shells that source `queuebash.sh`. After system install, `/usr/local/bin/queue` is a wrapper suitable for scripts, cron, CI, `timeout`, and systemd.

## Enterprise pilot note

Rupert enterprise acceptance evidence for 0.18.108 identified policy-root inconsistency as a P0 operational clarity issue. The installer, policy wizard, runtime resolver, docs, examples, and verification commands must agree on the active policy root before broad live regulated-service deployment.
