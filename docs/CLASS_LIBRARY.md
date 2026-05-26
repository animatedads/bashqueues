# bashqueues Class Library

Version 0.17.61+. Nine new classes plus a cron class selector plugin.

---

## Class overview

| Class | Parallel | Concurrent | Sandbox | Time Window | Key gates |
|---|---|---|---|---|---|
| `ALERT_NOTIFICATION` | yes | 5 | restrict-egress | none (24/7) | interface_state |
| `BACKUP_JOB` | no | 1 | network-none | 01:00–05:00 | mount, freespace, once-per-20h |
| `BATCH_PROCESSING` | no | 1 | network-none | 19:00–06:00 | cpu_load, freespace |
| `DB_MIGRATION` | no | 1 | network-none | 20:00–05:00 | db connect, no active migration |
| `DEADLINE_CRITICAL` | yes | unlimited | network-none | 18:00–06:00 | deadline monitor+panic, extra worker |
| `DEPLOY_RELEASE` | no | 1 | restrict-egress | none | git clean, target reachable |
| `FILE_TRANSFER` | no | 2 | restrict-egress | 20:00–06:00 | mount, allowance, iowait |
| `INTERACTIVE_PRIORITY` | yes | 10 | network-none | none (24/7) | cpu_load, memory |
| `LOG_HOUSEKEEPING` | no | 1 | network-none | 02:00–05:00 | secaudit, freespace |
| `REPORT_GENERATION` | yes | 3 | network-none | 24/7 | db connect, freespace |
| `SENSITIVE_DATA_EXPORT` | no | 1 | strict + seccomp strict | 22:00–04:00 | secaudit (3 checks), no-network-sockets |

---

## Class design principles

**Exclusive vs shared claims.** Classes that must never overlap system-wide
(migrations, sensitive exports, backups) use `queue_class_exclusive_claim`.
Classes that tolerate controlled parallelism (reports, alerts, interactive)
use only `CLASS_MAX_CONCURRENT` for rate limiting.

**Security floors by class type:**

- Administrative/housekeeping: `network-none` + `docker-default`
- Data exports: `strict` + `seccomp strict` + runtime caps
- Transfers: `restrict-egress` (network required) + `no-spawn-shell`
- Interactive: `network-none` (fast, short timeout, no seccomp overhead)
- Deadline-critical: `network-none` with panic fallback bypassing time gates only

**Once-per-period guards.** `BACKUP_JOB` and `DB_MIGRATION` use
`queue:job_has_not_run` to prevent duplicate runs from cron double-fires
or manual resubmits. Set `time=` to match your actual run frequency.

**Site overrides.** Every class defines `export QUEUEBASH_*` environment
variables that operators can set before sourcing `queuebash.sh` to adapt
paths, hosts, and thresholds to the local installation without editing
the class file itself.

---

## Cron class selector plugin

**File:** `bin/bashqueues-cron-class-selector.py`

The selector analyses a cron command string and returns the most appropriate
class name. It is called by the cron ticker when no explicit `BASHQUEUES_CLASS`
is declared in the crontab entry.

### Integration in `bashqueues-cron-ticker.py`

In `_resolve_cron_class`, after confirming no explicit class is set:

```python
# After the existing explicit_class None check:
if not explicit_class:
    selector = Path(__file__).parent / "bashqueues-cron-class-selector.py"
    if selector.exists():
        try:
            import subprocess, json as _json
            out = subprocess.check_output(
                [sys.executable, str(selector),
                 "--command", command,
                 "--user", user,
                 "--json"],
                text=True, timeout=5
            )
            d = _json.loads(out)
            if d.get("class") and d.get("confidence", 0) >= 70:
                candidate = d["class"]
                if not _cron_class_below_minimum(user, qsrc, candidate):
                    return candidate, None
        except Exception:
            pass  # Selector failure is non-fatal; fall through to generated class.
```

The selector failure path is intentionally silent — if the selector is absent
or errors, the ticker generates its safe per-command cron class as before.

### CLI usage

```bash
# Plain output (class name or empty)
bashqueues-cron-class-selector.py --command "/opt/scripts/nightly-backup.sh" --user hc3

# JSON output
bashqueues-cron-class-selector.py --command "CMD" --user hc3 --json

# Explain all rule evaluations
bashqueues-cron-class-selector.py --command "CMD" --user hc3 --explain

# Override minimum confidence (default 70)
bashqueues-cron-class-selector.py --command "CMD" --user hc3 --min-confidence 80
```

### Selector behaviour

The selector applies ordered rules by priority. The first matching rule
above the confidence threshold whose class file exists on the system wins.
When no rule matches, output is empty and the ticker uses its generated class.

Rules check for command tokens (word-boundary regex), substrings, and
file extension patterns. They are intentionally conservative — a command
that partially resembles a backup but has no backup verb will not match.

The `--no-existence-check` flag bypasses the class file check for testing.
In production, the existence check prevents the selector from returning a
class that is not installed on the current machine.

### Extending the selector

Add new rules by appending to the `RULES` list in the selector script:

```python
Rule(
    priority=45,           # Lower = higher priority
    class_name="MY_CLASS",
    confidence=82,
    reason="human-readable explanation of what this rule detects",
    pattern_fn=lambda cmd, env: _has_token(cmd, "my-tool", "my-keyword")
)
```

Re-sort RULES after adding (or maintain insertion order by priority).

---

## Crontab declaration syntax

When the selector's automatic detection is insufficient, declare the class
explicitly in the crontab file using a `BASHQUEUES_CLASS=` assignment:

```
# Explicit class for this entry and all entries below until reassigned.
BASHQUEUES_CLASS=DEADLINE_CRITICAL
0 2 * * 1-5  /opt/scripts/month-end-recon.sh

# Attach an authorisation code for policy-gated classes.
BASHQUEUES_CLASS=SENSITIVE_DATA_EXPORT
BASHQUEUES_AUTHORISATION=AUTH-XXXX-YYYY-ZZZZ
30 22 * * 0  /opt/scripts/weekly-export.sh

# Reset to selector-chosen class for subsequent entries.
BASHQUEUES_CLASS=
*/15 * * * *  /opt/scripts/poll.sh
```

The `BASHQUEUES_CLASS=` assignment applies to all subsequent entries in
the same crontab file until reassigned or cleared with `BASHQUEUES_CLASS=`.
