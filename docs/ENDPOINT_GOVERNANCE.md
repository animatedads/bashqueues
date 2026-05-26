# ENDPOINT_GOVERNANCE

The `endpoint` asset family extends sovereignty from worker placement to outbound
submission targets.  A UK-secured job running on a UK worker is still wrong if it
submits the result to a US endpoint.  These assets fail closed unless the endpoint
can be mapped to an allowed region.

Facilities:

- `endpoint:jurisdiction_allowed` checks a single URL/host/IP against a named legal framework.
- `endpoint:region_allowed` checks a single URL/host/IP against an explicit region list.
- `endpoint:command_jurisdiction_allowed` scans the queued command for URLs and `host:port` tokens and checks all discovered endpoints against a named legal framework.
- `endpoint:command_region_allowed` scans the queued command against an explicit region list.

Example class requirement:

```bash
queue_class_shared_asset endpoint jurisdiction_allowed "https://submit.uk.example.com/api" framework=UK_DPA
```

Example mandatory policy asset:

```bash
CLASS_POLICY_MANDATORY_ASSETS=$'endpoint\tcommand_jurisdiction_allowed\tUK_DPA\tallow_empty=1'
```

Endpoint region mapping lives in:

- `/etc/bashqueues/policies.d/endpoint-jurisdiction/default.env`
- `/etc/bashqueues/policies.d/endpoint_jurisdiction.env`
- `$QUEUEBASH_ROOT/policies.d/endpoint-jurisdiction/default.env`
- bundled `policies.d/endpoint-jurisdiction/default.env`

The asset deliberately does not call a public GeoIP service.  Production systems
should populate the map from a CMDB, cloud inventory, service catalogue, or
controlled DNS/IP range registry.

Example mapping:

```bash
QUEUEBASH_ENDPOINT_REGION_SUBMIT_UK_EXAMPLE_COM="uksouth"
QUEUEBASH_ENDPOINT_REGION_SUBMIT_US_EXAMPLE_COM="us-east-1"
QUEUEBASH_ENDPOINT_SUFFIX_REGION_UK_EXAMPLE_COM="uksouth"
QUEUEBASH_ENDPOINT_CIDR_REGION_1="203.0.113.0/24=eu-west-2"
```

Unknown public endpoints block.  Unknown private endpoints also block unless
`QUEUEBASH_ENDPOINT_ALLOW_PRIVATE_UNKNOWN=1` or `allow_private_unknown=1` is
used for a specific asset declaration.
