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

## Display resource manifest/catalog contract

Bob18 wave 3 adds a manifest/catalog layer for resource governance. The manifest is metadata only: it lists resource names, resource family, language/fallback availability, intended command or panel surface, allowed token names, and the security boundary that applies to the resource.

The catalog is deliberately not a renderer, not a policy engine, and not a command contract. It helps reviewers, installers, signing tools, and tests answer these questions before a resource is shipped:

- Is the resource presentation-only?
- Is there an English and fallback copy where required?
- Are the token names explicit and controlled?
- Does the resource forbid secrets and provider credentials?
- Does the resource remain separate from JSON output?
- Is the resource covered by signing/verification expectations?

Example TSV manifests live under:

```text
resources.d/display/manifest.example.tsv
resources.d/xml/manifest.example.tsv
```

Machine-readable schema examples live under:

```text
schemas/display_resource/resource_manifest.example.json
schemas/display_resource/resource_catalog.example.json
```

The manifest format is intentionally simple TSV so shell installers can inspect it without executing it. Fields are:

```text
resource_type<TAB>name<TAB>language<TAB>fallback_required<TAB>tokens<TAB>surface<TAB>json_contract_source<TAB>secret_rendering_allowed<TAB>notes
```

Rules:

- `resource_type` is `display` or `xml`.
- `language` is a concrete `lang_*` directory or `fallback`.
- `tokens` is a comma-separated allow-list, or `none`.
- `json_contract_source` must remain `false`.
- `secret_rendering_allowed` must remain `false`.
- manifests must not contain secret values, provider credentials, command substitutions, shell expansion, or executable snippets.

This manifest is review evidence. Runtime JSON output continues to come from command code and provider contracts, not display templates.


## Display resource lint helper

Bob18 wave 4 adds a reviewer/installer lint helper:

```sh
python3 bin/queue-display-resource-lint.py --root . --json
```

The helper is read-only. It checks display and XML manifest rows, confirms referenced resources exist, confirms fallback peers for fallback-required resources, verifies controlled `{{TOKEN}}` usage against the manifest token allow-list, rejects shell-looking expansion, rejects secret-looking placeholders or sample values, and emits a bounded JSON evidence object.

The helper is deliberately not a renderer and not a command implementation. It does not produce command JSON output, does not source or evaluate resource content, does not call providers, does not inspect secret stores, and does not mutate signing state. In signed deployments, signing and verification remain the responsibility of `queue code sign --all` and `queue code verify`; lint evidence is complementary reviewer evidence.

Expected JSON evidence uses:

```text
queuebash.display_resource_lint.v1
```

Lint results must remain redacted. They may include paths, token names, counts, and error messages; they must never include secret values or resource-rendered secrets.
