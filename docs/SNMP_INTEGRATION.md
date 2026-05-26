# SNMP integration

bashqueues has two deliberately separate SNMP integration points:

1. `assets.d/snmp.sh` is an inbound preflight asset plugin.  The queue acts as an SNMP manager and polls an external NMS or device before dispatching a job.
2. `bin/queue_snmp_inform.sh` is an outbound notification helper.  The queue, or a site-local hook, can send a strictly typed SNMP INFORM to an NMS when a terminal condition occurs.

The split is intentional.  SNMP polling is infrastructure-specific and belongs in class assets.  SNMP reporting is site-specific and should be wired through local hooks, `ON_FAILURE`, or event processing.

## Inbound asset plugin

Published facilities:

```text
snmp:int_below
snmp:int_above
snmp:truth_ok
snmp:string_match
```

All facilities use `snmpget -Oqv` so Net-SNMP returns only the value component, not the MIB/type prefix.  Numeric checks validate the value with `^[0-9]+$` before any shell arithmetic.  Missing `snmpget`, SNMP errors, unexpected types, timeouts, and unsupported versions all fail closed with `asset_check_blocked`.

### Central SNMP map

Class files should not have to carry opaque numeric OIDs such as `.1.3.6.1.4.1.2021.11.9.0`.  The SNMP asset therefore supports a central map file.  Preferred site locations are:

```text
/etc/bashqueues/snmp-map.env
/etc/bashqueues/snmp.d/default.env
```

A queue-local or bundled fallback can also exist at:

```text
$QUEUEBASH_ROOT/policies.d/snmp-map/default.env
policies.d/snmp-map/default.env
```

Map entry format:

```bash
SNMP_MAP_SAN_CPU_TARGET="10.0.0.5"
SNMP_MAP_SAN_CPU_OID=".1.3.6.1.4.1.2021.11.9.0"
SNMP_MAP_SAN_CPU_COMM="monitor"
SNMP_MAP_SAN_CPU_V="2c"
SNMP_MAP_SAN_CPU_MAX="85"

SNMP_MAP_MAINT_WINDOW_TARGET="10.0.0.250"
SNMP_MAP_MAINT_WINDOW_OID=".1.3.6.1.4.1.99999.10.1.0"
SNMP_MAP_MAINT_WINDOW_EXPECT_INT="1"
```

Class definitions can then use readable aliases:

```bash
queue_class_shared_asset snmp int_below SAN_CPU max=85
queue_class_shared_asset snmp truth_ok MAINT_WINDOW
queue_class_shared_asset snmp string_match SITE_STATE expect_str="Active" match=exact
```

Explicit class parameters override map defaults.  For example, `max=90` in a class overrides `SNMP_MAP_SAN_CPU_MAX=85` without editing the central map.

Direct OID usage remains supported for quick tests and one-off local classes.

## Parameters

Common parameters:

```text
oid=OID       required unless target or map= names a central SNMP map alias
map=ALIAS     optional explicit central map alias; otherwise a target with no oid= is treated as the alias
comm=TEXT     SNMP community, default public
v=1|2c        SNMP version, default 2c
timeout=N     seconds, default 5
retries=N     Net-SNMP retry count, default 1
```

Facility-specific parameters:

```text
snmp:int_below      max=N
snmp:int_above      min=N
snmp:truth_ok       expect_int=N, default 1
snmp:string_match   expect_str=TEXT match=exact|contains
```

## Outbound SNMP INFORM helper

`bin/queue_snmp_inform.sh` sends a typed SNMP v2c INFORM:

```bash
JOB_NAME="nightly-import" \
JOB_ID="20260525_101500_123456" \
JOB_SNMP_STATE_INT=2 \
JOB_EXIT_REASON="pol_blocked command matched emergency policy" \
  bin/queue_snmp_inform.sh 10.0.0.250 alerts
```

Default virtual MIB layout, rooted at `.1.3.6.1.4.1.99999.1` unless a third argument overrides it:

```text
.1  bashqueuesJobName        s  OctetString
.2  bashqueuesJobId          s  OctetString
.3  bashqueuesTerminalState  i  Integer32
.4  bashqueuesReason         s  OctetString
```

State integer convention:

```text
1 failed
2 pol_blocked
3 security_cap_tripped
4 auth_tampered
```

The helper checks for `snmpinform` and fails clearly with `tool_missing=snmpinform` if Net-SNMP tools are not installed.

## Operational note

Do not hard-code one organisation's OIDs into bashqueues.  SNMP OIDs, communities, maintenance-window states, and monitored thresholds belong in `/etc/bashqueues/snmp-map.env` or another site map file.  Class definitions should normally reference stable aliases such as `SAN_CPU`, `MAINT_WINDOW`, or `SITE_STATE`.  The bundled plugin provides the safe framework; the local SNMP map provides the network-specific meaning.
