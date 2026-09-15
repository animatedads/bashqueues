# Bob31 ooRexx API merged into 0.18.136

Base verified in this sandbox:

```text
bashqueues_0.18.135_BOB32_full_release_no_rto.zip
sha256 617b7ec7b7db59d90b90cd5fb479701dd7ae20612590ce820069f8ea6921549c
```

This delivery carries Bob31's no-vendored-JSON ooRexx API onto the real 0.18.135 base and bumps the package to 0.18.136.

## Scope

Adds `api/oorexx/` as the first usable ooRexx API frontage:

- `BashQueues.cls`: JSON-fronted ooRexx wrapper around `queue`.
- `examples/bq_json_frontage_demo.rex`: stats/list/submit/explain/dev-functions smoke demo.
- `examples/bq_status_panel.rex`: small status panel inspired by the reviewed TUI examples.
- `examples/bq_snapshot_export.rex`: raw JSON snapshot/export helper.
- tests for connect, data wrapper, jobs, and namespace calls.
- docs for API usage and reviewed ooRexx example patterns.

## Important constraints

- No vendored JSON class. `::requires "json.cls"` resolves via the platform/site ooRexx require path.
- `QUEUEBASH_ALLOW_NONINTERACTIVE=1` and `NO_COLOR=1` are exported before sourcing `queuebash.sh`.
- JSON parsing instantiates the parser with `json = .json~new` before `json~fromJson(text)`.
- API examples are BashQueues-focused; Claude's alchemy/banking learning demos are not included.
- Full command-surface discovery is lazy by default; use `q~discover`, `q~surface`, or `BASHQUEUES_OOREXX_DISCOVER=1` when introspection is explicitly needed.
- `install-system.sh` now includes `api/` in the shared-tree copy list so the ooRexx API is installed beside docs, providers, schemas, and tests.

## Smoke test

```bash
cd api/oorexx
QUEUEBASH_SOURCE=../../queuebash.sh QUEUEBASH_ROOT=../../.queuebash rexx examples/bq_json_frontage_demo.rex
rexx examples/bq_status_panel.rex
rexx examples/bq_snapshot_export.rex /tmp/queue_snapshot.json
```

The packaging sandbox does not have `rexx` installed, so this lane includes static guards plus command JSON validation from bash.
