# bashqueues IPC

`bashqueues` IPC stays filesystem-native.

## Env-drop job outputs

Every running job receives `QUEUEBASH_JOB_ID`, `QUEUEBASH_OUTPUT_ENV`, `QUEUEBASH_ENV_OUT`, and `QUEUEBASH_STREAM_FIFO`.

Payloads can write structured outputs with:

```bash
queue_output RESULT_PATH /tmp/result.dat
queue_output CHECKSUM "$sha"
```

This writes shell-quoted exports to `outputs/<JOB_ID>.env`.

Downstream jobs inherit a producer env-drop with:

```bash
queue submit consumer --inherit-env-from <producer-qid> -- ./consumer.sh
```

QIDs are recommended because duplicate job names are valid.

## FIFO stream taps

When a job enters `running/`, queuebash creates `streams/<JOB_ID>.fifo`.

Use `queue stream <QID>` for a safe single live tap from the durable log into the FIFO. POSIX FIFOs are not broadcast buses; multiple readers compete for bytes.


## Name-based env inheritance

`--inherit-env-from` accepts a producer job name as well as a QID:

```bash
queue submit make_path -- bash -c 'queue_output RESULT_PATH /tmp/out.txt; echo hello > /tmp/out.txt'
queue submit read_path --inherit-env-from make_path -- bash -c 'cat "$RESULT_PATH"'
queue run
```

Using `--inherit-env-from make_path` automatically adds:

```bash
--after-success make_path
```

This means the consumer can be submitted before the producer has completed. At dispatch time, the worker resolves the completed producer name to the actual successful QID and sources:

```text
outputs/<producer-qid>.env
```

If multiple successful jobs share the same producer name, env inheritance is ambiguous and the worker asks for a QID. Use unique producer names for pipeline steps, or use the QID explicitly.


## queue_output helper command

`queue_output` is available to payloads as an external command, not only as a Bash function.

The worker creates:

```text
~/.queuebash/helpers/<QID>/bin/queue_output
```

and prepends that directory to `PATH`.

This matters for the systemd runner because `systemd-run` does not reliably preserve exported Bash functions. Payloads can therefore use:

```bash
queue_output RESULT_PATH /tmp/result.txt
```

inside:

```bash
bash -c 'queue_output RESULT_PATH /tmp/result.txt'
```

or inside a Bash script launched by the job.


## 0.8.4 name resolver fix

The env-drop name resolver now sources queue-generated job metadata rather than parsing it with `grep | xargs`.

This matters because job files may store:

```bash
INHERIT_ENV_FROM=( producer )
```

or:

```bash
INHERIT_ENV_FROM=producer
```

and both must resolve correctly at worker dispatch time.


## 0.8.5 submit-time binding

When possible, `--inherit-env-from <name>` is resolved to an exact QID at submit time.

Example:

```bash
queue submit producer -- ...
queue submit consumer --inherit-env-from producer -- ...
```

The consumer job file stores:

```bash
DEPENDS_AFTER_SUCCESS=<producer-qid>
INHERIT_ENV_FROM=<producer-qid>
```

This avoids ambiguity when older successful jobs have the same `JOB_NAME`.

Binding rules:

1. If `<name>` matches exactly one pending/running/paused job, bind to that QID.
2. Otherwise, if it matches exactly one done job, bind to that QID.
3. If multiple matches exist in either group, ask the user to use a QID.
4. If there is no match yet, keep the name for legacy late-binding behaviour.


## 0.8.6 systemd inherited env keys

When a consumer sources `outputs/<producer-qid>.env`, queuebash records the keys exported by that env-drop file:

```text
QUEUEBASH_INHERITED_ENV_KEYS="RESULT_PATH CHECKSUM"
```

For systemd jobs, those keys are explicitly passed to the transient unit:

```text
--setenv=RESULT_PATH=...
--setenv=CHECKSUM=...
```

This is required because `systemd-run` does not automatically receive variables created by sourcing the env-drop file in the worker shell.


## IPC file checksums

For file hand-offs, use `queue_output_file` instead of plain `queue_output`.

Producer:

```bash
queue submit producer -- bash -c '
  tmp=/tmp/result.txt.tmp
  final=/tmp/result.txt
  echo hello > "$tmp"
  mv "$tmp" "$final"
  queue_output_file RESULT_PATH "$final"
'
```

This writes:

```bash
export RESULT_PATH=/tmp/result.txt
export RESULT_PATH_SHA256=<sha256>
export RESULT_PATH_BYTES=<bytes>
export RESULT_PATH_MTIME=<mtime>
```

Consumer:

```bash
queue submit consumer --inherit-env-from producer -- bash -e -c '
  queue_require_file RESULT_PATH
  cat "$RESULT_PATH"
'
```

or:

```bash
queue_require_file RESULT_PATH || exit $?
```

`queue_require_file` is an external helper command. It returns non-zero on validation failure; it cannot forcibly exit a parent `bash -c` script unless the script uses `set -e`, `bash -e`, or `|| exit $?`.

It verifies file existence, byte count, SHA256, and mtime where available.


## Automatic pre-flight checksum validation

No consumer command-line flag is needed.

If a producer publishes a file using:

```bash
queue_output_file RESULT_PATH /tmp/result.txt
```

the env-drop contains:

```bash
RESULT_PATH
RESULT_PATH_SHA256
RESULT_PATH_BYTES
RESULT_PATH_MTIME
```

Any consumer that inherits that env-drop automatically validates the file before its payload is launched:

```bash
queue submit consumer --inherit-env-from producer -- bash -c 'cat "$RESULT_PATH"'
```

The worker runs the equivalent of:

```bash
queue_require_file RESULT_PATH
```

before launching the consumer payload.

If validation fails, the consumer is moved to `failed/`, and the payload is not executed.
