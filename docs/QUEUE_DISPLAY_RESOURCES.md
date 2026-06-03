# Queue display resources

Display resources are external, signed, non-executable presentation modules used for human-centric output.  They are deliberately separate from JSON contracts: JSON mode is generated from structured command data and must not depend on display resources or locale.

## Layout

Runtime resources are searched as:

1. `$QUEUEBASH_RESOURCE_DIR`
2. `$QUEUEBASH_ROOT/resources.d`
3. `/etc/bashqueues/resources.d`
4. bundled `resources.d` beside `queuebash.sh`
5. built-in emergency fallback

Display resources live under:

```text
resources.d/display/LANG/NAME
```

For example:

```text
resources.d/display/lang_eng/queue-version.txt
resources.d/display/lang_es/queue-version.txt
resources.d/display/fallback/queue-version.txt
```

## Trust and signing

External resources are covered by the existing bashq code/module signature system.  `queue code sign --all` and `queue code verify` include:

```text
resources.d/display/*/*
resources.d/xml/*/*
resources.d/schemas/*
```

When code signing is enforced, unsigned or untrusted resource files are rejected by the same `_queue_code_signature_check_file_for_execution` path used for executable modules and helpers.  The loader then continues down the fallback chain instead of rendering the rejected resource.

## Template safety

Resources are never sourced, eval'd, shell-expanded, or executed.  The only supported replacement form is controlled double-brace tokens:

```text
{{VERSION}}
{{QUEUEBASH_VERSION}}
```

Resource text containing shell-looking expansion forms is invalid and rejected:

```text
${...}
$(...)
`...`
```

Version strings remain stable ASCII identifiers.  Localised text may surround the version string, but the version itself is not converted to locale-specific numerals.

## Locale fallback

`queue resource-fetch-i18nl` performs fallback internally:

```text
requested locale -> parent language family -> lang_eng -> fallback -> built-in emergency fallback
```

The Catalan-family compatibility spelling requested during design is supported:

```text
lang_catilanian -> lang_es -> lang_eng -> fallback
```

## Commands

```sh
queue resource-fetch-i18nl --name queue-version.txt --lang lang_es --var VERSION=0.18.91
queue resource-fetch-i18nl --name queue-version.txt --lang lang_catilanian --var VERSION=0.18.91 --json
```

Development tools:

```sh
queue dev resource extract --name queue-version.txt --lang lang_es --output /tmp/queue-version.es.txt
queue dev resource insert --dir resources.d --name queue-version.txt --lang lang_es --input /tmp/queue-version.es.txt --json
queue dev resource validate --dir resources.d --json
```

After inserting or changing resources in a signed deployment, run:

```sh
queue code sign --all
queue code verify
```

## Bob18 display/XML contract extension

Bob18 owns the display-resource and internationalisation lane. This lane is additive and presentation-only: it may add resource layouts, token examples, XML display fixtures, and validation tests, but it must not refactor queue dispatch, provider authority, cloud/resource lifecycle, secrets delivery, or command JSON contracts.

Display resources use controlled `{{TOKEN}}` replacement only. They must not contain shell expansion, command substitution, executable snippets, secrets, credentials, scratchpad payloads, or provider-specific authority data. Missing or rejected resources must fail safely through the existing fallback chain.

JSON output remains locale-independent and structured. Human-facing resources may describe JSON fields, but they must never be the source of truth for JSON schemas or provider decisions.
