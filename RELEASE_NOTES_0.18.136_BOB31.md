# bashqueues 0.18.136 BOB31 ooRexx API JSON frontage

Base: `bashqueues_0.18.135_BOB32_full_release_no_rto.zip`

Verified base SHA256:

```text
617b7ec7b7db59d90b90cd5fb479701dd7ae20612590ce820069f8ea6921549c
```

This delivery adds Bob31's first packaged ooRexx API frontage without changing the queue core behaviour beyond the package version and installer coverage for `api/`.

## Added

- `api/oorexx/BashQueues.cls`
- `api/oorexx/docs/OOREXX_API.md`
- `api/oorexx/examples/bq_json_frontage_demo.rex`
- `api/oorexx/examples/bq_status_panel.rex`
- `api/oorexx/examples/bq_snapshot_export.rex`
- `api/oorexx/examples/cancel_blocked.rex`
- `api/oorexx/examples/list_by_state.rex`
- `api/oorexx/examples/submit_and_watch.rex`
- `api/oorexx/tests/test_connect.rex`
- `api/oorexx/tests/test_data.rex`
- `api/oorexx/tests/test_jobs.rex`
- `api/oorexx/tests/test_namespace.rex`
- `tests/oorexx_api_static.sh`

## Constraints preserved

- No vendored `json.cls`; the API uses the ooRexx/site JSON class from the normal `::requires` path.
- The wrapper exports `QUEUEBASH_ALLOW_NONINTERACTIVE=1` before sourcing `queuebash.sh`.
- JSON parsing instantiates `.json` before calling `fromJson`.
- Claude's alchemy/banking learning examples remain excluded from the packaged API.
- Full command-surface discovery is lazy by default; use `q~discover`, `q~surface`, or `BASHQUEUES_OOREXX_DISCOVER=1` when introspection is explicitly needed.

## Validation in this packaging sandbox

```text
sha256sum bashqueues_0.18.135_BOB32_full_release_no_rto.zip
bash -n queuebash.sh
bash -n install-system.sh
bash tests/oorexx_api_static.sh
python3 -m py_compile bin/*.py tests/*.py
queue version
queue stats --json | python3 -m json.tool
queue health --json | python3 -m json.tool
queue dev functions --json | python3 -m json.tool
```

`rexx` is not installed in the packaging sandbox, so ooRexx runtime execution remains for the target host.
