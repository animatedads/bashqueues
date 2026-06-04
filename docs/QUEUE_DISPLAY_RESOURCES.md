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

## Display resource catalog helper

Bob18 wave 5 adds a read-only catalog helper for reviewers, installers, and release packaging:

```sh
python3 bin/queue-display-resource-catalog.py --root . --json
```

The helper reads the display and XML manifest TSV files and emits redacted `queuebash.display_resource_catalog.v1` evidence. It groups resources by type/name, lists available languages, token allow-lists, fallback requirements, and declared human surfaces.

The catalog helper is deliberately not a renderer. It does not read resource body text, perform token replacement, source files, evaluate shell, call providers, inspect secret stores, alter signing state, or generate command JSON. It is metadata-only review evidence that can be compared with lint/signing evidence before a resource package is accepted.

Catalog JSON must keep these hard boundaries:

- `redacted=true`;
- `renderer=none-catalog-only`;
- `json_contract_source=false`;
- `secret_rendering_allowed=false`;
- no secret values, provider credentials, scratchpad payloads, or command output are included.

The catalog helper complements `bin/queue-display-resource-lint.py`: lint answers whether the resources pass safety checks, while catalog answers what presentation resources are present and which tokens/languages/surfaces they declare.

## Display resource coverage helper

Bob18 wave 6 adds a read-only coverage helper:

```sh
python3 bin/queue-display-resource-coverage.py --root . --json
```

The helper emits `queuebash.display_resource_coverage.v1` evidence from manifest metadata only. The example display manifest also records fallback entries for fallback-required resources so reviewers can distinguish incomplete manifests from advisory translation gaps. It reports the display/XML language directories present in the tree, the manifest languages declared for each resource, fallback availability, and advisory translation gaps. This helps reviewers and installers see which human-facing resources have English, fallback, and translated variants before a release is cut.

The helper is not a renderer and does not inspect secret stores, provider outputs, command JSON schemas, signing keys, or job state. It does not mutate manifests or signing state. Translation gaps are advisory unless a future policy explicitly promotes them to release gates; missing required fallback entries remain fail-closed lint/coverage findings.

## Display resource lookup explain helper

Bob18 wave 7 adds a read-only lookup explain helper:

```bash
python3 bin/queue-display-resource-lookup-explain.py --root . --type display --name queue-version.txt --language lang_eng --json
```

The helper emits `queuebash.display_resource_lookup_explain.v1` evidence from manifest metadata and resource file-presence checks only. It answers which localized resource, fallback resource, or missing state would be selected for a named display/XML resource.

The helper is deliberately not a renderer. It does not read resource body text for display, perform token replacement, source files, evaluate shell, call providers, inspect secret stores, mutate signing state, or generate command JSON. It is reviewer/install evidence for the lookup route only.

Required boundaries:

- `renderer=none-lookup-explain-only`;
- `source=manifest-metadata-and-file-presence-only`;
- display/XML resources remain presentation-only;
- JSON command/provider contracts remain generated by command/provider code, not templates;
- secrets are never rendered by display resources or lookup explanation.


## Display resource token audit helper

Bob18 wave 8 adds a read-only token audit helper:

```sh
python3 bin/queue-display-resource-token-audit.py --root . --json
```

The helper emits `queuebash.display_resource_token_audit.v1` evidence by comparing controlled `{{TOKEN}}` names used in display/XML resource bodies against the manifest allow-list. It reports declared tokens, used tokens, undeclared tokens, unused declarations, and secret-looking token names. It never substitutes token values and therefore never renders resource output.

The token audit helper is deliberately not a renderer, not a policy engine, not a signing mutator, and not a command JSON generator. It must not call providers, inspect secret stores, read job state, or treat display templates as authority. Its evidence is review metadata only and remains redacted.

## Display resource fallback audit helper

Bob18 wave 9 adds a read-only fallback audit helper:

```sh
python3 bin/queue-display-resource-fallback-audit.py --root . --json
```

The helper emits `queuebash.display_resource_fallback_audit.v1` evidence from display/XML manifest metadata and resource file-presence checks only. It verifies that resources marked `fallback_required=yes` have a matching `fallback` manifest row and an actual fallback resource file.

The fallback audit helper is deliberately not a renderer. It does not read resource bodies for display, perform token replacement, call providers, inspect secret stores, alter signing state, or generate command/provider JSON. It is release-review and installer evidence for the fallback safety net only.

Required boundaries:

- `renderer=none-fallback-audit-only`;
- `source=manifest-metadata-and-file-presence-only`;
- `secret_rendering_allowed=false`;
- `json_contract_source=false`;
- `token_value_substitution=false`.

Missing required fallback coverage is a fail-closed finding. Optional translation gaps remain the coverage helper's advisory domain unless a later policy promotes them to release gates.

## Display resource install audit helper

Bob18 wave 12 adds a read-only installed-resource audit helper:

```bash
python3 bin/queue-display-resource-install-audit.py --source-root . --installed-root /etc/bashqueues --json
```

The helper emits `queuebash.display_resource_install_audit.v1` evidence by comparing bundled/source display and XML manifest entries with an installed resource tree. It checks that installed manifests are present, that installed manifest hashes match the source manifests, and that every manifest-declared display/XML resource exists in the installed tree with the same SHA-256 hash as the source copy.

This helper is audit evidence only. It does not install files, update manifests, sign resources, render templates, substitute token values, call providers, inspect secret stores, or generate command/provider JSON. Signing and installation remain separate responsibilities; install audit simply tells reviewers whether the installed presentation resource files match the reviewed source set.

Required boundaries:

- `renderer=none-install-audit-only`;
- `source=manifest-metadata-and-file-hash-presence-only`;
- `installer=false`;
- `signing_mutation=false`;
- `json_contract_source=false`;
- `secret_rendering_allowed=false`;
- display/XML resources remain presentation-only after installation.
