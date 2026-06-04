# Bob21 optional AI policy gate

Bob21 adds an optional local AI policy-blocking companion module for bashqueues.
It follows the same design direction as `queue ask`: provider-shaped, local by
default, auditable, bounded, and policy-gated. It is not wired into the main
queue dispatcher by default.

## Purpose

The gate reviews pending jobs before worker dispatch and classifies potential
hostile or policy-harmful intent. It has three conservative outcomes:

| Decision | Effect |
| --- | --- |
| `allow` | Leave the pending job unchanged. |
| `advise_delay` | Append a bounded `NOT_BEFORE_EPOCH` delay and advisory metadata. |
| `pol_block` | Move the pending job into `pol_blocked`. |

`pol_block` is deliberately narrow. The helper downgrades model block requests
unless they meet both tests:

1. confidence is at or above `QUEUEBASH_AI_POLICY_GATE_BLOCK_THRESHOLD`
   (default `0.86`), and
2. the category is a hostile/security-harm category such as credential theft,
   malware, exfiltration, privilege escalation, persistence, policy bypass, or
   destructive operation.

Ambiguous security operations, legitimate admin work, tests, dry-runs, and weak
matches should become advisory delays rather than hard blocks.

## Local-only model configuration

Recommended environment:

```bash
export QUEUEBASH_AI_POLICY_GATE_ENABLED=1
export QUEUEBASH_AI_PROVIDER=ollama
export QUEUEBASH_AI_MODEL=gemma4:e2b
```

The live provider uses the local Ollama generate API at
`http://127.0.0.1:11434/api/generate` by default. Non-loopback URLs are refused
unless an explicit unsafe override is set. The request contains only bounded job
metadata and a truncated command string; it does not read job environment files,
logs, outputs, secrets, class claim internals, or arbitrary payload files.

## Usage

Dry-run a pending scan:

```bash
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 \
  bin/queue-ai-policy-gate scan --dry-run --limit 10
```

Apply decisions to pending jobs:

```bash
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 \
  bin/queue-ai-policy-gate scan --limit 10
```

Classify a single job by job id or name and print the normalized decision. Pending jobs may live below priority directories such as `pending/p0999999990/`; the helper resolves that layout internally:

```bash
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 \
  bin/queue-ai-policy-gate classify --job-id badjob
```

`--job-file` remains available as a low-level/debug input, but `--job-id` is the normal operator interface.

Provider contract discovery:

```bash
providers.d/ai_policy_gate/ollama.sh describe
```

## Audit and mutation behaviour

The module writes audit lines to:

```text
$QUEUEBASH_ROOT/logs/ai-policy-gate.audit.jsonl
```

For advisory delays, it appends fields such as:

```text
AI_POLICY_GATE_ADVISORY=1
AI_POLICY_GATE_DELAY_SECONDS=900
NOT_BEFORE_EPOCH=<future epoch>
```

For policy blocks, it appends fields such as:

```text
POLICY_BLOCKED=1
POLICY_BLOCKED_BY=ai_policy_gate
AI_POLICY_GATE_DECISION=pol_block
```

then moves the job from `pending/` to `pol_blocked/`.

## Installation model

This is a companion module. Operators can run it from a systemd timer, cron, or
sentinel wrapper before worker dispatch. It intentionally avoids changing the
main queue code path in this patch.

## Failure posture

If the local model is unavailable, the helper emits a bounded error event. It
does not block all jobs by default merely because AI is unavailable. Sites that
need fail-closed behaviour should run the helper from a higher-level policy
wrapper that treats helper errors as a local operational incident.

## Candidate v2 hardening notes

This candidate revision tightens merge-readiness and conservative behaviour:

- `--fixture-decision-dir` supports per-job fixture decisions for deterministic
  tests without accidentally applying one hostile fixture to every pending job.
- Obvious inline secrets in command text are redacted before prompt/request JSON
  is built. Audit logs continue to store hashes and decisions, not raw commands.
- Existing later `NOT_BEFORE_EPOCH` values are preserved; advisory delay will not
  shorten a job's current pre-boarding hold.
- The model prompt explicitly treats the job command as untrusted data and tells
  the model to ignore prompt-injection attempts embedded inside the job itself.
- `--config policies.d/ai-policy-gate/default.env` can load simple `KEY=VALUE`
  defaults without shell evaluation; explicit environment variables still win.

## Optional ITSM ticket requests

Bob21 can mirror enforced policy actions into the existing bashqueues ITSM
reporter contract. This is optional and local: the helper writes the normalized
`queuebash.reporter.itsm_event.v1` JSONL outbox only when
`QUEUEBASH_ITSM_ENABLED=1` and the event is allowed by `QUEUEBASH_ITSM_EVENTS`.

Default behaviour is deliberately asymmetric:

- `pol_block` requests an ITSM ticket by default (`policy_blocked`, severity
  `critical`) because the job has been moved to `pol_blocked/`.
- `advise_delay` does not request a ticket by default, but can do so with
  `QUEUEBASH_AI_POLICY_GATE_TICKET_ON_ADVISE_DELAY=1`, emitting
  `advisory_high_risk_operation`.

The event remains contract-only unless a site has a downstream reporter watching
the ITSM outbox. Bob21 sets `ticket_requested=true`, `ticket_created=false`,
`contract_only=true`, includes a correlation key and command hash, and keeps the
job command/body out of the ticket event.

## Candidate v5 deterministic containment examination

Candidate v5 keeps the separate deterministic containment examiner and expands its acceptance fixtures. The examiner is
not the AI model and does not execute commands, SQL, Python, shell, or network
activity. It reads only the pending job command text and extracts bounded static
patterns.

The process is deliberately two-stage:

1. `examine` builds a plan from the job type and script payloads. It selects only
   the relevant static check families, currently `bash`, `sql`, `python`, and
   generic embedded-script patterns.
2. `classify`/`scan` include the examination bundle in the local AI request. The
   model gets a second-shot review over the command/data-flow pattern rather
   than isolated words.

Example:

```bash
bin/queue-ai-policy-gate examine --job-id badjob
```

If the job command directly references a local script such as `bash badscript.sh`, the examiner may statically read that script from `PWD_AT_SUBMIT`, bounded by `QUEUEBASH_AI_POLICY_GATE_SCRIPT_MAX_BYTES`, without executing it. By default the script must resolve under the submit directory; this preserves the containment boundary while allowing command/data-flow pattern checks across bash, SQL, Python, and generic script text.

The examination JSON has schema:

```text
queuebash.ai_policy_gate.examination.v1
```

and includes:

```text
executed=false
external_network=false
job_type_plan.languages
job_type_plan.selected_checks
findings[]
pattern_summary
pattern_summary.command_data_usage
```

The static findings are compact and redacted. They can detect patterns such as:

- passwordless SQL users or roles,
- broad `GRANT ALL PRIVILEGES`, including `privileged_database_grant` when the target resembles an ERP/database-wide grant,
- `pg_hba`/`trust` authentication weakening references,
- firewall disable/open policy commands,
- file/data transfer commands,
- transfer after firewall weakening,
- Python subprocess/network/client capability markers,
- destructive root filesystem markers.

A normal maintenance command, such as `systemctl restart firewalld`, should not
be treated the same as a sequence that disables firewalling, opens database
authentication, grants broad ERP privileges, and then transfers data. The static
examiner can raise the floor to advisory delay, and it can label compound
exposure as a `pol_block_candidate`, but it does not itself hard-block. A hard
`pol_block` still requires the second-shot AI decision to land in a hostile
security-harm category with sufficient confidence.


## Candidate v5 acceptance matrix

The v5 candidate pack adds fixture coverage for the reviewer acceptance matrix:

1. normal firewall restart -> maintenance/allow pattern,
2. firewall disable -> `firewall_disable`,
3. firewall disable followed by transfer -> compound exposure evidence,
4. passwordless DB user or role -> `passwordless_db_login`,
5. `GRANT ALL` on an ERP database -> `privileged_database_grant`,
6. passwordless DB + broad grant + firewall disable -> `pol_block_candidate` evidence,
7. Python subprocess/socket/file-transfer patterns detected statically,
8. shell/SQL/Python-looking payloads are not executed during `examine`,
9. non-loopback model URLs are refused by default, and
10. hard block remains possible only after a high-confidence hostile/security-harm second-shot decision.

The examiner remains an evidence producer. The AI policy gate remains the
second-shot classifier. The policy engine remains the final enforcement boundary.

## Deterministic legal/case restriction hints

Bob21 v6 adds a local hint layer for legal/case restrictions. The examiner may
load hints from `QUEUEBASH_AI_POLICY_GATE_LEGAL_CASE_HINTS_FILE`, from
`QUEUEBASH_AI_POLICY_GATE_LEGAL_CASE_HINTS`, and from the built-in example hints
when enabled. The hint layer is deliberately limited:

```text
no database query
no SQL execution
no shell execution
no Python execution
no network lookup
bounded redacted samples plus hashes only
```

The emitted categories are:

```text
legal_case_restriction_hint
legal_case_database_entry_hint
```

These are evidence categories. They indicate that a job touches a locally known
legal/case restriction phrase, table, column, flag, or identifier. They can raise
the deterministic recommendation to `advise_delay` so the job waits for policy
review or tighter controls. They do not create a legal conclusion and do not
hard-block on their own.

A hard `pol_block` remains conservative. It requires the local second-shot model
to return a high-confidence binding policy category such as:

```text
legal_restriction_violation
case_restriction_violation
```

The deterministic examiner remains the evidence producer; the AI gate remains a
second-shot classifier; and the policy engine remains the final enforcement
boundary.

## Candidate v7 legal/case hint redaction hardening

Bob21 v7 keeps legal/case restriction hints in the deterministic examiner lane,
but tightens how matched hints are represented in the model-facing second-shot
bundle. A matched restricted phrase, case identifier, or database-entry hint is
applied as deterministic evidence while the raw configured hint value is redacted
from the request JSON. The AI receives local hint identifiers, hint kind/severity,
pattern hashes, and a `legal_case_hint_summary` object; it does not need the raw
restricted phrase or database-entry name to decide whether the job needs advisory
hold or policy escalation.

The intended flow is:

```text
deterministic local hint match -> redacted evidence finding -> second-shot review
```

This preserves the existing rule: hint matches can raise an otherwise-allow job
to `advise_delay`; hard `pol_block` still requires a high-confidence second-shot
policy-block category such as `legal_restriction_violation` or
`case_restriction_violation`.


## Candidate v8 job-id lookup and Gemini test provider

Candidate v8 keeps Ollama as the safe default provider and adds two operator/testing improvements:

- `examine` and `classify` accept `--job-id`, resolving job ids, job names, or unique id prefixes under priority buckets such as `pending/p0999999990/*.job`.
- Direct script references are inspected statically from `PWD_AT_SUBMIT` where safe, so a pending job like `bash badscript.sh` can produce findings from the script body without running the shell.
- Gemini is available only as an explicit test provider. Set `QUEUEBASH_AI_POLICY_GATE_PROVIDER=gemini` or `--provider gemini` plus `QUEUEBASH_AI_POLICY_GATE_ALLOW_EXTERNAL_PROVIDER=1` and a Gemini API key. Without that opt-in, the helper refuses before any external provider call.

Example Gemini test invocation:

```bash
QUEUEBASH_AI_POLICY_GATE_ENABLED=1 \
QUEUEBASH_AI_POLICY_GATE_PROVIDER=gemini \
QUEUEBASH_AI_POLICY_GATE_ALLOW_EXTERNAL_PROVIDER=1 \
QUEUEBASH_AI_MODEL=gemini-2.5-flash \
bin/queue-ai-policy-gate classify --job-id badjob
```

This is not the default no-leak posture. The default remains local Ollama only.

## Candidate v9 recommendation-only calibration

The second-shot provider may return a delay-shaped response while its own category and rationale say the job is routine work with hygiene recommendations only.  Bob21 treats those as `allow` with `recommended_tightening` preserved when all of the following are true:

- the category is a recommendation-only category such as `media_processing`;
- deterministic containment did not find compound exposure, legal/case restriction evidence, high/critical static risk, or an advisory recommendation;
- the category is not a risky delay category.

This keeps routine media/build/automation jobs from being delayed merely because the model can suggest better controls.  Security posture changes such as firewall-open commands still stay `advise_delay`, and high-confidence hostile/destructive categories still remain eligible for `pol_block`.

## Candidate v10 SQL argument-payload examination calibration

The deterministic containment examiner now reads multiple bounded local text
payloads referenced by a submitted command, not just the first wrapper script.
This is specifically to catch wrapper-and-payload jobs such as a Python migration
helper that reads and executes a `.sql` argument file. The examiner still does
not execute shell, Python, SQL, model output, or network activity.

Example evidence path:

```text
queue submit update_db -- bash python3 erp_db_sync.py "dbname=postgres user=admin" schema_update_v4.sql
```

The examiner should inspect both the Python wrapper and the SQL argument file
from `PWD_AT_SUBMIT` when they are local bounded text files. The wrapper can
produce evidence such as `database_command_execution` and
`external_payload_read`; the SQL payload can produce `passwordless_db_login`,
`grant_all_privileges`, and `privileged_database_grant`. A model response that
classifies only the wrapper as routine maintenance must not erase those static
payload findings; the policy normalizer may raise the result to advisory delay.

SQL comment text is ignored for syntax decisions. A comment saying "no
password" must not prevent the checker from recognizing `CREATE ROLE ... LOGIN`
without a `PASSWORD` or `IDENTIFIED BY` clause.

## Candidate v11 encoded payload and static taint hardening

The deterministic containment examiner remains static-only. It does not execute
shell, Python, SQL, model output, database calls, or network activity. Candidate
v11 adds bounded evidence for encoded argument payloads and simple sink-to-source
flow in Python wrappers:

- external file read evidence: `external_payload_read`
- base64 decode transform evidence: `payload_decode_transform`
- decoded payload scan evidence: `decoded_payload`
- decoded payload sent to database execute sink: `decoded_payload_to_database_execute`
- base64-like argument/file anomaly: `encoded_payload`

This is intended for wrapper jobs such as a Python ERP migration helper that
reads a local argument file, decodes it with `base64.b64decode`, and passes the
result to `cur.execute`. The examiner may decode bounded base64-looking text in
memory solely so existing SQL pattern checks can inspect the resulting text. It
never executes that decoded text.

A routine wrapper remains eligible for recommendations-only allow, but an encoded
SQL payload that creates passwordless database login and grants broad ERP/database
privileges raises the deterministic recommendation to `advise_delay`. Hard
`pol_block` still requires the second-shot classifier to return a high-confidence
hostile/security-harm or binding legal/case-restriction category accepted by the
policy boundary.

## Candidate v12 multi-hop shell/source expansion

Candidate v12 extends deterministic containment to common shell indirection
without turning the policy gate into a shell emulator. It performs bounded static
graph expansion only:

- local bash wrapper scripts can be inspected for nested `python3`, `bash`, or SQL
  client invocations;
- nested local Python/script/data arguments are read as bounded text from
  `PWD_AT_SUBMIT` where permitted;
- shell `source`/`.` includes are followed for local files;
- simple shell function definitions are extracted as static bash payloads;
- optional shell startup files such as `.bashrc` can be scanned for source/function
  indirection when `QUEUEBASH_AI_POLICY_GATE_SHELL_STARTUP_SCAN=1`.

Example wrapper path:

```text
queue submit update_db -- bash update_db.sh
update_db.sh -> python3 erp_db_sync.py ... schema_update_v4_base64.sql
erp_db_sync.py -> file read -> base64 decode -> cur.execute
schema_update_v4_base64.sql -> decoded SQL static scan
```

Example sourced-function path:

```text
.bashrc -> source badfile.sh
badfile.sh -> byebyebirdy() { ... risky commands ... }
queue submit later -- bash byebyebirdy
```

The examiner records evidence such as `shell_source_include`,
`shell_function_definition`, nested payload sources, decoded payload scans, and
any risky commands found in the statically read bodies. It still does not execute
shell startup files, shell functions, Python, SQL, decoded payloads, model output,
database calls, or network activity.

## Explain-visible write-back candidate

`queue-ai-policy-gate classify --apply --job-id JOB` may append redacted
`AI_POLICY_GATE_*` metadata to the job record. This allows `queue explain JOB`
to display the last applied policy-gate decision, compact deterministic evidence,
risk flags, advisory hold metadata, and local policy log path.

Advisory holds are monotonic. If a job already has a later `NOT_BEFORE_EPOCH`
than the advisory delay requested by the policy gate, the existing later value is
preserved and `AI_POLICY_GATE_DELAY_PRESERVED_EXISTING=1` is recorded. The policy
gate may add evidence and review metadata, but it must not shorten a pre-existing
hold.
