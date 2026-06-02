# queue fetch

`queue fetch` retrieves result metadata for completed jobs, subject to class-level egress policy.

## Usage

queue fetch --job-id ID [--json]
queue fetch --class CLASS [--status done] [--limit N] [--json]

## Egress policy

The class definition controls whether results can be fetched:

- `CLASS_EGRESS_ALLOWED_JURISDICTION` — jurisdiction that may receive results (GLOBAL, UK_DPA, NONE, etc.)
- `CLASS_EGRESS_REQUIRE_ENCRYPTION` — if 1, only local fetches or encrypted remote fetches are permitted
- `CLASS_RESULT_RETENTION_DAYS` — days after which results are no longer available

## JSON schema

queuebash.fetch.v1

## Audit

Every fetch emits a queuebash.egress.v1 event to $QUEUEBASH_ROOT/logs/egress-audit.jsonl.

## Remote fetch

job.fetch is available as a remote operation via queue remote SERVICE job fetch JOBID.
