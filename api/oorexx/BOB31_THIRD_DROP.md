# Bob31 ooRexx API third drop — corrected no-vendored-JSON package

The Architect correction accepted: **do not bundle `json.cls`**. Modern ooRexx has its own JSON class / site-provided JSON support, so this package now depends on the platform ooRexx JSON class being available on the normal `::requires` path.

## Contents

- `BashQueues.cls` — BashQueues ooRexx JSON-fronted API.
- `examples/bq_json_frontage_demo.rex` — basic JSON-fronted smoke/demo.
- `examples/bq_status_panel.rex` — lightweight TUI-inspired status view.
- `examples/bq_snapshot_export.rex` — JSON snapshot/export example using `q~raw(...)`.
- `docs/BOB31_ADDITIONAL_OOREXX_EXAMPLES_REVIEW.md` — review of TUI/serialization examples as reference material only.

## Important correction

No `json.cls` is shipped in this archive. `BashQueues.cls` still uses:

```rexx
::requires "json.cls"
```

That is intentional: the class should resolve from the ooRexx installation/site require path, not from a vendored copy in the bashq API package.

## Retained fixes

- Instantiate the JSON parser before calling `fromJson`.
- Export `QUEUEBASH_ALLOW_NONINTERACTIVE=1` before sourcing `queuebash.sh`.
- Use JSON frontage for queue commands that support `--json`.
- Keep the extra TUI/serializer examples as API usage inspiration, not dependencies.
