# bashqueues reporting plugins

`queuebash` reporting is an event-observer layer.  The engine always writes its
normal JSONL event log first.  Reporter plugins may then observe that event and
send it to an external system such as an NMS.

Reporter plugins live under:

- `$QUEUEBASH_ROOT/reporters.d`
- bundled source tree `reporters.d/` for first-time installation into a queue root

A reporter plugin exports:

```bash
queue_reporter_facilities() { ... }          # optional metadata publisher
queue_reporter_handle_event EVENT QID NAME STATE DETAIL TS
```

Discovery is metadata-only:

```bash
queue reporters list
queue reporters list --json
```

## Configuration

Reporting policy/env files are sourced from:

- `/etc/bashqueues/reporting.env`
- `/etc/queuebash/policies.d/reporting/default.env`
- `$QUEUEBASH_ROOT/policies.d/reporting/default.env`
- `$QUEUEBASH_ROOT/reporting.env`
- bundled `policies.d/reporting/default.env`

Set `QUEUEBASH_REPORTING_DISABLE=1` to suppress all reporters.

## SNMP INFORM reporter

The bundled `reporters.d/snmp.sh` plugin is disabled unless explicitly configured:

```bash
QUEUEBASH_SNMP_INFORM_DEST="10.0.0.250:162"
QUEUEBASH_SNMP_COMMUNITY="secure-alerts"
QUEUEBASH_SNMP_TRAP_OID=".1.3.6.1.4.1.99999.1"
QUEUEBASH_SNMP_INFORM_EVENTS="pol_blocked,failed,runtime_cap_violation,log_overflow_kill"
```

No NMS address, community string, or trap target is hard-coded into the queue
engine.  The reporting pipeline is intentionally decoupled from `_queue_log_event`:
logging remains local and deterministic, while reporters are optional observers.


## Microsoft Notify reporter

The bundled `reporters.d/ms.sh` plugin sends selected queue events to a
Microsoft-facing HTTP ingestion endpoint such as a Fabric, Sentinel, or Log
Analytics bridge.  It is disabled unless explicitly configured:

```bash
QUEUEBASH_REPORTERS="ms"
QUEUEBASH_MS_ENDPOINT="https://example.ingest.monitor.azure.com/..."
QUEUEBASH_MS_TENANT="00000000-0000-0000-0000-000000000000"
QUEUEBASH_MS_CLIENT_ID="00000000-0000-0000-0000-000000000000"
QUEUEBASH_MS_CLIENT_SECRET_FILE="/etc/bashqueues/secrets/ms-client-secret"
QUEUEBASH_MS_SCOPE="https://management.azure.com/.default"
QUEUEBASH_MS_TABLE="QueuebashEvent"
QUEUEBASH_MS_EVENTS="failed,pol_blocked,runtime_cap_violation,log_overflow_kill"
```

The plugin uses Entra client-credentials flow, reads the client secret from a
file, and never writes the secret or bearer token to the reporter error log.  It
requires `curl` plus either `jq` or `python3` for JSON handling.  `QUEUEBASH_MS_SCOPE`
can be adjusted for the exact ingestion API being used.

## `net_usage.sh`

Do not add `assets.d/net_usage.sh`.  The canonical charged-link asset facility is
`net:allowance` in `assets.d/net.sh`.  The old `net_usage` name is only a
compatibility alias/facility where needed; the asset-side helper file remains
absent to avoid name incompatibility and plugin sprawl.
