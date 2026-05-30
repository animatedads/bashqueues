# 0.18.73 BOB_MERGER13 QBTEST installer complete merge

Merges the Bob13 QBTEST add/extract command support and restored function-level QBTEST coverage onto the accepted 0.18.71 grid/energy cost platform line, then adds Claude's portable `qbtest_installer.sh` as the compatibility route for older/newer trees. The installer sources the target `queuebash.sh` and uses the target tree's own `queue dev test qbtest add` command, skipping existing blocks unless `--force` is supplied. Runtime provider, dispatch, provisioning, cloud, and live API posture remain unchanged.

# 0.18.72 BOB_MERGER13 QBTEST add/extract and missing Bob13 coverage merge

Merges the `queue dev test qbtest extract` and `queue dev test qbtest add` developer commands into the 0.18.71 platform line, then restores the missing Bob13 QBTEST wave9-wave11 function-level coverage as test-only embedded comment blocks. Runtime/provider/dispatch/provisioning behaviour is unchanged apart from the dev-tool command surface.

# 0.18.71 BOB_MERGER grid energy cost model contract merge

Folded Bob11 grid energy cost model branch payload onto the accepted 0.18.70 cloud cost/service-availability base. Adds a fixture-first Grid FinOps / electrical-cost model for energy-aware scheduling through the new `grid_energy` asset/provider, energy-aware classes, docs, policy examples, fixtures, and tests. No live grid API calls, credentials, OT/ICS writes, provisioning, destruction, or queue dispatch refactor are introduced by default.

# 0.18.70 BOB_MERGER cloud cost and service availability wiring merge

Merged Bob10 cloud cost/service-availability wiring onto the accepted 0.18.69 remote connection entry base. Adds fixture-first `queue cloud-signals` helper rails for OCI, AWS, Azure, GCP, and IBM Cloud local availability and cost policy evidence. Preserves no-live/no-credentials/no-billing-query/no-provisioning/no-dispatch-refactor boundaries.

# 0.18.69 BOB_MERGER remote connection entry command merge

Merged the remote connection entry command branch onto the accepted 0.18.68 remote-admin dual-control base. Adds `queue remote add SERVICE --url URL ...` to create local client-side `remote.d` entries and optional local secret files without mutating server ACL/client registry/listener policy. Preserves remote-admin transaction/dual-control work, provider parity reporting, embedded QBTEST coverage, and no shell/run/exec command exposure.

# 0.18.68 BOB_MERGER remote-admin dual-control ACL plan approval merge

Merged Bob10 remote-admin dual-control ACL plan approval branch payload onto the accepted 0.18.67 provider parity report base. Adds `queue remote-admin plan approve PLAN_FILE [--out FILE]`, `remote-admin.plan.approve`, distinct-approver dual-control for transaction plans that mutate `acl.tsv`, and apply-time dual-control validation before the existing per-operation ACL re-checks. Preserves `remote-admin.acl.write` as the crown-jewel ACL permission. Secrets remain excluded from plans; no generic editor, arbitrary shell, secret disclosure, queue dispatch refactor, or live remote mutation path is introduced.

# 0.18.67 BOB_MERGER provider parity report merge

Merged Bob2 provider parity report branch payload onto the accepted 0.18.66 Perplexity/QBTEST coverage base. Adds an offline provider-family parity report helper, policy fixture, documentation, and static/smoke/JSON contract tests while preserving embedded QBTEST coverage and existing ask/cloud/remote-admin provider surfaces.

# 0.18.66 BOB_MERGER Perplexity Sonar ask-provider merge

Merged Bob11 Perplexity Sonar ask-provider branch payload onto the accepted 0.18.65 QBTEST coverage base. Adds fixture-gated `queue ask --provider perplexity` helper, provider descriptor, docs, policy/examples, and offline tests while preserving embedded QBTEST coverage.

## 0.18.65 BOB_MERGER QBTEST wave3-wave8 function coverage

Merged Bob13 QBTEST wave3/wave5, wave6/wave7, and wave8 function-level embedded tests by extracting QBTEST blocks from patchset queuebash.sh files and reapplying them against the matching functions on the current merger head. Preserves remote-admin transaction plan/apply/rollback work and avoids stale whole-file queuebash overwrite.

# 0.18.62 BOB_MERGER remote-admin transaction plan/apply/rollback merge


Merges Bob10 remote-admin transaction plan/apply/rollback functionality onto the accepted 0.18.61 QBTEST wave1 base. Adds typed, ACL-gated `queue remote-admin` plan creation/show, plan apply, rollback list/show/apply, per-operation ACL re-check during apply, and local rollback snapshots. Secrets remain excluded from plans; no generic editor, arbitrary shell, secret disclosure, queue dispatch refactor, or live remote mutation path is introduced.

# 0.18.61 BOB_MERGER QBTEST wave1 embedded coverage merge

Merges Claude/Bob12 QBTEST wave1 embedded function tests onto the accepted 0.18.60 IBM/OCI cloud enablement base. Adds a substantial set of QBTEST:BEGIN/B64/END developer-only embedded tests to queuebash.sh for time/date helpers, parser helpers, JSON escaping, CSV matching, resource-size/duration conversion, and related low-level utility functions. No runtime command behaviour, cloud provider behaviour, dispatch, provisioning, or live API paths are changed.

# 0.18.60 BOB_MERGER IBM/OCI cloud enablement provider contracts

Merges the additive IBM cloud provider contract pack and OCI asset helper onto the accepted 0.18.59 patchset apply backup hardening base. Adds IBM provider docs, class criteria, explainability and legal/compliance notes, IBM policy examples, fixture-first IBM provider helper/tests, and an OCI asset helper. This remains contract/fixture-first: no live IBM or OCI API calls, no credentials required, no provisioning/destruction, and no queue dispatch refactor.

# 0.18.59 BOB12 patchset apply backup hardening

Hardens generated patchset application and `queue dev patchset apply`: help/check modes, isolated zip apply, pre-apply backup manifests, JSON reporting, and item-level scratchpad merge instead of blind `.queuebash/dev/scratchpad.json` overwrite.

# 0.18.58 BOB_MERGER remote-admin ACL-gated policy commands merge

Merges Bob10 remote-admin ACL-gated policy command contracts onto the 0.18.57 merger line. Adds `queue remote-admin` helper dispatch, docs, provider helpers, fixtures, and static/smoke/JSON tests for governed editing of remote queue management policy files. The command surface is ACL-gated and contract/test focused; no live remote mutation is enabled by default.

# 0.18.57 BOB_MERGER Cerebras, GPU templates, scratchpad required-fields, and dev validate/scope merge

Merges Bob11 Cerebras ask-provider support, Bob10 GPU cloud provisioning template parity, Bob2 scratchpad required-fields guard, and Bob12 queue dev validate/scope-check gates onto the accepted 0.18.56 Groq/status enum base. Patch tooling was used first; ledger/version overlaps were treated as expected, and runtime queuebash changes were reconciled across independent provider, cloud, and queue-dev lanes.

# 0.18.56 BOB_MERGER Groq provider and scratchpad status-enum guard merge
## 0.18.57 BOB11 Cerebras ask-provider pack

- Adds Cerebras OpenAI-compatible chat-completions ask provider.
- Keeps default tests fixture/gated: no live API key or network required.
- Preserves existing Bob11 ask providers and 0.18.56 Groq/status enum base.


Merges Bob11 Groq ask-provider support and Bob2 scratchpad status enum guard onto the accepted 0.18.56 QBTEST example/timeout-helper base. Patch tooling was used first; Groq queuebash integration was reconciled to preserve the accepted EXAMPLE_QBTEST help/example fix and timeout-helper work.

# 0.18.56 BOB12 QBTEST example escape and timeout helper

Escapes QBTEST examples in help/docs so documentation is never executed as an embedded test, adds a small bounded non-interactive `bin/queue-dev-timeout` helper for repeatable dev-test runs, and preserves the accepted 0.18.55 Bob Merger EU/APAC QBTEST DeepSeek base.

# 0.18.55 BOB_MERGER EU/APAC cloud helpers, QBTEST polish, and DeepSeek merge

Merges Bob10 EU/APAC cloud infrastructure helper parity, Bob12 QBTEST usability polish, and Bob11 DeepSeek ask-provider support onto the accepted 0.18.54 master. Patch script application was used first; Bob10 and Bob12 applied through the patch tooling, and Bob11 DeepSeek was manually reconciled only where the expected queuebash.sh/ledger version overlap occurred. Cloud helper work remains dry-run/status only; DeepSeek live use remains gated; QBTEST polish is developer-command only.

# 0.18.55 BOB10 EU/APAC cloud infrastructure helper parity

Adds dry-run/status lifecycle-helper rails for EU sovereign and APAC/China provider families that were already mapped as provider contract packs: OVHcloud, Scaleway, Hetzner Cloud, Open Telekom Cloud, Alibaba Cloud, Tencent Cloud, and Huawei Cloud. This remains fixture-first and non-mutating: no live provider API calls, no credentials required, no provisioning/destruction, and no queue dispatch refactor.

# 0.18.54 BOB_MERGER Mistral, scratchpad authority guard, and Azure/GCP parity merge

Merges Bob11's Mistral ask-provider pack, Bob2's scratchpad authority-shape guard, and Bob10's Azure/GCP first-tier platform parity work onto the accepted 0.18.53 QBTEST full-delivery master. Ledger/version overlaps are expected. Runtime changes are limited to adding the Mistral ask provider and version identity; Azure/GCP parity remains fixture-first and non-mutating, and scratchpad authority objects are normalized for safer dev workflow use.

## 0.18.52 BOB11 Mistral AI ask-provider pack

Adds a fixture-gated Mistral AI ask-provider through `bin/queue-ai-ask-mistral` and `providers.d/ask/mistral.sh`. Default tests require no credentials and perform no live network call; live use remains gated by `QUEUEBASH_AI_LIVE_ENABLED`.

## 0.18.52 BOB2 scratchpad authority shape guard

Adds a static guard ensuring every scratchpad item has an object-shaped authority with `type`, `name`, and `confidence`, and repairs historical malformed authority records during merge.

## 0.18.52 BOB10 Azure and GCP first-tier platform parity

Promotes Azure and GCP to first-tier contract coverage by adding explicit FinOps/cost and ITAR/export-control parity notes, cost/export policy examples, first-tier docs/tests, and platform-parity status updates. This remains fixture-first and non-mutating: no live Azure/GCP API calls, no credentials required by default, no provisioning/destruction, and no queue dispatch refactor.

# 0.18.53 BOB_MERGER QBTEST embedded function tests merge

Merges Bob12's `queue dev test qbtest` embedded function-test helper into the accepted 0.18.52 merger line. QBTEST scans base64 comment blocks near Bash or Python functions and runs decoded snippets with bounded execution. Ledger/version overlaps are expected; this delivery preserves the 0.18.52 dev context/think/handover merge, the 0.18.51 version-guard cleanup, and the repaired patchset inspect boundedness.

## 0.18.52 BOB_MERGER dev context think handover merge

Merges Bob12's lightweight `queue dev context`, `queue dev think`, and `queue dev handover` cockpit commands into the accepted 0.18.51 full-delivery line. The commands provide bounded working-set context, auditable planning notes, and reviewer-friendly handover summaries while preserving the version-guard cleanup and avoiding validation self-acceptance, dispatcher refactors, or live-provider expansion.

## 0.18.50 BOB12 dev context think handover

Implements the remaining lightweight dev workflow cockpit commands: `queue dev context`, `queue dev think`, and `queue dev handover`. Context and handover default to bounded working-set/delta output instead of dumping the whole scratchpad corpus; think records a safe auditable planning note in the scratchpad rather than private reasoning. This remains a patch-only follow-up from the accepted 0.18.48 base plus the 0.18.49 patchset hardening line. It does not wire validation self-acceptance, refactor queue dispatch, or add live providers.

## 0.18.51 BOB_MERGER version guard cleanup

Bumps the repaired full delivery line to 0.18.51 and removes stale exact QUEUEBASH_VERSION pins from legacy static tests. Tests should verify the version shape or feature/minimum compatibility, not crash merely because the accepted package version advanced.

## 0.18.50 BOB_MERGER repaired full delivery with OpenAI-compatible ask and cloud reconcile

Repairs the Bob Merger round2 full delivery by cleaning Python cache debris, bounding `queue dev patchset inspect --target` output for new/unbaselined files, and merging the Bob11 OpenAI-compatible local/private ask-provider pack plus Bob10 cloud resource reconcile enhancement. Version/ledger overlaps are expected merger noise; runtime is now `0.18.50` because accepted runtime/provider command surface was added.

## 0.18.50 BOB11 OpenAI-compatible local/private ask-provider pack

Adds a fixture-gated OpenAI-compatible local/private ask-provider for localhost or private `/v1/chat/completions` endpoints. Live use remains opt-in through `QUEUEBASH_AI_LIVE_ENABLED`; default tests require no endpoint, credentials, or network call.

## 0.18.50 BOB10 cloud resource reconcile enhancement

Adds local-registry-only cloud resource reconcile support with observation import, stale marking, suspect-claim reporting, and explicit no-cloud-mutation evidence. This is not provisioning and not scheduling.

## 0.18.51 BOB2 static version-pin policy guard

Adds a static guard ensuring provider-family tests use future-compatible version checks rather than stale exact `QUEUEBASH_VERSION` pins. This is a static-test policy guard only and does not bump runtime beyond the current runtime delivery.

## 0.18.49 BOB12 patchset file-registry hardening

Hardens the accepted dev file-registry and patchset workflow. `queue dev files scan` now reports per-file current MD5/size records and counts missing baseline MD5s explicitly. Patchset export now treats missing old MD5 as new/unbaselined changed state even when older registry entries forgot to mark `changed=true`, adds manifest summary/change-type/precondition metadata, and includes a `queue dev patchset inspect` command for reviewable outcome reporting before apply. This is a patch-only follow-up and does not add live providers or refactor the dispatcher.

## 0.18.49 BOB11 ask IBM watsonx.ai live-provider pack

Adds a Bob11 IBM watsonx.ai ask-provider pack. The provider is fixture/gated by default, requires no credentials or live API calls in default tests, supports file-backed IBM Cloud API key or bearer token lookup for live use, preserves OpenAI/Anthropic/Gemini/Ollama/fixture behaviour, and keeps Bob2/Bob10/Bob12 lanes untouched.

## 0.18.49 BOB10 cloud provisioning approval live gate contract

Adds a contract-only approval/live-gate layer for cloud provisioning. The new gates validate change-ticket/reason/authority/audit evidence, customer-data/data-protection review, export-control review, and cost approval before any future live provisioning can proceed. This package remains non-mutating: it performs no live cloud API calls, ignores provider credentials as authority, does not provision/destroy resources, does not write queue dispatch paths, and keeps registry handoff/local resource records separate from live apply.

## 0.18.48 BOB12 Bob10 handoff evidence merge repair

Repairs the 0.18.47 multistream merge by importing Bob10's dedicated controlled registry-handoff documentation, focused handoff static/smoke/JSON tests, and Bob10 validation/cleanup/manifest evidence files from the full Bob10 handoff package. Also updates stale provider static version pins for the current branch head. No new live cloud API calls, credentials, provisioning, destruction, or dispatcher refactors are introduced.

## 0.18.47 BOB12 multistream registry scan merge

Merges Bob2 primary-source validation, Bob10 registry handoff, Bob11 OpenAI/Anthropic ask-provider work, and Bob12 attempt/evidence linkage on top of the dev file registry line. Repairs the first real multistream patchset failure mode: missing baseline MD5 now means new or unbaselined changed file, never unchanged. Adds `queue dev files scan` to refresh current size/MD5/function metadata for tracked files without creating false baselines, and keeps newly added files included in patch-set exports.

# 0.18.44 BOB11 ask Anthropic live-provider pack

Adds Bob11's optional Anthropic ask-provider helper, descriptor, docs, policy examples, and fixture/gated smoke tests. Default tests perform no live Anthropic API call and require no credentials.

# 0.18.43 BOB11 ask OpenAI live-provider pack

Adds Bob11's optional OpenAI ask-provider helper, descriptor, docs, policy examples, and fixture/gated smoke tests. Default tests perform no live OpenAI API call and require no credentials.

# 0.18.46 BOB12 attempt evidence linkage

Adds `queue dev attempt begin/end` and `queue dev evidence record` so validation facts can be bound to named engineering attempts without granting automatic acceptance authority. Also tightens `queue dev files` scoped-function tracking so later changed/list views preserve the intentionally tracked function set, and fixes newly added files so patch-set export can include them as changed entries.

## 0.18.46 BOB2 primary-source validation + BOB12 patchset registry merged

Merges Bob12 dev file registry/patchset export tooling with Bob2 provider-family primary-source validation framework. The BOB12 command/tooling base is preserved: `queue dev files` records multistream file edit baselines and `queue dev patchset create` exports changed-file patchsets with checksum preconditions. The BOB2 provider-governance layer is carried forward additively: provider-family consistency, explainability standardization, primary-source validation policy, platform parity status, and tests. This merge does not add live provider API calls, credentials, provisioning/destruction, or queue dispatcher refactors beyond already accepted command surfaces.

# 0.18.45 BOB12 dev file registry patchset export

Adds a `queue dev files` registry for multistream development work and a guarded `queue dev patchset create` exporter. The registry records edit-session baselines, file locations, purposes, timestamps, sizes, file MD5 checksums, and function-level MD5 checksums. Patch-set export creates a minimal zip containing only changed files, unified diffs, a manifest, and review/apply scripts that enforce old file/function MD5 preconditions before merge. This package does not implement context/think/handover handlers and does not make validation self-author acceptance.

# 0.18.44 BOB12 scratchpad lifecycle commands

Implements the first staged dev-workflow command handlers for scratchpad lifecycle management. Adds `queue dev scratchpad status set` and `queue dev scratchpad supersede` as authority-gated, append-preserving lifecycle operations so stale or duplicate scratchpad items can be marked without deletion. Default scratchpad list/working-set views prefer active/current records while full export remains chronological and auditable. This release does not implement dev context/think/attempt/evidence/handover handlers, does not make validation self-author acceptance, and does not refactor queue dispatch.

# 0.18.43 BOB12 dev workflow command contracts

Adds a contract-first roadmap package for future `queue dev` workflow commands: context, think, attempt begin/end, evidence record, handover, scratchpad status set, and scratchpad supersede. This release is docs/schemas/static-tests only: it defines command semantics, authority rules, lifecycle transitions, attempt/evidence linkage, handover/delta behaviour, fail-closed boundaries, and JSON example payloads. It intentionally does not implement the commands, does not refactor the dispatcher, does not add dynamic queue-dev probes, and does not make validation automatically mutate scratchpad state.

# 0.18.42 BOB12 queue dev contract cleanup merged

Merges Bob12 queue dev contract cleanup onto the accepted 0.18.41 Bob2 hybrid/on-prem cloud lifecycle ask-provider base. The package formalises queue dev as a controlled internal development API for AI-assisted inspection, patching, testing, evidence, scratchpad, and remote-review workflows. It adds contract/security/workflow docs and bounded static/JSON contract tests. It keeps scope to docs/tests and stale-test repair; it does not add Grid FinOps, OT/ICS, live APIs, dispatcher refactors, or restored assets.d/net_usage.sh.

# 0.18.41 BOB2 hybrid/on-prem provider contracts merged with cloud lifecycle + ask provider

Merges Bob2 hybrid/on-prem provider-contract coverage into the accepted 0.18.40 Bob10 cloud provisioning lifecycle + ask provider base. The merge preserves Bob10's cloud_provision lifecycle-plan and registry-preview dry-run workflows, preserves Bob11 ask-provider contract/discovery, and adds Bob2 fixture-first VMware/vCloud, OpenStack, and OpenShift provider contracts. Hybrid/on-prem remains provider-family contract coverage only: no live provider API calls, no credentials, no provisioning/deployment/destruction, and no queue dispatch refactor.

# 0.18.40 BOB10 cloud provisioning lifecycle + ask provider merged

Merged current 0.18.39 edge cloud/cloud provisioning/ask-provider base with Bob10 cloud provisioning dry-run lifecycle.

- Preserves ask provider contract/discovery and fixture execution path.
- Preserves edge cloud provider contracts.
- Extends cloud_provision with lifecycle-plan and registry-preview dry-run commands.
- Keeps live cloud API calls, credentials, provisioning/destruction, registry writes, and queue dispatch refactor out of scope.

# 0.18.39 BOB10 edge cloud, cloud provisioning, and ask provider contract merged

Merged the accepted 0.18.38 edge cloud + cloud provisioning base with Bob11's repaired ask provider contract/discovery package. Ask provider discovery and the fixture execution path are present, fixture-first, non-live, and preserve Gemini/Ollama behaviour. Edge cloud remains fixture-first; cloud provisioning remains dry-run-only. No live provider API calls, credentials, provisioning/destruction, or queue dispatch refactor are introduced.

## 0.18.38 BOB10 edge cloud and cloud provisioning merged

Merges the accepted 0.18.37 Bob2 edge cloud provider contracts branch and the accepted 0.18.37 Bob10 cloud provisioning contract branch onto one current head. Edge cloud remains fixture-first provider-contract coverage for Cloudflare Workers, Fastly Compute@Edge, and Fly.io. Cloud provisioning remains Bob10's dry-run-only signed work-order layer beside `cloud_resource` and `cloud_infra`. The merge preserves the boundary: `cloud_provision` does not absorb edge provider logic, edge provider contracts do not imply live deployment/provisioning, and queue dispatch is not refactored.

## 0.18.37 edge cloud provider contracts

Adds Bob2 contract-first edge cloud provider coverage for Cloudflare Workers, Fastly Compute@Edge, and Fly.io. This is a fixture-first governance/provider-contract pack: docs, provider helper, policy examples, class templates, fixtures, explainability, legal/compliance posture, edge runtime/network/data-residency posture, and static/smoke/JSON tests. It makes no live provider API calls, requires no credentials, performs no provisioning/deployment/destruction, and does not refactor queuebash.sh dispatch. AWS remains first-tier for contract coverage; GCP, Azure, EU sovereign, APAC/China, GPU cloud, and edge cloud providers remain accepted fixture-first provider coverage; OCI and IBM remain high-standard references.

## 0.18.37 cloud provisioning contract

Adds Bob10 provider-neutral cloud provisioning contract as a controlled lifecycle work-order layer beside `cloud_resource` and `cloud_infra`. The package adds dry-run-only provisioning docs, security model, workflows, `providers.d/cloud_provision/cloud_provision.sh`, policy/template examples, plan examples for OCI/AWS/Azure/GCP/IBM, and static/JSON/dry-run smoke tests. It remains contract-first and non-mutating: no live cloud API calls, no provider credentials, no provisioning/destruction, no queue dispatcher refactor, and no ordinary dispatch path creates cloud servers.

## 0.18.36 GPU cloud provider contracts

Adds Bob2 contract-first GPU cloud provider coverage for CoreWeave, Lambda Cloud, and NVIDIA DGX Cloud. This is a fixture-first governance/provider-contract pack: docs, provider helper, policy examples, class templates, fixtures, explainability, legal/compliance posture, GPU capacity/accelerator posture, and static/smoke/JSON tests. It makes no live provider API calls, requires no credentials, performs no provisioning/destruction, and does not refactor queuebash.sh dispatch. AWS remains first-tier for contract coverage; GCP, Azure, EU sovereign, APAC/China, and GPU cloud providers remain accepted fixture-first provider coverage; OCI and IBM remain high-standard references.

## 0.18.35 remote management listener + APAC/China cloud provider contracts merge

Merges Bob11's repaired optional remote queue management listener onto Bob2's 0.18.35 APAC/China cloud provider coverage. The package preserves the 0.18.35 Azure/EU/APAC provider-contract sequence while adding the listener install option, loopback-first server-side remote management endpoint, HMAC client registry, fail-closed ACL policy files, audit logging, bounded read-only operation surface, and repaired denial paths for bad signatures and unknown clients. The unknown-client denial path is specifically hardened through an explicit close/bounded HTTP client path so a stranger knocking on the listener airlock returns JSON denial rather than hanging. The listener installer now dogfoods remote-listener installation as named queue jobs (`system-install-remote-listener-policy`, `system-install-remote-listener-service`, and `system-install-remote-listener-verify`) chained with `--after-success`; those jobs create `/etc/bashqueues/policies.d/remote-queue/`, copy `remote-management.env`, `acl.tsv`, and `clients.tsv`, install/enable the service, and verify the required files before post-install guidance is printed. The queue dispatcher dependency check now honours the same QID-or-exact-name contract accepted by `queue submit --after-success`, so one-shot named installer dependencies release correctly in the sandbox installer queue. It remains fixture-first for cloud providers: no live Azure/EU/APAC cloud API calls, no credentials required by default, no provisioning/destruction, and no queue dispatcher refactor.

## 0.18.35 APAC/China cloud provider contracts

Adds Bob2 contract-first APAC/China cloud provider coverage for Alibaba Cloud, Tencent Cloud, and Huawei Cloud. This is a fixture-first governance/provider-contract pack: docs, provider helper, policy examples, class templates, fixtures, explainability, legal/compliance posture, and static/smoke/JSON tests. It makes no live API calls, requires no credentials, performs no provisioning/destruction, and does not refactor queuebash.sh dispatch. AWS remains first-tier for contract coverage; GCP, Azure, and EU sovereign providers remain accepted fixture-first provider coverage; OCI and IBM remain high-standard references.

## 0.18.34 EU sovereign cloud provider contracts

Adds Bob2 contract-first EU sovereign cloud provider coverage for OVHcloud, Scaleway, Hetzner Cloud, and Open Telekom Cloud. This is a fixture-first governance/provider-contract pack: docs, provider helper, policy examples, class templates, fixtures, explainability, legal/compliance posture, and static/smoke/JSON tests. It makes no live API calls, requires no credentials, performs no provisioning/destruction, and does not refactor queuebash.sh dispatch. AWS remains first-tier for contract coverage; GCP and Azure remain accepted fixture-first provider coverage; OCI and IBM remain high-standard references.

## 0.18.33 Azure provider contract backfill

Adds Bob2 contract-first Microsoft Azure provider coverage as a backfill provider pack on top of the accepted 0.18.32 remote queue command + AWS/GCP parity base. Azure receives provider docs, class criteria, explainability, legal/compliance posture, fixture helper, policies, class templates, fixtures, and static/smoke/JSON tests. The package is fixture-first and non-mutating: no live Azure API calls, no credentials required by default, no provisioning or destruction, and no queue dispatcher refactor. AWS remains first-tier for contract coverage; GCP remains accepted fixture-first provider coverage; OCI and IBM remain high-standard references.

## 0.18.32 remote queue command + AWS/GCP provider parity merge

Merges Bob9 remote queue command plugin, Bob10 AWS first-tier cloud platform parity, and Bob2 GCP provider contract coverage. The remote command plugin remains a signed, read-only client-side system plugin (`queue remote <service> ...`) with no shell/run/exec/cmd path. AWS remains first-tier cloud platform/provider contract material. GCP is added as an accepted fixture-first provider contract pack with docs, provider helper, policies, classes, fixtures, explainability, legal/compliance notes, static/smoke/JSON tests, and no live GCP calls. The Bob9/Bob10/Bob2 boundary remains explicit: remote service exposes authorised queue/dev operations; cloud provider packs describe governance/resource/provider facts and do not become remote execution logic or cloud scheduling.

## 0.18.31 remote queue command plugin

Adds `queue remote <service> <command structure>` as the first client-side system plugin for the remote queue service line. The command loads named service configs from `remote.d`, signs read-only remote queue requests, supports `health`, `version`, `capabilities`, `queue status/list`, `job explain/tail`, `worker status`, and `service ps`, and keeps provider responses as data only. It does not expose a shell, does not add host-wide ps/kill, does not turn Bob9 remote service work into Bob10 cloud scheduling, and does not alter queue dispatch semantics beyond the new command entry point.

## 0.18.30 cloud resource provider contract

Adds Bob10 provider-neutral cloud resource registry contract: file-backed resources, lease-based claim/release/heartbeat/reconcile, cloud_resource asset preflight, platform parity matrix/gap tests, and Bob2 cloud_infra lifecycle helpers as an adjacent dry-run/gated layer. Keeps remote-service and cloud-resource scopes separate; no live cloud mutation, no provisioning, and no queue dispatch refactor. Includes reviewer scratchpad evidence from a live Gemini `queue ask` customer-data governance test, reinforcing that advisory strictness escalates for customer databases, cross-border deployment, and legal jurisdiction prompts.

## 0.18.28 remote queue service provider contract

Defines a provider-neutral remote queue service contract that extends the accepted 0.18.27 runner pattern into a future governed service boundary. The contract covers authenticated sessions, policy-gated named operations, queue/dev operation allowlists, scoped workspace file transfer, session-scoped ps/kill, bounded JSON results/log tails, audit events, and fail-closed behaviour.

This release is deliberately contract-only. It does not add live remote service execution, does not expose a generic shell, does not add `/run`, and does not change the accepted 0.18.27 dev runner implementation except documentation and contract tests.

## 0.18.27 merged platform package: exposed API auth key repair + OCI provider contracts

Merges the accepted OCI provider-contract overlay into the newer repaired remote-runner platform base. The OCI additions remain contract/helper/fixture/test oriented and are kept away from the queue dispatcher/core queue path. This merge preserves the exposed API authentication repair and process-control behaviour from the newer platform package while adding OCI provider contracts, OCI class criteria, explainability, legal/compliance notes, provider fixture helpers, policy examples, class examples, and OCI contract tests.

## 0.18.27 internal dev remote runner bridge

Adds `bin/queue-dev-runner.py`, a localhost-first, capability-scoped remote development runner for external build/test VMs. The bridge creates short-lived session workspaces, requires a server-console one-time bootstrap code followed by random session id plus auth code, bounds uploads/runtime/log tails, rejects path traversal and symlink escape, redacts obvious secret-bearing fields, and exposes only named development operations: upload, approved test, queue dev test, queue dev patch, queue dev splice, session-scoped ps, session-scoped kill, and session close.

The API is deliberately visible and narrow: `GET /healthz` works, `GET /session/create` is unavailable, `POST /session/create` consumes a bootstrap code printed in the server terminal, `/run` is absent, and all operational endpoints require session authentication. Direct JSON/form endpoints accept `session_id` and `auth_code` in the body as well as header auth, while multipart upload keeps header-only auth so the file stream is not consumed before parsing. Pressing Enter on the server mints a new one-use bootstrap code.

The repaired process-control contract adds a per-session process registry. `ps` lists only registered processes for the authenticated session. `kill` can terminate only a registered process id/process group belonging to that same session, and rejects host/global PIDs such as PID 1. API-submitted operations are visible on screen for the issuer of the token through server-console audit lines.

This release is deliberately dev-infrastructure-only. It is not a generic HTTP shell, does not expose arbitrary command execution, and does not alter queue dev test, queue dev scratchpad, OCI governance/provider contracts, governance provider behaviour, or job-resolution semantics.

## 0.18.26 Oracle Cloud Infrastructure governance provider contract

Adds a contract-first OCI governance/provider boundary for future Oracle Cloud Infrastructure integrations. This package documents normalized helper contracts, fail-closed provider behaviour, OCI policy/ACL/key/posture/audit evidence responsibilities, and an example provider environment file under `examples/providers/oci.env.example`.

This release is deliberately contract-only: it does not add live OCI CLI/SDK enforcement, does not install an OCI runtime asset, and does not claim that `queue oci` command functionality exists yet. Future packages may add runtime/provider implementations against this contract after primary-source validation and explicit scoping.

## 0.18.25 internal dev test runner class

Adds `queue dev test` as a queue-native development test runner on top of the accepted scratchpad list/delete/dedupe base. The command creates an isolated harness `QUEUEBASH_ROOT`, submits a real `DEV_TEST_RUNNER` job through normal `queue submit` in a clean subprocess, optionally runs a bounded worker pass with `--run`, and emits `queuebash.dev_test_result.v1` JSON. Scratchpad remains available for continuity but automatic test-result-to-scratchpad wiring is deliberately deferred.

## 0.18.24 internal dev scratchpad import contract

Adds `queue dev scratchpad` as a file-backed, authority-stamped engineering ledger for AI-assisted development. The first package is storage/state only: `init`, lightweight `import --from-tree`, `add`, `task`, `attempt`, `evidence`, `done`, `reject`, `fail`, `bump-fail`, compact `list`, soft-audit `delete ITEM_ID`, pruned `next --json`, full `export --json`, and human `explain ITEM_ID`. It deliberately does not integrate with `queue dev test`, render prompts, call AI providers, or refactor queue/job-resolution/splice semantics.

## 0.18.22 internal dev splice tool

This release adds `queue dev splice`, a constrained anchored text-splicing tool for internal refactor work. It supports dry-run/idempotency, JSON diagnostics, atomic writes, permission preservation, file-based anchors/inserts/replacements with trailing newlines preserved, and deliberately does not implement `_queue_resolve_job_operand` or refactor `queue()`.

## 0.18.20 internal refactor job resolution inventory

This release adds `docs/JOB_RESOLUTION_INVENTORY.md`, a no-behaviour-change map of every `queue()` command branch that resolves job operands through QID, QID-prefix, or exact job-name matching. It is preparatory documentation for a later job-resolution helper extraction and deliberately does not change dispatcher semantics.


## Effective class-statement policy

`queue policy list` may show multiple `class-statement` policy files from the shared policy tree, queue-local policy tree, or bundled defaults. The execution gate loads the discovered class-statement files as a merged effective policy, so an operator can keep emergency blocks or test policy statements in a separate file such as `policyblock-test.env` without replacing the default statement.

Useful diagnostic:

```bash
queue policy explain
```

This prints the class-statement files loaded and the effective merged values, including `CLASS_POLICY_BLOCK_CLASS_NAMES` and command-block settings.

## System install

For a shared root-managed installation, run:

```bash
sudo ./install-system.sh
```

Add cron bridge support with:

```bash
sudo ./install-system.sh --with-cron
```

The system installer uses an isolated temporary bashqueues queue to perform the privileged installation steps, installs shared policies under `/etc/bashqueues/policies.d`, and can generate/install root's authorisation signing public key into the shared class-statement policy. The generated `/usr/local/bin/queue` wrapper is explicitly non-interactive-safe, so scripts can call `queue ...` without first sourcing a shell profile. See `docs/SYSTEM_INSTALL.md`.

# bashqueues

Queues for Bash, because good job management means everything should use Queues.

`queuebash` is a native Bash task queue with filesystem-backed state, job priorities, parallel workers, dry-run safety, resubmission, hooks, PID tracking, process cancellation, log tailing, and JSONL event audit logs.

It is designed to be inspectable and recoverable using normal shell tools. The queue lives in `~/.queuebash` by default.


#
### Dynamic deadline asset

`assets.d/deadline.sh` adds `deadline:monitor` and `deadline:panic` assets. They compute deterministic slack from a drop-dead completion time and median historical runtime, then raise priority or apply only class-declared fallback asset exceptions when the point of no return is reached. See `docs/DEADLINE_ASSET.md`.

## Policy-blocked jobs

Jobs that are contrary to the active shared/admin class-policy statement at execution time and do not have a valid standing grant or command-bound authorisation move to `pol_blocked`. This is a terminal state, not a retryable failure. The worker performs this check before class claims, asset preflight, dynamic preflight, global claims, or payload launch.

Compact status for automation:

```bash
queue status QID
queue status QID --json --tail 40
```

`queue status` is intentionally shorter than `queue explain` and includes the QID, synthetic submission line, command line, state, class, PID data, timing, return code, job file, log path, and recent log tail.

After an admin issues a valid authorisation for the exact command, the command may be resubmitted with `--authorisation CODE`. The same command-bound code can be reused for unlimited resubmissions of that exact command until it expires.

See `docs/POLICY_BLOCKED.md`.

### Per-user class-policy standing grants

The shared class-policy statement can delegate narrow exception values to specific
queue users.  For example, a site policy in
### Root-aware policy editor

Root can edit the shared site policy directly:

```bash
sudo queue policies edit class-statement default
sudo queue policies path class-statement default
```

Normal users still edit queue-local policies by default. Use `--shared` or `--personal` when the target must be explicit.

A plain submit that inherits the default sandbox/seccomp settings is no longer treated as an explicit weak-policy request. Explicit selections such as `--sandbox off` still follow the active class-statement requirement.

`/etc/bashqueues/policies.d/class-statement/default.env` may contain:

```bash
CLASS_POLICY_USER_WEBADMINS_ALLOW_ADD_PORTS="80 1080 8080"
```

A `webadmins` queue user can then submit with `--add-port 80` without a
per-command authorisation, while another user such as `dba` still needs the
normal `--reason` or signed `--authorisation` path.

## Features

- Pure Bash, no daemon, no database.
- Filesystem state machine:
  - `pending`
  - `running`
  - `paused`
  - `done`
  - `failed`
  - `cancelled`
  - `deleted`
- Priorities: higher number runs first.
- Multi-worker execution.
- `--dryrun` for destructive or mutating actions.
- Exact job-name group operations.
- Success/failure hooks.
- Failed-job resubmission.
- Runtime `RUN_PID`, `RUN_PGID`, and `RUN_STARTED_AT` tracking.
- `queue cancel` / `queue kill`.
- `queue tail`.
- `queue stats`.
- JSONL event audit log at `~/.queuebash/events.jsonl`.
- Helper loop functions:
  - `overfiles`
  - `overdir`

## Full Disclosure: The `bashqueues` Origin Story

In the spirit of open-source transparency and Zero-Trust architecture, we believe in putting our cards on the table about how this system was built.

**The Blueprint:** `bashqueues` was architected by a human with decades of battle scars in software architecture, shell operations, and enterprise systems management. The human design set the physical laws of the system: distributed governance, strict policy boundaries, cryptographic approval paths, and the fail-closed philosophy.

**The Assembly Line:** With the architecture set, construction was carried out with an openly acknowledged AI-assisted software factory. Different AI systems were used for implementation, security review, integration checking, Microsoft-stack modelling, cloud-governance modelling, documentation, packaging, and adversarial critique.

That process is not hidden. It is part of the audit trail. The point was not to ask an AI to invent an operations model; the point was to use AI as a high-throughput assembly and review line under human architectural control.

**The Prime Directive:** Like all trustworthy enterprise packages, `bashqueues` does **not** use AI to make runtime decisions about job management.

There are no Large Language Models in the critical path. There are no stochastic guesses about when a job should run, where it should be routed, which class policy applies, or what system calls a profiled job is allowed to make.

At runtime, `bashqueues` is deterministic, inspectable, policy-verifiable, and designed to fail closed. Where configured, enforcement is delegated to ordinary Linux controls such as filesystem permissions, process ownership, systemd sandbox properties, seccomp syscall filters, capabilities, namespaces, and cryptographic signature verification.

AI helped build the code. Deterministic policy enforces the law.

See [docs/ORIGIN_STORY.md](docs/ORIGIN_STORY.md) for the longer form.

Enterprise provider contracts:

- [Trust providers](docs/TRUST_PROVIDERS.md)
- [Microsoft governance provider contract](docs/MS_GOVERNANCE_PROVIDER.md)
- [Oracle Cloud Infrastructure governance provider contract](docs/OCI_GOVERNANCE_PROVIDER.md)
- [Directory governance provider contracts](docs/DIRECTORY_GOVERNANCE_PROVIDERS.md)
- [AI advisory provider contract](docs/AI_ADVISORY_PROVIDER.md)
- [AI advisory audit logging](docs/AI_AUDIT_LOGGING.md)
- Local Ollama advisory provider: `queue ask --provider ollama --model llama3 --live` when `QUEUEBASH_AI_LIVE_ENABLED=1`




## SNMP asset and NMS notification helpers

`assets.d/snmp.sh` provides SNMP-backed preflight gates for infrastructure-specific readiness checks:

```bash
queue_class_shared_asset snmp int_below SAN_CPU max=85
queue_class_shared_asset snmp truth_ok MAINT_WINDOW
```

SNMP aliases are resolved from `/etc/bashqueues/snmp-map.env`, `/etc/bashqueues/snmp.d/default.env`, or queue-local/bundled `policies.d/snmp-map/default.env` files.  Direct `oid=...` parameters still work, but production classes should normally use stable aliases so OIDs can be corrected centrally.

The plugin uses Net-SNMP `snmpget -Oqv`, validates numeric SMI values before shell arithmetic, and fails closed if the tool, OID, value type, or network response is unsuitable.

`bin/queue_snmp_inform.sh` is a site-hook helper for sending typed SNMP INFORM notifications to an NMS from failure, policy-block, or incident hooks. See `docs/SNMP_INTEGRATION.md`.

## Process preflight assets

`assets.d/proc.sh` provides process-state gates for classes, including `proc:running`, `proc:not_running`, `proc:user_running`, `proc:pid_file`, `proc:max_instances`, `proc:cpu_user`, and `proc:mem_user`.

Example:

```bash
queue_class_shared_asset proc not_running "nightly_export.sh" match=substr
queue_class_shared_asset proc running "gpsd" match=exact
```

These checks are read-only and return `asset_check_blocked` rather than hard-failing the worker when the precondition is not met.

## Global shared resources

`queue_class_global_*` class records coordinate scarce resources across multiple user queue roots.

Examples:

```bash
queue_class_global_exclusive_claim "github:publish"
queue_class_global_shared_claim "gpu:cuda" slots=2
queue_class_global_shared_asset net allowance "wwan0" slots=1 allowance_bytes=10G direction=rx_tx
```

Global claims live under `${QUEUEBASH_GLOBAL_ROOT:-/var/lib/bashqueues/global}` and can be inspected with:

```bash
queue global root
queue global claims
queue global claim github:publish
queue global cleanup --dryrun
queue global health
```

The QueueManager includes a `Global Resources` panel. Existing non-global class records remain per-queue-root only. See `docs/GLOBAL_RESOURCES.md`.

## Install

Clone the repository, then source `queuebash.sh` from your shell startup file:

```bash
git clone https://github.com/animatedads/bashqueues.git
cd bashqueues
./install.sh
source ~/.bashrc
```

Manual install:

```bash
mkdir -p ~/.local/share/bashqueues
cp queuebash.sh ~/.local/share/bashqueues/queuebash.sh
printf '\n# bashqueues\nsource "$HOME/.local/share/bashqueues/queuebash.sh"\n' >> ~/.bashrc
source ~/.bashrc
```

## Runtime sandboxing

Jobs can request a runtime sandbox either directly or through class defaults:

```bash
queue submit safe_import --sandbox network-none -- bash import.sh

# in a class file
CLASS_DEFAULT_SANDBOX_LEVEL=strict
```

Supported levels:

- `network-none` — no external network namespace under systemd (`PrivateNetwork=yes`) or best-effort `unshare --net -r --` fallback for direct runner.
- `restrict-egress` — systemd IP address policy allows loopback/RFC1918 subnets and denies public egress.
- `strict` — disables networking and asks systemd for `ProtectSystem=strict`, `ProtectHome=read-only`, and `NoNewPrivileges=yes`.

This is designed to complement static `secaudit:*` asset checks. Static analysis can catch common mistakes; the runtime sandbox limits what a payload can do if static analysis misses an obfuscated action.

## Security audit asset

`assets.d/secaudit.sh` publishes `secaudit:script_safe`, `secaudit:string_safe`, `secaudit:no_destructive`, `secaudit:no_network_c2`, `secaudit:no_privesc`, and `secaudit:no_obfuscation`. Example:

```bash
queue_class_shared_asset secaudit script_safe "/opt/scripts/import.sh" strict=0
queue_class_shared_asset secaudit no_network_c2 "/opt/ingest/parse_payload.sh"
```

## Quick start

Submit a job:

```bash
queue submit hello -- echo "hello from queuebash"
```

List jobs:

```bash
queue list
queue ls
```

Run one worker:

```bash
queue run
```

Run four workers in the foreground:

```bash
queue run --workers 4
```

Detached workers:

```bash
queue start
queue start --workers 4
queue run --workers 4 --detach
queue workers
```

Dry-run the next queue run:

```bash
queue --dryrun run --workers 4
```

## Priorities

```bash
queue submit urgent --priority 100 -- ./important_job.sh
queue submit normal --priority 10 -- ./ordinary_job.sh
queue priority urgent 50
```

Exact job names are treated as groups where appropriate:

```bash
queue priority ingest_tblisi 100
queue pause ingest_tblisi
queue delete ingest_tblisi
```

Job-name prefix matching is deliberately not used for mutating commands.

## Hooks

```bash
queue submit download \
  --on-success echo complete \
  --on-failure echo failed \
  -- curl -O https://example.invalid/file.wav
```

Add or amend hooks after submission:

```bash
queue onsuccess download -- echo complete
queue onfailure download -- echo failed
queue hooks download
```

For shell syntax, use `bash -c`:

```bash
queue onsuccess myjob -- bash -c 'echo complete && date'
```

## Pause, unpause, delete, undelete

```bash
queue pause myjob
queue unpause myjob

queue delete myjob
queue undelete myjob

queue clear deleted
```

Deleted jobs are moved to `deleted` and can be restored. `clear deleted` permanently removes deleted job records.

## Cancel and kill

For running jobs:

```bash
queue pids myjob
queue --dryrun cancel myjob
queue cancel myjob
queue kill myjob
```

`cancel` defaults to `TERM`. `kill` defaults to `KILL`. Both move the job record to the `cancelled` state.

```bash
queue cancel myjob --signal INT
queue kill myjob --signal KILL
```


## Cancellation semantics

`queue cancel` and `queue kill` are operator actions. They move the job record into the `cancelled` state and append `CANCELLED_*` metadata, but they do **not** run `ON_FAILURE`.

The distinction is deliberate:

```text
command exits 0        -> done       -> ON_SUCCESS runs
command exits non-zero -> failed     -> ON_FAILURE runs
queue cancel           -> cancelled  -> ON_FAILURE does not run
queue kill             -> cancelled  -> ON_FAILURE does not run
```

This prevents dangerous surprises such as a killed job immediately resubmitting itself through an `ON_FAILURE` hook.

Cancellation is recorded in `events.jsonl` and in the job metadata:

```text
CANCELLED_AT=
CANCELLED_FROM=
CANCEL_SIGNAL=
```

If cancellation hooks are needed later, they should be added as a separate `ON_CANCEL` mechanism rather than overloading `ON_FAILURE`.


## Logs and events

Tail a job log:

```bash
queue tail myjob
```

Show recent JSONL audit events:

```bash
queue events --tail 20
```

Stats:

```bash
queue stats
queue stats --today
queue stats --name ingest_tblisi
```

The master event log is:

```text
~/.queuebash/events.jsonl
```

Example with `jq`:

```bash
jq 'select(.event=="failed")' ~/.queuebash/events.jsonl
```

## Failed job resubmission

Resubmission clones failed jobs into new `pending` jobs while retaining the failed original and log.

```bash
queue resubmit failer
queue retry failer
queue --dryrun resubmit failer
```

The cloned job records:

```text
RESUBMITTED_FROM=<old job id>
RESUBMITTED_AT=<timestamp>
```

## Queue manager

Interactive queue manager:

```bash
queuemgr
```

Useful commands inside `queuemgr`:

```text
r             run one worker
rd            dryrun one worker
r4            run four workers
rd4           dryrun four workers
s <id|name>   show job/log
t <id|name>   tail job log
pid <id|name> show PID/process tree
p <id|name> <priority>
pause <id|name>
unpd <id|name>
d <id|name>
dd <id|name>
rs <id|name>
rsd <id|name>
stat
ev
q
```

## `overfiles` and `overdir`

Run a command over matching files:

```bash
overfiles "../*.zip" unzip "{1}"
overfiles --dryrun "../*.zip" unzip "{1}"
```

Unzip each ZIP into its own directory:

```bash
overfiles "../*.zip" \
  bash -c 'mkdir -p "${1%.zip}" && unzip -o "$1" -d "${1%.zip}"' _ "{1}"
```

Run a command over directories:

```bash
overdir "~/Downloads/import/*" \
  python forensic_helper.py --ingest "{1}" --raw-amp-db 12 --enhanced-amp-db 12 --yaml tblisi.yaml
```

## Queue storage

Default queue root:

```text
~/.queuebash/
```

Override it:

```bash
export QUEUEBASH_ROOT=/var/tmp/myqueue
```

## Safety notes

`queuebash` is intended for user-level job management. It is deliberately simple and inspectable. It does not replace systemd, Slurm, Kubernetes, or a distributed queue.

For dangerous actions, use dry run first:

```bash
queue --dryrun delete myjob
queue --dryrun cancel myjob
queue --dryrun clear deleted
```

## License

GPL-3.0.


## Batch 2 / operational additions

### Version

```bash
queue version
```

### Automatic retries

```bash
queue submit fetch_payload --retries 3 --backoff 30 -- curl -O https://example.invalid/file.wav
```

Retries clone the failed attempt into a fresh pending job. The failed attempt remains in `failed` for audit.

### Resource limits with systemd-run

```bash
queue submit heavy --cpu 200 --mem 4G -- ./heavy_dsp_job.sh
```

When `systemd-run --user --pipe --wait --collect` is available, queuebash runs the payload inside a transient systemd scope with:

```text
CPUQuota=<cpu>%
MemoryMax=<mem>
```

If `systemd-run` is unavailable, the job runs normally and logs a warning.

### Queue manager completion

Inside `queuemgr`, press `TAB` to complete internal queue-manager commands and job IDs/names. This uses Bash readline and a temporary TAB binding while `queuemgr` is active.



## Detached workers

`queue run` is a foreground supervisor by default: it waits until its workers finish. For slow jobs, use detached mode:

```bash
queue start
queue start --workers 4
queue run --workers 4 --detach
```

Check recorded detached workers:

```bash
queue workers
```


## Final core conveniences

### Dynamic priority alias

`queue priority` remains the canonical command. `queue dynamic-prio` is provided as an operator-friendly alias:

```bash
queue dynamic-prio forensic_heavy 99
```

### Log safety cap

Submit with a maximum log size hint:

```bash
queue submit noisy --max-log-size 50M -- ./noisy-script.sh
```

The default is `QUEUEBASH_MAX_LOG_SIZE_BYTES` or 50MB.

### Execution summary

Completed job files append:

```text
EXEC_FINISHED_AT=
EXIT_CODE=
DURATION_SECONDS=
LOG_BYTES=
```

So `queue show <job>` gives a quick operational summary without parsing the text log.

### Watch mode

```bash
queue watch
queue watch --interval 2
```

Shows live stats, running jobs, and the top of the pending list.


## Resource limit verification

`--cpu` and `--mem` are enforced through `systemd-run --user --pipe --wait --collect` when available in the current login/session.

Check support:

```bash
queue limits
```

Example:

```bash
queue submit heavy --cpu 50 --mem 4G -- rexx waiter.rex
queue start
queue tail heavy
```

The job log should include:

```text
resource_limit_request: cpu=50 mem=4G status=systemd-run-user-service-pipe
limit_status: systemd-run-user-service-pipe
```

If the status is `requested-but-not-enforced-systemd-run-user-service-pipe-unavailable`, the limit was recorded but not enforced by the OS in that shell/session.


## Regression harness

Fast smoke test:

```bash
QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/selftest.sh
```

Full regression harness:

```bash
QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/regression.sh
```

The full regression checks stdout/stderr capture, zero and non-zero return paths, hooks, priority, dry-run, pause/unpause, delete/undelete, detached workers, cancel/kill, PID reporting, retry, resubmit, log capture, stats, events, tail, resource metadata, and watch mode.

Dedicated heavy log-volume stress test:

```bash
QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/stress_logstorm.sh 1000000
```

The ordinary regression uses a smaller logstorm by default. Override it with:

```bash
QB_REGRESSION_LINES=100000 QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/regression.sh
```


### Regression harness debugging

`tests/regression.sh` now prints diagnostics if a state transition stalls:

- full `queue list --state all`
- matching job files
- matching log tails

Hook tests use `tests/write_marker.sh` to avoid nested `bash -c` quoting ambiguity.


## Clearing cancelled jobs

At the command line:

```bash
queue --dryrun clear cancelled
queue clear cancelled
```

Inside `queuemgr`:

```text
cc    clear cancelled jobs
ccd   dryrun clear cancelled jobs
```


## Two-column queue manager help

`queuemgr` now renders its command summary in grouped two-column form to reduce screen space.

Inside `queuemgr`:

```text
help
?
```

prints the same compact summary.


## systemd-run wait/scope note

Resource-limited jobs use a transient user **service**:

```bash
systemd-run --user --pipe --wait --collect -p CPUQuota=50% -p MemoryMax=4G -- command ...
```

`--wait` is deliberately not combined with `--scope`, because systemd rejects that combination. Queue workers need `--wait` so they can collect the exit code and move the job to `done` or `failed` correctly.


## systemd resource-limit probe

Use this before trusting CPU/MEM enforcement on a machine:

```bash
queue limits --probe
queue limits --probe --cpu 50 --mem 4G
```

`queuebash` uses:

```bash
systemd-run --user --pipe --wait --collect -p CPUQuota=50% -p MemoryMax=4G -- command ...
```

`--pipe` is important: it returns the transient service stdout/stderr to the queue worker, so the normal job log still captures command output and systemd diagnostics.


## Health and interrupted recovery

`queue health` reports queue integrity and recovery issues:

```bash
queue health
queue health --fix
```

`queue health --fix` is intentionally non-interactive but loud. It prints everything it repairs, including stale `running` jobs whose recorded `RUN_PID` is no longer alive.

Safe repairs include:

- creating missing state directories
- removing dead detached worker PID files
- moving stale `running` jobs to `interrupted`
- appending `INTERRUPTED_*` metadata

`interrupted` means the worker/session died or disappeared while the job was marked running. It is distinct from `failed`, because no program exit code was observed.

Resubmission accepts both failed and interrupted jobs:

```bash
queue resubmit myjob
queue retry myjob
```

Inside `queuemgr`:

```text
h     health
hf    health --fix
```


## Three-column queue manager help

`queuemgr` now uses a compact three-column grouped command summary for standard full-screen terminals.

Additional clear shortcut:

```text
ci    clear interrupted
cid   dryrun clear interrupted
```

## Dynamic list column widths

`queue list` calculates column widths from the actual displayed rows, so long QIDs align under `JOB_ID` correctly.


## systemd working directory

Resource-limited jobs use the original submit directory when launching through `systemd-run`:

```bash
--working-directory="$PWD_AT_SUBMIT"
```

This preserves normal relative-command behaviour:

```bash
queue submit heavy --cpu 50 --mem 4G -- rexx waiter.rex
```

The transient service now resolves `waiter.rex` from the directory where the job was submitted.


## Runner policy

Queuebash now supports a runner policy:

```bash
export QUEUEBASH_RUNNER=auto
```

Allowed values:

```text
auto     prefer systemd-run when available, otherwise direct
systemd  require systemd-run support
direct   use the direct/setsid runner
```

Per job:

```bash
queue submit heavy --runner systemd --cpu 50 --mem 4G -- rexx waiter.rex
queue submit tiny --runner direct -- echo hello
```

When systemd is used, queuebash records:

```text
RUNNER=auto|systemd|direct
RUNNER_USED=systemd|direct
SYSTEMD_UNIT=<unit name when observed>
```

Inspect cgroup/unit information:

```bash
queue metrics <job>
queue unit <job>
```


## Automatic gzip log compression

Completed job logs are compressed by default:

```bash
export QUEUEBASH_GZIP_LOGS=1
```

Disable compression:

```bash
export QUEUEBASH_GZIP_LOGS=0
```

While a job is running, the log remains plain:

```text
~/.queuebash/logs/<QID>.log
```

After completion, it becomes:

```text
~/.queuebash/logs/<QID>.log.gz
```

`queue show` and `queue tail` read both `.log` and `.log.gz` automatically.

`queue show` now tails logs by default:

```bash
queue show myjob
queue show myjob --tail 500
queue show myjob --full
```


## Compress existing completed logs

Automatic gzip runs after completed job logs are closed. To compress existing completed logs manually:

```bash
queue compress-logs
```

Alias:

```bash
queue gzip-logs
```


## Completion for log compression

The shell completion includes:

```bash
queue compress-logs
queue gzip-logs
```

Inside `queuemgr`:

```text
gz    compress completed logs
```


## Live log watchdog

Queuebash protects ordinary jobs from runaway stdout/stderr.

Default cap:

```bash
QUEUEBASH_MAX_LOG_SIZE_BYTES=52428800
```

Override per job:

```bash
queue submit noisy --max-log-size 2G -- ./thing
```

Explicitly allow huge logs:

```bash
queue submit noisy --allow-large-log -- ./thing
```

If a running job exceeds the cap, queuebash records:

```text
LOG_OVERFLOW=1
LOG_OVERFLOW_AT=
LOG_OVERFLOW_BYTES=
LOG_OVERFLOW_CAP=
```

and terminates the process or transient systemd unit.


## Runner/operator documentation

See:

```text
docs/RUNNERS.md
```

for the current execution model:

```text
direct runner  -> setsid + RUN_PGID
systemd runner -> transient service + SYSTEMD_UNIT + cgroup
```

Operator summary command:

```bash
queue explain <job>
```


## Systemd MainPID handling

For systemd-run jobs, `RUN_PID` may be the `systemd-run` launcher process rather than the long-running payload.

For active systemd jobs, queuebash now treats the transient unit as authoritative:

```text
SYSTEMD_UNIT
systemctl --user show <unit> -p MainPID
```

`queue pids`, `queue health`, `queue cancel`, `queue kill`, and the log watchdog prefer the active systemd unit/MainPID where available, then fall back to `RUN_PGID` / `RUN_PID`.


## Explain exact-name batches

`queue explain <name>` explains every job with that exact name, matching `queue show` behaviour. Use a QID when you want one specific record.

For pending jobs, `queue explain` reports:

```text
planned: <runner>
used: not-started
```

and explains that cancellation only moves the job record because no process exists yet.


## Dependencies

Queuebash supports simple success dependencies:

```bash
queue submit next_step --after-success previous_step -- ./next.sh
```

Aliases:

```bash
--after
--depends-on
```

Inspect:

```bash
queue deps <job>
queue waiting
```

See:

```text
docs/DEPENDENCIES.md
```


## After-success test script

Dedicated dependency test:

```bash
QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/after_success.sh
```

The test forces:

```bash
QUEUEBASH_RUNNER=direct
```

because it validates dependency scheduling, not user-systemd execution.


## Self-dependency validation

Dependency jobs cannot depend on themselves by exact job name:

```bash
queue submit self_dep --after-success self_dep -- echo loop
```

returns:

```text
queue submit: job cannot depend on itself: self_dep
```


## Retry dependency touch test

Dedicated integration test for retry + on-retry-failure + dependency release:

```bash
QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/retry_dependency_touch.sh
```

`--on-failure` remains the final-failure hook. Use `--on-retry-failure` when a hook should repair the environment before the retry attempt.


Note: the retry-remediation hook is recorded in the failed first attempt log, while the final producer success is recorded in the retry job log. `tests/retry_dependency_touch.sh` checks the whole producer attempt chain.


## One-shot scheduling

Submit a job to become eligible after a delay:

```bash
queue submit-in 10m publish_later -- bash publish_to_github.sh
```

Submit a job to become eligible at a specific time:

```bash
queue submit-at 23:30 night_job -- ./nightly.sh
```

Inspect scheduled pending jobs:

```bash
queue scheduled
queue explain <job>
```

See:

```text
docs/SCHEDULING.md
```


## Scheduling completion

Shell completion includes:

```bash
queue submit-in
queue submit-at
queue in
queue at
queue scheduled
queue schedule
```


## Clean log files

Preview removable completed/orphan logs:

```bash
queue clean-logs --dryrun
```

Delete matching logs:

```bash
queue clean-logs --older-than 30d --force
```

Examples:

```bash
queue clean-logs --state done --older-than 7d --force
queue clean-logs --state failed --older-than 14d --force
queue clean-logs --orphan --force
queue clean-logs --all --older-than 90d --force
```

Safe defaults:

```text
without --force, clean-logs previews only
running logs are never deleted unless --include-running is used
without --all/--state, only completed/dead/orphan states are eligible
```


## Log cleanup audit fields

When `queue clean-logs --force` removes a log belonging to a known job, the job record is appended with:

```bash
LOG_CLEANED=1
LOG_CLEANED_AT=...
LOG_CLEANED_PATH=...
LOG_CLEANED_BYTES=...
```

A `log_cleaned` event is also appended to `events.jsonl`.


## Dependency edge-case tests

Run:

```bash
QUEUEBASH_ALLOW_NONINTERACTIVE=1 tests/dependency_edge_cases.sh
```

This covers:

```text
retroactive satisfaction
failed parent blocking
duplicate-name dependency semantics
strict QID dependency semantics
circular safe-pending behaviour
fan-in dependencies
```

This is a diagnostic edge-case test, not part of the fast regression suite, because it deliberately creates blocked/cyclic pending jobs.

See:

```text
docs/DEPENDENCY_EDGE_CASES.md
```


## Health and integrity

Run:

```bash
queue health
queue health --fix
queue health --deep
```

`queue health` checks queue directories, writability, events logging, free disk/inodes, helper commands, malformed job files, stale running jobs, and dependency status.

`queue health --fix` only performs safe repairs:

```text
create missing directories
remove dead worker pid files
move definitely stale running jobs to interrupted/
```

See:

```text
docs/HEALTH.md
```


## Restore diagnostics

`queue restore` / `queue undelete` only restores jobs from `deleted/`.

If no deleted job matches, queuebash now searches the other state directories and reports where matching jobs actually are:

```text
queue undelete: no matching deleted job: publish_to_git
but matching job(s) exist outside deleted/:
  2026... done publish_to_git
```

Use:

```bash
queue list --state deleted --name publish_to_git
```

to confirm whether a job is currently restorable.


## stderr-only overflow policy

The default log overflow policy protects noisy jobs without breaking their stdout pipe:

```text
before first cap: log stdout + stderr
after first cap:  suppress stdout, continue stderr
after second cap: suppress stderr too
always:           drain streams so the child keeps running
```

Per job:

```bash
queue submit noisy --max-log-size 50M --log-overflow stderr-only -- ./noisy.sh
queue submit strict --max-log-size 50M --log-overflow kill -- ./noisy.sh
```


## systemd runner process model

For `RUNNER_USED=systemd`, `RUN_PID` is the `systemd-run` client process, not necessarily the payload PID.

`queue cancel`, `queue kill`, `queue health`, and `queue explain` now prefer `SYSTEMD_UNIT` for process accounting and termination.

See:

```text
docs/SYSTEMD_PROCESS_MODEL.md
```


## Systemd cancellation no longer falls back to PGID

For `RUNNER_USED=systemd`, `queue cancel` and `queue kill` now target the transient unit with:

```bash
systemctl --user kill --kill-whom=all --signal=<SIG> <SYSTEMD_UNIT>
```

They do not fallback to `RUN_PGID` when the unit was targeted, because `RUN_PGID` may be the queue worker process group.

Stream temp files/FIFOs are cleaned up on completion, cancellation, and health repair.


## Cancellation race handling

If an operator cancels/kills a running job while a worker is still waiting for the payload runner to return, the worker now reports:

```text
[worker N] cancelled <QID> (operator cancellation observed; payload rc=...)
```

rather than reporting the job as failed. This keeps `cancelled` and `failed` audit meanings separate.


## Log drain synchronization

Queuebash waits for stdout/stderr drainers to finish before appending the queue footer. This prevents payload output appearing after:

```text
finished:
exit_code:
```

and prevents logger-side pipe closure from causing SIGPIPE failures in short jobs.


## Tail defaults

`queue tail <job>` now shows the last 40 lines before following a running log.

```bash
queue tail longrexx --tail 10
queue tail longrexx --no-follow
queue tail longrexx --from-start
```

Set the default with:

```bash
export QUEUEBASH_TAIL_LINES=80
```

See `docs/TAIL.md`.


## Targeted log compression

Workers now compress only the log for the job they just completed. They no longer scan all completed jobs after every job.

Manual bulk compression remains available:

```bash
queue compress-logs
```

See `docs/TARGETED_COMPRESSION.md`.


## Filesystem-native IPC

`bashqueues` supports lightweight IPC:

```bash
queue_output KEY VALUE
queue submit consumer --inherit-env-from <producer-qid> -- ./consumer.sh
queue stream <running-job>
```

IPC files live under `outputs/` and `streams/`. See `docs/IPC.md`.


## Name-based IPC inheritance

`--inherit-env-from` now accepts a job name and automatically creates the after-success dependency:

```bash
queue submit producer -- bash -c 'queue_output RESULT_PATH /tmp/out.txt; echo hello > /tmp/out.txt'
queue submit consumer --inherit-env-from producer -- bash -c 'cat "$RESULT_PATH"'
queue run
```

The consumer waits for `producer` to finish successfully, then sources `outputs/<producer-qid>.env`.


## Queue classes

Queue classes provide cooperative concurrency/resource gating:

```bash
queue class init FORENSIC_DSP
queue submit enhance --class FORENSIC_DSP -- ./enhance.sh
```

Class files define sequential class execution, maximum class concurrency, shared assets, and exclusive assets.

See `docs/CLASSES.md`.


## queue_output helper command

`queue_output KEY VALUE` is installed as a per-job helper command and added to `PATH`. This keeps env-drop IPC working under both direct and systemd runners, even when `systemd-run` strips exported Bash functions.


## IPC file checksums

For auditable file hand-offs:

```bash
queue_output_file RESULT_PATH /tmp/result.txt
queue_require_file RESULT_PATH
```

Use `bash -e` or `queue_require_file RESULT_PATH || exit $?` in consumers so validation failure stops the payload.

See `docs/IPC.md`.


## Automatic pre-flight checksum validation

Consumers do not need an extra `--require-file` flag. If a producer uses:

```bash
queue_output_file RESULT_PATH /tmp/result.txt
```

then any consumer using:

```bash
queue submit consumer --inherit-env-from producer -- ./consume.sh
```

automatically validates `RESULT_PATH` before the payload starts.


## Default class and class preflight plugins

Every submitted job records a class. Jobs without `--class` use `JOB_CLASS=DEFAULT`.

Class files can call machine-specific readiness checks:

```bash
CLASS_PREFLIGHT_PLUGINS="vpn.sh"
CLASS_PREFLIGHT_FUNC="check_vpn_ready"
```

Plugins live under `~/.queuebash/class.d/`. If preflight fails, the job stays in `pending/` rather than moving to `failed/`.


## Published asset facilities

Asset plugins publish the checks they provide:

```bash
queue assets
queue assets show path
```

A nested asset such as:

```bash
CLASS_EXCLUSIVE_ASSETS="path:freespace:/mnt/audio:min_gb=100"
```

maps to `~/.queuebash/assets.d/path.sh`, published facility `path:freespace`, and function `queue_asset_check_path_freespace`.


## Asset helper contract validation

Validate asset plugins with:

```bash
queue assets validate
queue assets show path
```

For every published `family:check`, the helper must define `queue_asset_check_family_check`.


## Asset plugins are separate files

Asset checks are not embedded in `queuebash.sh`. The core loads helpers from:

```text
~/.queuebash/assets.d/
```

The bundled standard path helper is shipped as:

```text
assets.d/path.sh
```

and is copied into the queue root only when missing, so site-specific edits are preserved.


## Standard network/system asset plugins

Bundled external plugins now include:

```text
assets.d/net.sh
assets.d/snmp.sh
assets.d/sys.sh
```

List them with:

```bash
queue assets
queue assets show net
queue assets show sys
queue assets validate
```


## Replace and rollback asset plugins

Install an updated plugin safely:

```bash
queue assets replace net ./net.sh
```

Rollback the last replacement:

```bash
queue assets rollback net
```

List backups:

```bash
queue assets backups
queue assets backups net
```


## Refresh, delete, and explain asset plugins

```bash
queue assets refresh ./assets.d
queue assets delete net
queue assets undelete net
queue assets explain net:tcp_endpoint
```


## Git and database asset plugins

Bundled external plugins include:

```text
assets.d/git.sh
assets.d/db.sh
```

Examples:

```bash
CLASS_SHARED_ASSETS="git:branch:/home/hc3/bashqueues:require_branch=main"
CLASS_SHARED_ASSETS="db:sqlite_accessible:/tmp/test.db:query=SELECT 1"
```

Inspect asset subcommands and families:

```bash
queue assets expand
```


## GitHub publishing class

```bash
queue submit publish_to_git --class GITHUB_PUBLISH -- bash publish_to_github.sh
queue classes show GITHUB_PUBLISH
queue classes edit GITHUB_PUBLISH
queue classes explain GITHUB_PUBLISH
```


## Format validation assets

```bash
CLASS_SHARED_ASSETS="format:json:/tmp/payload.json"
CLASS_SHARED_ASSETS="format:csv:/tmp/data.csv:strict_columns=1"
CLASS_SHARED_ASSETS="format:archive:/tmp/download.tar.gz"
CLASS_SHARED_ASSETS="format:sqlite:/tmp/state.db"
```

Colon-bearing targets are supported:

```bash
CLASS_SHARED_ASSETS="net:http_status:https://github.com:timeout=5"
CLASS_SHARED_ASSETS="net:tcp_endpoint:db.internal:5432:timeout=3"
```


## Delimiter-safe class asset records

Preferred class syntax:

```bash
queue_class_shared_asset net http_status "https://github.com" \
  timeout=5 \
  accept_status="200,201,204,301,302,304,307,308,403"

queue_class_shared_asset net tcp_endpoint "db.internal:5432" timeout=3
```

This avoids delimiter bugs entirely because `:`, `,`, and `=` are preserved inside real Bash arguments.


## Record-only class assets

Class assets are record-only:

```bash
queue_class_shared_asset net http_status "https://github.com" timeout=5
queue_class_shared_asset git branch "/home/hc3/bashqueues" require_branch=main
queue_class_exclusive_claim "github_publish:slot"
```

Legacy `CLASS_SHARED_ASSETS`, `CLASS_EXCLUSIVE_ASSETS`, and `CLASS_ASSETS` are intentionally unsupported during development.


## Dispatch decision in explain

For pending jobs, `queue explain <job>` reports why the worker is not running the job yet:

```text
Dispatch decision
  dependencies
  schedule/not-before state
  class file
  class/resource gate status
  plugin/preflight output
```

This is the first diagnostic command to run when a job is pending but not moving.


## Dispatch trace

If `queue explain <job>` says a pending job is runnable but `queue run` does not print `[worker N] running ...`, enable dispatch tracing:

```bash
QUEUEBASH_TRACE_DISPATCH=1 queue run
queue dispatch-trace
```

The trace records worker entry, `_queue_next_job` entry, candidate selection, and run transition points.


## Candidate-level dispatch trace

`QUEUEBASH_TRACE_DISPATCH=1 queue run` now records each pending candidate and why it was skipped or selected:

```text
candidate <job>
skip <job> dependencies-not-satisfied
skip <job> class-or-resource-blocked
selected <job>
move pending->running ok <job>
claim acquire ok <job>
about to run <job>
```


## Next-job stdout purity

`_queue_next_job` has a strict contract: stdout is either one selected pending job path or empty.

Asset and class plugin output is captured and written to dispatch trace as:

```text
class output <qid>: asset_check_ok: ...
```

This prevents plugin messages from contaminating the path passed to `mv pending -> running`.


## QueueManager split

QueueManager is now a lazily sourced module:

```text
queuemgr.sh
```

Launch it with:

```bash
queue mgr
queue manager
queue qm
```

Scriptable record-format class creation:

```bash
queue mgr class-create GITHUB_PUBLISH_TEST \
  --no-parallel \
  --max-concurrent 1 \
  --exclusive-claim github_publish:slot \
  --shared-asset net http_status "https://github.com" timeout=5 \
  --shared-asset git repo_exists "/home/hc3/bashqueues" \
  --shared-asset git branch "/home/hc3/bashqueues" require_branch=main
```

The manager generates record-format classes only.


## Standalone queuemgr compatibility

The bare command:

```bash
queuemgr
```

now routes to the new lazy-loaded QueueManager, equivalent to:

```bash
queue mgr
```

The old built-in REPL is kept only for development diagnostics:

```bash
queue legacy-manager
queue legacy-queuemgr
```


## QueueManager asset hints

QueueManager has built-in hints for common asset facilities:

```bash
queue mgr hints
queue mgr hint net:http_status
queue mgr hint git:branch
queue mgr picker
```

During interactive class creation, type `?` at the asset-family prompt to list installed assets and hinted facilities.


## Plugin-published asset hints

Asset helpers may publish UI/editor hints with:

```bash
queue_asset_hints
```

The function emits TSV records:

```text
family:check<TAB>target=...<TAB>params=...<TAB>example=...<TAB>notes=...
```

QueueManager uses these hints for:

```bash
queue mgr hints
queue mgr hint net:http_status
queue mgr picker
```


## Hint compatibility fallback

`queue asset-hints` prefers helper-published `queue_asset_hints` metadata. If an installed helper predates the hint contract, bashqueues synthesizes a minimal hint from `queue_asset_facilities` so QueueManager can still display available facilities.

To get richer target/parameter hints, refresh or replace the asset helper with a version that defines `queue_asset_hints`.


## Class default job settings

Classes may define defaults copied into each job record at submit time:

```bash
CLASS_DEFAULT_RUNNER=systemd
CLASS_DEFAULT_CPU_LIMIT=50%
CLASS_DEFAULT_MEM_LIMIT=512M
CLASS_DEFAULT_MAX_LOG_SIZE_BYTES=1048576
CLASS_DEFAULT_LOG_OVERFLOW_POLICY=stderr-only
CLASS_DEFAULT_TIMEOUT=30s
CLASS_DEFAULT_KILL_AFTER=5s
CLASS_DEFAULT_LOG_TAG='${JOB_NAME}.${JOB_ID}'
CLASS_DEFAULT_OUTPUT_DIR='${QUEUEBASH_ROOT}/class_outputs/${JOB_NAME}/${JOB_ID}'
CLASS_DEFAULT_ENV_PREFIX='${JOB_NAME}_${JOB_ID}'
```

Templates are expanded using the final `JOB_ID`, `JOB_NAME`, and `QUEUEBASH_ROOT`.

QueueManager can set these with `queue mgr class-create --default-*`.


## CPUQuota class defaults

For systemd-backed jobs, class defaults may use either form:

```bash
CLASS_DEFAULT_CPU_LIMIT=50
CLASS_DEFAULT_CPU_LIMIT=50%
```

Both are normalized to the valid systemd property:

```text
CPUQuota=50%
```

The value is passed as an argv element and is not printf-escaped.


## Timeout enforcement

If a job record contains:

```bash
TIMEOUT=30s
KILL_AFTER=5s
```

the payload is wrapped as:

```bash
timeout --signal=TERM --kill-after=5s 30s <command...>
```

For systemd-backed jobs, this appears after the systemd `--` separator:

```text
systemd-run ... -- timeout --signal=TERM --kill-after=5s 30s rexx waiter.rex
```


## Execution caps and billing cycles

Classes can express cost/operational caps:

```bash
CLASS_DEFAULT_TIMEOUT=30s
CLASS_DEFAULT_KILL_AFTER=5s
CLASS_DEFAULT_CPU_SECONDS=20
CLASS_DEFAULT_BILLING_UNIT_SECONDS=60
CLASS_DEFAULT_BILLING_CYCLES=1
CLASS_DEFAULT_BILLING_GRACE_SECONDS=5
CLASS_DEFAULT_BILLING_POLICY=shortest-cap-wins
```

Billing timeout is calculated as:

```text
billing_timeout = billing_unit_seconds * billing_cycles - billing_grace_seconds
```

The effective timeout is the shortest valid cap between explicit `TIMEOUT` and the billing-cycle timeout.

`CPU_SECONDS` is currently metadata shown by `queue explain`; live CPU accounting enforcement is intended for a later systemd-monitor patch.


## runnable:path_safe

`runnable:path_safe` is a preflight asset for scripts that may depend on a specific current working directory or unsafe relative paths.

Example:

```bash
queue_class_shared_asset runnable path_safe "waiter.rex" \
  allow_relative=1 \
  require_cwd="/home/hc3/bashqueues"
```

Parameters:

```text
require_shebang=1     require the script to start with #!
allow_relative=1      allow relative path assumptions
require_cwd=/path     require a working directory to exist
scan_depth=200        number of lines to scan
```


## Class refresh

Refresh class definitions from a directory of `.env` files:

```bash
queue classes refresh ./classes
queue mgr class-refresh ./classes
```

Existing class definitions are backed up under:

```text
~/.queuebash/classes/.backup/
```

Refresh is intended for loading bundled class definitions such as `REXX_RUNAWAY.env` into a user's queue root.


## Resubmit adopts current class

When a failed/cancelled/deleted job is resubmitted, bashqueues preserves the job intent but re-applies the current class definition to the new QID. This means changed class defaults such as timeout, billing caps, CPU/memory limits, and log caps are adopted by resubmitted jobs.


## Job history

Show lifecycle events, dispatch attempts, resubmit links, exit codes, and logs:

```bash
queue history <job-id|name>
```

`queue explain <job>` includes a compact History section and points to the full command.


## Asset refresh dispatcher fix

`queue assets refresh ./assets.d` refreshes asset helpers from a directory of `.sh` plugin files. It must route to the asset plugin refresher, not class refresh.

Use after installing patched bundled helpers:

```bash
queue assets refresh ./assets.d
queue assets validate
queue assets explain runnable:path_safe
queue asset-hint runnable:path_safe
```


## Unambiguous refresh aliases

For scriptable use and QueueManager internals, bashqueues provides direct refresh aliases:

```bash
queue asset-refresh ./assets.d
queue class-refresh ./classes
```

The older grouped commands remain valid:

```bash
queue assets refresh ./assets.d
queue classes refresh ./classes
```


## Asset helper argv contract

Asset check helpers receive the asset target as `$1`, followed by optional `key=value` parameters:

```bash
queue_asset_check_runnable_interpreter "rexx"
queue_asset_check_runnable_path_safe "/home/hc3/bashqueues/waiter.rex" allow_relative=1
```

They do not receive the full asset token as `$1`.


## Class default working directory

A class can force the execution working directory for submitted/resubmitted jobs:

```bash
CLASS_DEFAULT_WORKING_DIR=/home/hc3/bashqueues
```

This is copied into the job record as:

```bash
PWD_AT_SUBMIT=/home/hc3/bashqueues
```

and is useful for jobs whose command uses relative paths, for example:

```bash
queue submit rexx_waiter_caps --class REXX_RUNAWAY -- rexx waiter.rex
```

even when the submit command is typed from another directory.


## Class job command context

When a class is sourced for a specific job preflight, bashqueues exports command context variables that class records can use:

```bash
QUEUEBASH_JOB_WORKDIR
QUEUEBASH_COMMAND_0
QUEUEBASH_COMMAND_ARG_1
QUEUEBASH_COMMAND_ARG_1_ABSPATH
```

Use `${QUEUEBASH_COMMAND_ARG_1_ABSPATH:-fallback}` in class files so class-default inspection still works before a concrete job is loaded.


## Class wizard

QueueManager includes a zero-dependency terminal class builder:

```bash
queue mgr class-wizard CLASS
queue mgr class-builder CLASS
```

It uses `tput` and raw keyboard input where available, falling back to normal prompts otherwise. The wizard browses published asset facilities, shows helper-published hints, adds record-format shared/exclusive assets, previews the class, and saves it to `~/.queuebash/classes/CLASS.env`.


## Network allowance and usage caps

Charged data links can be handled with plugins.

The canonical class/preflight gate is `net:allowance`:

```bash
queue_class_shared_asset net allowance "wwan0" allowance_bytes=10G direction=rx_tx
```

Testable counter-file form:

```bash
queue_class_shared_asset net allowance "charged" counter_file=/tmp/charged.bytes allowance_bytes=10G
```

Per-job runtime accounting still uses the `CLASS_DEFAULT_NET_USAGE_*` metadata names:

```bash
CLASS_DEFAULT_NET_USAGE_INTERFACE=wwan0
CLASS_DEFAULT_NET_USAGE_DIRECTION=rx_tx
CLASS_DEFAULT_NET_USAGE_LIMIT_BYTES=500M
CLASS_DEFAULT_NET_USAGE_POLICY=mark-failed
```

Jobs record `NET_USAGE_START_BYTES`, `NET_USAGE_END_BYTES`, `NET_USAGE_USED_BYTES`, and `NET_USAGE_EXCEEDED`. `mark-failed` converts a successful payload into exit code `87` when the usage limit is exceeded.


## Time-window class restrictions

Use the `time:window` asset to prevent dispatch outside allowed periods:

```bash
queue_class_shared_asset time window "overnight-window" \
  weekdays=mon-fri \
  weekday_windows=18:00-05:00 \
  weekends=sat-sun \
  weekend_windows=always
```

Bundled class:

```text
OVERNIGHT_WINDOW
```

`OVERNIGHT_WINDOW` blocks weekday daytime dispatch. To override the restriction for a specific job, keep the job in `OVERNIGHT_WINDOW` and add a QID exception overlay:

```bash
queue exception add <qid> time:window --reason "operator-approved daytime run"
```


## QID exception overlays

Class restrictions should normally stay inside the class. To override a restriction for one job, add an exception overlay to the QID:

```bash
queue exception add <qid> time:window --reason "operator-approved daytime run"
queue exception list <qid>
queue exception clear <qid> time:window
```

The exception key may be:

```text
family              e.g. time
facility            e.g. time:window
full asset token    e.g. time:window:overnight-window
```

During class preflight, only the matching asset gates are skipped. Each creation and application is logged as an event, and `queue explain <qid>` shows the active overlays.

This is preferred over changing the job to a separate exception class because it keeps the original policy class visible while documenting exactly which restrictions were ignored.


## full-screen panel manager

### Panel command line

The full-screen panel supports type-a-command operation.  Type any printable character and the command line opens with that character already entered; press `F2` for an empty command prompt.  Commands accept first unique letters and unique substrings, then route to the correct panel and fill the relevant fields.

Examples:

```text
jo
tas
user hc3
user clear
task name publish_git
task command bash publish_to_github.sh
task class GITHUB
task schedule +1h
task dependencies setup_job, previous_qid
task on-success bash -c 'echo completed'
task save
class use GITHUB
cla mycla hist
panel:classes
maint health preview
job 1798231 history
```

In the command prompt, `*` opens contextual completions.  From Queue Users it can offer queue users plus `panel:*` jumps.  After choosing `panel:classes`, another `*` offers class names and then class actions, so the command line can be built up as `class MYCLASS history`.  Typing `cla mycla hist` directly performs the same cross-panel jump/action when the class match is unique.

Completion ordering is operational: current objects and actions are listed first, while panel jumps are grouped at the bottom.  On Jobs, `*` starts with job actions such as `job QID history`; on Classes it starts with class/object actions; on Queue Users it starts with user choices.  `panel:*` entries stay available, but they no longer push the current work off the top of the popup.

Panel tabs are hotkey-labelled rather than numbered, for example `[J] Jobs`, `[T] Task Creator`, and `[M] Maintenance`. Type the hotkey/command letter or any unique command prefix to move panels.

Global actions are on function keys: `F1` help, `F2` command, `F3` Queue Users, `F4` Jobs, `F5` refresh, `F6` dry-run, `F7` filter, `F8` detail tab, `F10` action, and `F12`/`Esc` quit.  `F9` and `F11` are deliberately not bound because Linux desktops and terminal emulators often reserve them or make accidental mutations too easy. Job copy remains a typed command: `job FRAG copy`. Exception operations remain available as typed commands: `ex`, `exception`, `ce`, and `clear-exception`.  Because Linux terminals/window managers may reserve some keys, the typed command line remains the portable fallback.


A curses-backed manager is available for panel-oriented workflows:

```bash
queue mgr panel
```

Panels are shown with hotkeys, not numbers:

```text
[U] Queue Users
[J] Jobs
[D] Drafts
[C] Classes
[A] Assets
[M] Maintenance
[E] Exceptions
[K] Class Creator
[T] Task Creator
```

The screen uses side-by-side panels with scrolling list/detail areas. The Restriction Builder panel is temporarily removed; class restrictions are managed through Classes/Class Creator commands and module/asset documentation.

The manager is intentionally separate from `queuebash.sh`; it invokes existing `queue ...` commands so the queue core remains the source of truth.

If launched directly with `python3 queuemgr_panel.py`, the manager auto-discovers an adjacent `queuebash.sh` and sources it before running `queue ...` commands.

The panel manager header shows the resolved `queuebash.sh` source. If it displays `NO QUEUE SOURCE`, launch from the source tree or set `QUEUEBASH_SOURCE=/path/to/queuebash.sh`.


### Panel command-line actions for Classes and Assets

The panel command line (`F2`) can operate directly on the selected class or asset. On the Classes panel, commands such as `explain`, `history`, `enable`, `disable`, `refresh`, and `use` apply to the selected class. On the Assets panel, commands such as `explain`, `hint`, `validate`, `enable`, `disable`, `refresh`, and `rollback` apply to the selected asset/plugin.

Explicit forms also work from any panel, for example:

```bash
class GITHUB_PUBLISH history
class GITHUB_PUBLISH disable
asset net:allowance explain
asset net:allowance disable
```

## Panel manager operator console

The panel manager supports operator workflows:

```text
d       toggle dry-run mode
f       filter current panel
[ / ]   switch right-hand job tabs
e       add QID exception overlay after showing the job class
c       clear QID exception overlay
x       context action
C       clear queue buckets
```

Job detail tabs:

```text
Explain
Class
Exceptions
History
Log
```

Class and asset panels expose actions for explain, validate, refresh, delete/archive, and rollback where the corresponding `queue ...` command exists.


### Scrollable command output

Panel manager command-output windows are scrollable:

```text
Up/Down       line scroll
PgUp/PgDn     page scroll
Home/End      start/end
q/Esc/Enter   close
```

Modal windows clear their full rectangle before drawing and redraw the panel screen when closed.


## Exception overlays in explain

`queue explain <qid>` always includes an exception overlay section:

```text
Exception overlays
  none
```

or:

```text
Exception overlays
  ignore:            time:window
    reason:          operator approved daytime run
    by:              hc3
    created:         2026-05-23T18:09:31+01:00 (age 42s)
```

This makes the QID explanation the primary audit surface for any restriction bypass.


## Panel Class Creator

The panel manager includes a Class Creator panel.

Workflow:

```text
1. Open Class Creator
2. Set name/purpose/defaults
3. Add shared/exclusive asset records through class commands or by editing the draft
4. Preview, validate, save
```

Generated classes use record-format functions only:

```bash
queue_class_shared_asset time window "overnight-window" weekdays=mon-fri weekday_windows=18:00-05:00
queue_class_exclusive_claim "runtime:nightly:slot"
```

No legacy `CLASS_SHARED_ASSETS` or colon/comma token parsing is generated.


## Panel Task Creator

The panel manager includes a Task Creator panel.

Workflow:

```text
1. Open: 2. Go to Task Creator
3. Set name and command
4. Select class from installed classes
5. Set priority and optional schedule/not-before
6. Preview, dry-run, or save as a persistent draft
7. Submit
8. After a successful submit the Task Creator working draft is cleared
```

The generated command uses the existing queue submit interface:

```bash
cd /home/hc3/bashqueues && queue submit nightly --priority 10 --class OVERNIGHT_WINDOW --not-before "2026-05-23T22:00:00+01:00" -- bash job.sh
```

The Classes panel can also set the selected class into Task Creator using the `use-for-task` action.



### Task Creator save-as-draft and submit clearing

Task Creator has a `save` action. It stores the current task fields as a persistent draft under:

```text
$QUEUEBASH_ROOT/drafts/
```

Saving does not submit a job. It is intended for half-built operational jobs, reviewed jobs, or jobs that should be submitted later from the Drafts panel.

Successful Task Creator submit clears the working Task Creator draft automatically. This prevents accidental duplicate submits after a job has already been queued. Dry-run submit does not clear the draft.

Task Creator also exposes operational dependency and hook fields:

```text
dependencies       after-success dependencies; comma or space separated QIDs/names
inherit env from   inherit environment from completed jobs; also adds dependencies
on success hook    command to run after successful completion
on failure hook    command to run after failed completion
on retry hook      command to run after an unsuccessful attempt before retry
```

The generated submit command uses the existing queue options:

```bash
queue submit job --after-success previous_qid --inherit-env-from setup_job \
  --on-success bash -c 'echo done' \
  --on-failure bash -c 'echo failed' \
  -- bash run_job.sh
```

Saved drafts preserve those dependency and hook settings through `queue draft create` and `queue draft submit`.

The equivalent command-line form is:

```bash
queue draft create publish_git --priority 10 --class GITHUB_PUBLISH --cwd /home/hc3/bashqueues -- bash publish_to_github.sh
```

### Task Creator job names and execution directory

Task Creator normalizes job names before submit. Spaces and unsafe characters become underscores:

```text
publish git -> publish_git
```

Generated submit commands put the job name before options and can include an execution directory:

```bash
cd /home/hc3/bashqueues && queue submit publish_git --priority 10 --class GITHUB_PUBLISH -- bash publish_to_github.sh
```


### Task Creator execution directory is not a submit option

`queue submit` captures the submit directory from the process current working directory. Task Creator therefore previews:

```bash
cd /home/hc3/bashqueues && queue submit publish_git --class GITHUB_PUBLISH -- bash publish_to_github.sh
```

and internally runs `queue submit` with that working directory. It does not emit `--chdir`.


## User context and root/operator use

Classes may declare default user context:

```bash
CLASS_DEFAULT_RUN_USER=appuser
CLASS_DEFAULT_SUBMIT_USER=appuser
```

`CLASS_DEFAULT_RUN_USER` is applied to the job as `RUN_USER`, meaning the payload should execute as that Unix account. When root runs the queue worker, queuebash attempts to switch user with `runuser`/`sudo` for direct execution, or systemd `--uid` where systemd execution is available.

`CLASS_DEFAULT_SUBMIT_USER` is recorded as `SUBMIT_USER` for audit/intent. The panel Task Creator also has a `submit user` field. When set, it runs the submit command as that user, for example:

```bash
runuser -u appuser -- bash -lc 'cd /home/appuser/project && queue submit nightly --class APP_NIGHTLY -- bash job.sh'
```

This is intended for root/operator workflows where one account can manage jobs for multiple user queue roots.


## Root administering user queues safely

Root can administer another user's queue files, but root must not evaluate queue-local code from that user.

Safe root-side operations include file/record administration such as list, cancel/delete, and exception overlay edits.

Commands that may source/evaluate queue-local code are delegated to the queue owner when `QUEUEBASH_ROOT` is owned by a non-root user. This includes:

```text
queue run
queue submit
queue explain
queue classes explain/validate/refresh/replace/rollback/edit
queue assets explain/validate/refresh/replace/rollback/expand
```

The delegation path runs as a child process and then returns to the original shell:

```bash
runuser -u <queue-owner> -- bash -lc 'export QUEUEBASH_ROOT=...; source queuebash.sh; queue ...'
```

The manager/panel launcher itself is not delegated. `queue mgr` stays in the operator/root shell and displays the selected queue context; individual panel actions that submit, explain, validate, or otherwise evaluate queue-local code are guarded when those actions run.

Set this to refuse rather than delegate:

```bash
export QUEUEBASH_ROOT_USER_QUEUE_MODE=refuse
```

There is an explicit escape hatch for trusted maintenance only:

```bash
export QUEUEBASH_ALLOW_ROOT_USER_QUEUE_EVAL=1
```

The default rule is: if code needs to be evaluated, it runs as the owner of the queue, not as root.


### Delegated submit working directory

When the panel Task Creator submits as another user and no execution directory is set, it submits from that user's home directory instead of inheriting the operator's current directory:

```bash
runuser -u testu -- bash -lc 'cd "$HOME" && queue submit run_as_testu -- bash -c "echo testu"'
```

This prevents a job in `testu`'s queue from recording an inaccessible root/operator submit directory such as `/home/hc3/bashqueues`.

If a specific execution directory is required, set it explicitly in Task Creator.


## User systemd bus fallback

`RUNNER=auto` prefers systemd only when the user's systemd bus is actually usable. In `su`/`runuser` shells, `XDG_RUNTIME_DIR` may exist but the user bus may still be inaccessible.

Queuebash now checks:

```text
systemd-run exists
systemctl exists
XDG_RUNTIME_DIR is set
XDG_RUNTIME_DIR/bus is a socket
systemctl --user show-environment succeeds
```

If those checks fail, `RUNNER=auto` falls back to the direct runner instead of attempting `systemd-run --user`.

Job logs include:

```text
systemd_user_bus: user-bus-ok
systemd_user_bus: user-bus-unusable
systemd_user_bus: user-bus-missing
```


## Root running payloads as another user

When root runs a queued payload for another Unix user, `RUNNER=auto` resolves to the direct runner.

This avoids depending on another user's `systemd --user` bus. The direct runner uses the root-controlled user switch path, for example `runuser`, and is the predictable cross-user fallback.

Policy:

```text
root running root payload       -> normal auto behaviour
user running own payload        -> systemd if user bus works, otherwise direct
root running RUN_USER=someuser  -> direct
```

The job log records the policy when active:

```text
foreign_run_user_runner_policy: root-foreign-user-auto-direct run_user=someuser
```


## Managing user queues from root

Root/operator can select another user's queue root from the command line. The selection-only form switches the effective queue user for the current sourced shell session:

```bash
queue --queue-user testu
queue list
```

The equivalent shorthand is:

```bash
queue user testu
queue list
```

The one-shot command form still works when you want to select and run a command immediately:

```bash
queue --queue-user testu list
queue --queue-user testu exception list QID
queue --queue-user testu delete QID
queue user testu submit job -- echo hello
```

When a queue user has been selected, list-style output makes the context visible before the table:

```text
QUEUE USER: testu  shell-user=root  root=/home/testu/.queuebash
JOB_ID                                    STATE  PRI  NAME         OK  FAIL  COMMAND
```

Safe administrative operations can be done directly by root. Any command that might source or evaluate queue-local class/asset code is still protected by the root/user-queue safety guard and delegated to the queue owner. Delegation is a subprocess call, not an `exec`, so after a delegated command finishes the shell remains the original operator/root shell.

The panel manager has a `Queue Users` panel. Select a user there and all other panels operate on that user's queue.

To go back to no selected queue owner, select the clear/current row in `Queue Users`. Optional user/delegation fields such as Task Creator `submit user` can be cleared by entering `current`, `none`, `clear`, `default`, or `-`, or by opening the `*` list and choosing `<current/default>`.

`submit user` is Unix-user delegation, not queue-owner selection. Normal non-root users should leave it blank/current. The panel suppresses `runuser` when the chosen submit user is the current logged-in user; only root/operator sessions use `runuser` to submit as a different Unix account.


## Copying a completed job into Task Creator

In the panel manager, select a job on the Jobs panel and press:

```text
y
```

or use the job action:

```text
copy
```

The selected job is copied into the Task Creator draft using the existing job metadata:

```text
name
command
class
priority
execution directory / submit directory
runner
CPU and memory limits
log cap
retries and backoff
schedule/not-before metadata where available
```

This is intended for repeat operational jobs: copy a known completed job, adjust one or two fields, preview, dry-run, then submit.


## Persistent task drafts

Queuebash supports persistent task drafts under:

```text
$QUEUEBASH_ROOT/drafts/
```

Draft commands:

```bash
queue draft list
queue draft show DRAFT_ID
queue draft create NAME [options] -- COMMAND...
queue draft create-from-job QID
queue draft ready DRAFT_ID
queue draft submit DRAFT_ID
queue draft abandon DRAFT_ID
queue draft state DRAFT_ID draft|ready|submitted|abandoned
```

Draft states:

```text
draft       editable, not submitted
ready       reviewed/approved, not submitted
submitted   converted into a real queue job
abandoned   retained for audit but not active
```

The panel manager has a Drafts panel. The Jobs panel copy action creates a persistent draft as well as populating the Task Creator draft.


## Queue manager panel safety

`queue mgr` and `queue mgr panel` launch the Python panel manager. The legacy numbered text menu has been removed.

When `queuebash.sh` is sourced into an interactive shell, closing the panel must return to that shell. The launcher therefore calls the panel process normally and does not use `exec`, so the current shell is not replaced by the panel.

The panel footer reserves separate lines for help/menu keys and status/message text.

### Panel selection behaviour

In the Python panel manager, command/action prompts and selectable fields accept first unique letters, numeric selection, and unique substrings. Entering `*` opens a searchable scrollable list; type part of the value, move with Up/Down, and press Enter to select. This is used for Task Creator class selection and other known-value fields.


## Panel Maintenance view

The Python QueueManager panel includes a Maintenance view for operator tidy-up work: health fixes, log rolling, log cleaning, and clearing old queue buckets.

Maintenance actions are queued by default.  The panel submits them as normal jobs using the `QUEUE_MAINTENANCE` class with conservative settings and a not-before delay.  This means maintenance appears in `queue list`, is logged, is cancellable before it starts, and runs through the normal class/policy path.

Typical maintenance recipes include:

```bash
queue health --fix
queue compress-logs
queue clean-logs --dryrun --older-than 30d --state done
queue clean-logs --force --older-than 30d --state done
queue clear deleted
queue clear done
queue clear interrupted
queue clear cancelled
```

The panel also offers a confirmed `direct` action for urgent recovery.  Use direct execution when the queue itself needs immediate help; otherwise prefer queued maintenance.

The old text QueueManager REPL has been removed.  `queue mgr`, `queue mgr panel`, `queue manager`, and `queuemgr` route to the panel manager.

### Panel right-hand output modes

Panel commands that inspect jobs or classes keep their output in the right-hand panel.  For example, `job 1798231 history` jumps to the matching job, switches the Jobs detail pane to History, and leaves that mode active as you move through jobs.  `class GITHUB history` does the same on the Classes panel.

Jobs also support typed mutation commands. These are command-line operations, not function-key operations:

```bash
job change priority 5
job 1798231 priority 5
job kill
job delete
job undelete
job edit
```

When the Jobs panel is active, bare actions such as `kill`, `delete`, `undelete`, `change priority 5`, and `edit` apply to the selected job. `job edit` follows the safe queue pattern: it asks for confirmation, cancels the selected job, then creates/populates a new Task Creator draft from the cancelled job so the replacement can be checked before submission.

Job copy is a command, not a function key action:

```bash
job 1798231 copy
```

F9 is intentionally unbound to avoid accidental copying while navigating.

### Task Creator context commands

When the panel is already on Task Creator, bare task actions apply to the current task draft.
For example, typing:

```text
submit
```

is interpreted as:

```text
task submit
```

The same current-task shorthand applies to `save`, `preview`, `dryrun`, `clear`, and task field edits.
This keeps the editor behaviour object-oriented: `(this task) submit`, rather than forcing the operator to repeat the noun every time.

### Jobs Tail right-hand pane

In the panel, `job FRAG tail` selects the matching job and puts the right-hand side into **Tail** mode. Moving through jobs keeps Tail active, so the RHS remains relevant to the selected job. `job FRAG show` still uses the **Log** pane for full job/show output.

## Module management: classes, assets.d, and caps.d

bashqueues now treats classes, asset helpers, and execution-cap helpers as manageable modules.

Module families:

```bash
queue modules list
queue modules explain class:GITHUB_PUBLISH
queue modules explain asset:net
queue modules explain cap:billing
```

Enable and disable operations keep the module file but move it into or out of the module family's `.disabled/` directory:

```bash
queue modules disable class GITHUB_PUBLISH
queue modules enable class GITHUB_PUBLISH

queue modules disable asset net --force
queue modules enable asset net

queue modules disable cap billing
queue modules enable cap billing
```

The family-specific commands are also available:

```bash
queue classes disable GITHUB_PUBLISH
queue classes enable GITHUB_PUBLISH
queue assets disable net --force
queue assets enable net
queue caps disable billing
queue caps enable billing
```

`caps.d` modules such as `billing.sh` and `net_usage.sh` are installed into the queue root during initialisation in the same way as bundled class and asset modules. The normal cap loader only sources enabled `*.sh` files, so disabled cap modules are ignored by execution-cap calculation.

The panel has a Modules view for the same operations. `Tab` moves forward through panels and `Shift-Tab` moves backwards.


### Task Creator dependency/reference fields

The panel Task Creator fields `after success deps` and `inherit env from` are queue-reference fields. Press `*` while editing them to list existing queue job names/QIDs, including a clear option. This prevents an accidental literal wildcard such as `--inherit-env-from '*'`. You can still type a job name, QID fragment, or a manual comma/space-separated dependency list.


### Class Creator hint-driven restrictions

The panel Class Creator can build class restriction records from asset/cap
hints.  Use the **add restriction** row or type commands such as:

```text
classcreator restriction net:allowance
restriction billing
restriction cap:net_usage
```

Each prompt supports `*` popups, unique prefixes, and unique substrings.  The
facility hint is displayed before the record is generated, and the resulting
record is added to the class draft only after confirmation.

### Obsolete asset-side net_usage cleanup

`assets.d/net_usage.sh` has been removed. Runtime network-usage accounting remains
available through `caps.d/net_usage.sh`. Queue roots upgraded from older builds may
still contain a stale `assets.d/net_usage.sh`; module refresh/list operations now
prune or hide that stale asset-side copy.

### Class Creator restriction prompts

Class Creator can build class restrictions from asset/cap hints. The hint metadata is parsed so the panel asks the right questions for each facility instead of asking for one raw parameter line. For example `time:window` prompts for policy name, weekday set, weekday window, weekend set, and weekend window. Press `*` in any generated field to open relevant choices.

### Exceptions panel with selected queue users

The panel Exceptions view is selected-user aware.  In root/operator sessions such
as:

```bash
queue --queue-user testu
queue mgr
```

exception overlays are loaded through `queue exception list-all`, not by reading
the operator's local `$QUEUEBASH_ROOT/exceptions` directory.  This keeps the top
level Exceptions panel consistent with the Jobs detail `Exceptions` tab.

### Exceptions panel with selected queue users

The panel Exceptions view is selected-user aware.  In root/operator sessions such
as:

```bash
queue --queue-user testu
queue mgr
```

exception overlays are loaded through `queue exception list-all`, not by reading
the operator's local `$QUEUEBASH_ROOT/exceptions` directory.  This keeps the top
level Exceptions panel consistent with the Jobs detail `Exceptions` tab.

### Class Creator restriction hints

Class Creator uses asset/cap hints to generate field-specific setup prompts for class restrictions. `*` opens contextual choices for each field. Test-only hint parameters, such as `now_epoch=TEST` on `time:window`, are hidden from the normal production wizard.

Directory filesystem checks now explain that `executable` means searchable/traversable. For `/tmp`, use `writable=1 executable=1` or just `writable=1`.


Module commands also accept completion-expanded identities, for example:

```bash
class:CAPS_TEST explain
asset:net explain
cap:net_usage explain
```

In these forms the first token is the module identity and the following token is the action.

## Cron bridge

The optional cron bridge lets cron-shaped schedules submit bashqueues jobs instead
of running commands directly. It is installed with:

```bash
sudo ./install-cron-bridge.sh
```

Use `bashqueues-crontab -e` or `queue cron edit` for bashqueues-managed crontabs,
`queue cron explain [user]` to translate entries into readable schedule/submission details,
`queue cron class ENTRY CLASS` to route an entry to a named queue class,
`queue cron status` to inspect the installed bridge/timer/spool state,
`queue cron test` for status plus a dry-run tick,
and `queue cron tick --dryrun` to preview due entries. See
[`docs/CRON_BRIDGE.md`](docs/CRON_BRIDGE.md).


### Queue-history asset checks

The `queue` asset family checks bashqueues job records rather than the current OS process table. This is useful for once-per-period or prerequisite workflows:

```bash
queue_class_shared_asset queue command_has_run "nightly_export.sh" match=substr time=24h
queue_class_shared_asset queue command_has_not_run "nightly_export.sh" match=substr time=24h
```

Use `proc:not_running` when the question is "is this process running right now?". Use `queue:command_has_not_run` when the question is "has a matching queue job already run recently?".

### Runtime caps

In addition to static `secaudit` assets and `--sandbox` isolation, bashqueues
now includes runtime caps via `caps.d/runtime.sh`:

```bash
CLASS_DEFAULT_SANDBOX_LEVEL=strict
CLASS_DEFAULT_RUNTIME_CAPS="no-spawn-shell,no-network-tools,only-local-sockets,only-port"
CLASS_DEFAULT_RUNTIME_CAP_INTERVAL=1
CLASS_DEFAULT_RUNTIME_CAP_PORTS="5432,8000-8099"
```

The worker watches the running process tree with `/proc` and, when installed,
`lsof -p`, then terminates jobs that spawn forbidden shells, invoke network
client tools, open non-local sockets, or use ports outside the class allow-list.


### 0.17.12 runtime cap spelling and C2 audit notes

Runtime cap names may be written with hyphens or underscores. For example, `no_spawn_shell` is normalised to `no-spawn-shell`. Unknown runtime cap names are reported as warnings in job logs and `queue explain`, because a misspelled cap should not silently disable protection.

`secaudit:no_network_c2` now detects listener-style network payloads such as `nc -l -p PORT`, `ncat -l`, `socat TCP-LISTEN:PORT`, and Python `socket.bind(...)` patterns. This remains an early warning layer; runtime sandbox and caps remain the load-bearing enforcement.

### 0.17.14 systemd relative executable handling

When the systemd runner is selected, bashqueues now normalises a relative executable argv[0] such as `./script.sh` to an absolute path before passing it to `systemd-run`. This avoids systemd's `is neither a valid executable name nor an absolute path` launch failure while keeping the job working directory unchanged.

### Seccomp profiles and sandbox/cap exception overlays

`bashqueues` supports class-level seccomp profiles for systemd-run jobs:

```bash
CLASS_DEFAULT_SECCOMP_PROFILE=docker-default
```

`docker-default` blocks dangerous syscall groups such as clock manipulation,
debug/ptrace, kernel module loading, mounting, raw I/O, reboot, swap, CPU
emulation, and keyring operations. `strict` uses systemd's `@system-service`
allow-list.

For deliberate exceptions, use job-level flags rather than editing the class:

```bash
queue submit debug-run \
  --class SECURE_CLASS \
  --sandbox-override restrict-egress \
  --seccomp-allow @debug \
  --drop-cap no-network-tools \
  --add-port 8080 \
  -- ./debug-script.sh
```

The exception is visible in `queue explain` under Exception overlays.

### Cron bridge class routing

The cron bridge accepts readable `#class` directives or `BASHQUEUES_CLASS=` as stateful crontab metadata:

```cron
#class cron_standard
*/5 * * * * /opt/jobs/poll-local-service.sh

# Clear a local class by using: queue cron class ENTRY --clear
0 * * * * /opt/jobs/local-cache-clear.sh

# Assignment form remains supported for compatibility.
BASHQUEUES_CLASS=cron_standard
15 * * * * /opt/jobs/legacy-style.sh
```

When set, the ticker submits to the named class and does not overwrite it. Use
`queue cron class 1 NIGHTLY_BATCH` to insert or update the `#class` line for
the first active entry in your bashqueues crontab. When unset, it creates a conservative generated `cron_<hash>` class with
`CLASS_MAX_CONCURRENT=1`, strict sandboxing, and basic runtime caps.

### Security policy files

Sandbox and seccomp profiles are policy-file driven. Bundled policy files live
under `policies.d/sandbox/` and `policies.d/seccomp/`, and are copied into the
queue root at initialisation.

```bash
queue policies list
queue policies show sandbox strict
queue policies show seccomp docker-default
```

Class defaults and submit flags still name policies:

```bash
CLASS_DEFAULT_SANDBOX_LEVEL=strict
CLASS_DEFAULT_SECCOMP_PROFILE=docker-default
queue submit example --sandbox network-none -- command
```

See `docs/SECURITY_POLICIES.md`. See also `docs/SECURITY_EXCEPTION_GUIDANCE.md`.


### Security policy snapshots

Sandbox and seccomp names are policy files, not hard-coded launch profiles.
Shared/admin policy files under `/etc/bashqueues/policies.d` take precedence
over queue-root personal policy files with the same name.

When a job is submitted, bashqueues snapshots the resolved sandbox/seccomp
policy into the `.job` record after class defaults are applied.  `queue explain`
therefore shows the exact policy name, origin, hash, and launch properties that
were in force for that QID.  Job-level exception overlays are applied on top and
remain visible in the exception overlay section.

Useful commands:

```bash
queue policies list
queue policies show sandbox strict
queue policies create sandbox local-strict --from strict
queue policies edit sandbox local-strict
```

Bundled safe defaults include `queue-default`, `network-none`,
`restrict-egress`, and `strict` for sandboxing, plus `queue-default`,
`docker-default`, and `strict` for seccomp.


### 0.17.17 Class Creator seccomp policy chooser

The Queue Manager Class Creator exposes both sandbox and seccomp policy fields. Use `*` on the default seccomp field to choose from `queue policies list seccomp`. F2 commands include `classcreator seccomp docker-default` and `classcreator seccomp-allow @debug`.

### 0.17.18 Queue Manager class edit safety

The Queue Manager class edit action is noninteractive. Selecting `edit` on a class now loads the selected class into the Class Creator panel, where it can be previewed, changed, validated, and saved. The panel no longer invokes `$EDITOR` through `queue classes edit`, because interactive editors can block the curses UI.


### Class policy statements and authorisations

`bashqueues` has a central class policy statement at `policies.d/class-statement/default.env`.
It defines which sandbox/seccomp policies are user-selectable and whether security
exception overlays require `--reason TEXT`, `--authorisation CODE`, or either.

By default, submit-time overlays such as `--sandbox-override`, `--seccomp-allow`,
`--drop-cap`, and `--add-port` require a reason or a short queue-local
authorisation code.

```bash
queue submit job --sandbox-override off --reason "approved one-off" -- command
queue generate authorisation --admin alice --user bob --code A1B2 -- bash -lc 'command'
queue submit job --sandbox-override off --authorisation A1B2 -- bash -lc 'command'
```

Authorisation codes are command-bound, queue-specific, case-insensitive, and no
more than five letters/numbers.  `queue authorisation list` reports whether each
record is internally valid.  If the stored command array is forcibly edited and
no longer matches the stored command hash, the record is shown as invalid and is
not accepted by submit/cron checks.

Authorisations can also be cryptographically signed. Generate an Ed25519
queue-authorisation keypair with:

```bash
queue keygen authorisation root
queue keygen authorisation hc3
queue keys list
queue keys show root
```

The private key remains in `$QUEUEBASH_ROOT/keys/private/` with mode `0600`.
The generated public-key lines can be pasted into a central read-only policy,
for example `/etc/bashqueues/policies.d/class-statement/default.env`:

```bash
CLASS_POLICY_AUTHORISATION_SIGNATURE_REQUIRED="if-trusted-key"

Inspect the active authorisation trust policy with:

```bash
queue authorisation policy
```

When a site policy declares a public key for an admin, new authorisations by that admin must be signed at creation time. For example, if `/etc/bashqueues/policies.d/class-statement/default.env` declares `CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_*`, then `root` authorisations require a matching queue-local private key and cannot silently fall back to unsigned records. If any trust-list keys are present, an undeclared admin is not trusted to create authorisations unless that admin's public key is also present in the policy.
CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_SHA256="..."
CLASS_POLICY_AUTHORISATION_SIGNER_ROOT_PUBLIC_KEY_PEM_B64="..."
CLASS_POLICY_AUTHORISATION_SIGNER_HC3_PUBLIC_KEY_SHA256="..."
CLASS_POLICY_AUTHORISATION_SIGNER_HC3_PUBLIC_KEY_PEM_B64="..."


When a policy file declares trusted authorisation public keys, the short code is only a handle. The authorisation record must still verify against the policy public key for `AUTHORISATION_ADMIN` and the exact command hash. Unsigned records for declared signers show `invalid-missing-signature`; records from undeclared signers show `invalid-untrusted-admin`. Authorisation records are published read-only/readable so a root-issued approval in another user's selected queue can still be listed and verified by that queue owner.
```

When a public key for the authorising admin is declared in policy, the
short code is only a handle; the real check is the Ed25519 signature over the
queue root, authorising admin, authorised user, exact command hash, expiry, and
reason hash.  Editing the command, user, hash, reason, or signature makes the
record invalid.

An operator can authorise an existing job in-place:

```bash
queue authorise <qid> --reason "approved one-off maintenance escape hatch"
```

This appends the authorisation code directly to the existing `.job` file without
rewriting it, so using it from root or the Queue Manager panel does not
accidentally change the job file owner/group.

The cron bridge also uses this mechanism: if a crontab requests a class below
the configured cron minimum, a matching `BASHQUEUES_AUTHORISATION=CODE` is
required or the ticker falls back to the generated safe cron class.  See
`docs/CLASS_POLICY_STATEMENT.md`.

### Security exception overlays

Job-level security overrides such as `--sandbox-override`, `--seccomp-allow`,
`--drop-cap`, and `--add-port` are recorded in the job file and shown by
`queue explain` in the `Exception overlays` section. This makes deliberate
single-job relaxation visible without editing the underlying class.

`queue explain` also includes `Security exception guidance`. When a job is
blocked by a runtime cap, sandbox, seccomp-looking failure, or pending
class/asset preflight, explain prints the narrowest likely exception needed for
that specific job. Examples include:

```bash
--drop-cap no-network-tools
--add-port 443
--sandbox-override off
queue exception add <qid> secaudit:no_network_c2 --reason "approved one-off exception"
```

These are deliberately suggestions, not automatic policy changes. The preferred
operator flow is to approve the smallest job-local exception and leave the class
restriction visible.


### Existing-job authorisation target user

When an operator such as `root` authorises an existing job in a selected user queue,
for example `queue --queue-user hc3 authorise QID --reason "..."`, the authorisation
is recorded as `admin=root` and `user=hc3`.  The target user is the selected queue
owner, not a stale `SUBMIT_USER` field from the job record.




### 0.17.30 authorisation signer key-root fix

Signed authorisations now separate the selected queue root from the signer key root.
When root switches into another user's queue with `queue --queue-user hc3`, authorisation records
and job stamps are still written into `/home/hc3/.queuebash`, but root's private signing key is read
from root's own key store, for example `/root/.queuebash/keys/private/root.ed25519.pem`.

`queue authorisation policy` reports the active signing key root to make this visible during debugging.

### 0.17.29 authorisation stamping guard

`queue authorise QID` now validates the candidate authorisation against the active class-policy signature requirements before publishing the authorisation record or appending `SECURITY_AUTHORISATION_CODE` to the job file.

### 0.17.31 authorisation keygen selected-user key-root fix

When an operator such as `root` is working against another user's queue with `queue --queue-user hc3`, authorisation files and job stamps are written to the selected queue, but signing keys are operator-owned. `queue keygen` and `queue authorise` now both use the signer/operator identity key root, so root uses `/root/.queuebash/keys` rather than `/home/hc3/.queuebash/keys`.

### Policy-block test policy

A validation-only policy is included at `policies.d/class-statement/policyblock-test.env`.
When installed as a shared/admin class-policy statement and selected with
`QUEUEBASH_CLASS_POLICY_STATEMENT=policyblock-test`, jobs submitted with
`--class POLICYBLOCKED` move directly to the terminal `pol_blocked` state unless
they have a valid command-bound authorisation. See `docs/POLICYBLOCK_TEST.md`.

### pol_blocked and security exemptions

Jobs blocked by a shared/admin class-policy statement now move to the terminal `pol_blocked` state. They do not retry and do not run preflight checks or payloads. After a valid command-bound authorisation exists, the same command can be resubmitted repeatedly until the authorisation expires. Exemptions are logged as `policy-approved`, `description-approved`, or `code-approved`.

### Emergency policy command blocks

Shared/admin class-policy statements can block commands by exact command hash,
command word, or shell-glob pattern before claims, preflight, or payload launch.
This is intended for rapid zero-hour response, including cron-submitted jobs.
See `docs/POLICY_COMMAND_BLOCKS.md`.

Jobs that run under a standing grant, reason, or valid command-bound
authorisation are still logged as security exemptions and shown by
`queue explain`.


### Queue sentinel / scheduler

`queue sentinel` is the lightweight daemon-mode control thread. It is deliberately separate from payload workers. It does not launch job commands and it does not run normal asset preflight. Its job is to perform cheap queue-control checks while workers may be busy:

```bash
queue sentinel --once
queue sentinel --interval 30 --detach
queue scheduler --interval 30 --detach   # alias
queue daemon --interval 30 --detach      # sentinel plus --min-workers 1
```

The sentinel currently removes dead detached-worker PID files, marks definitely stale running jobs as `interrupted`, moves policy-contrary pending jobs to `pol_blocked`, and evaluates only `deadline:monitor` / `deadline:panic` assets for due, dependency-ready jobs. With `--min-workers N` it also starts enough detached payload workers to maintain the requested minimum whenever at least one due, dependency-ready job exists. This lets deadline-driven priority boosts and bounded extra-worker starts happen before a payload worker becomes free, while keeping the control thread itself cheap.


### Queue Manager policy/global editors

The Queue Manager tab order now starts with day-to-day operational views: Jobs, Task Creator, Drafts, Classes, Assets, Policies, Global Resources, Exceptions, Queue Users, Modules, Maintenance, and Class Creator.

The Policies panel lists sandbox, seccomp, and class-statement policies and exposes actions for show/explain, path, edit, and create-copy. Root editing defaults to `/etc/bashqueues/policies.d`; normal users edit queue-local policy files unless `--shared` or `--personal` is specified.

The Global Resources panel exposes claims, explain, cleanup dry-run, cleanup, and force-release actions.

Typed command entry preserves the first printable key that opened the command prompt, so typing `e` followed by `xpl` becomes `expl` rather than losing the initial `e`.

### 0.17.51 operations additions

- `queue reevaluate [--all|QID]` rechecks `pol_blocked` jobs after a policy change or new command-bound authorisation.
- `queue exception add QID ASSET --reason TEXT --expires +2h` creates time-limited asset exceptions.
- `queue backup create FILE.tar.gz` and `queue backup restore FILE.tar.gz --to DIR` provide filesystem backup/restore helpers.


### 0.17.43 noninteractive submit default reason

Noninteractive scripts that create temporary queues, such as repository smoke tests, may run under a site policy that requires a reason for weak/default sandbox choices. They can set an audited default reason instead of adding `--reason` to every local test submission:

```bash
QUEUEBASH_SUBMIT_REASON_DEFAULT="publish selftest temporary queue under site policy" \
  bash tests/selftest.sh
```

This is only reason text. It does not satisfy policies that require a signed authorisation code, and it does not make an authorisation valid for a different command.

### System daemon

`queue system-daemon` is the root multi-user control loop. It scans user queue roots and delegates per-user `queue daemon --once --min-workers N`, so queued work is cleared by user-owned workers rather than by root. Install it with `sudo ./install-system.sh --with-daemon`.


### Developer introspection

`queue dev` provides JSON-friendly Bash introspection and function-scoped patching for dogfooding and AI-assisted maintenance:

```bash
queue dev locate FUNCTION --json
queue dev extract FUNCTION --json
queue dev functions --json [prefix]
queue dev patch --file FILE --function FUNCTION --source SOURCE --json
```

See `docs/DEV_INTROSPECTION.md`.


## Class library and cron selector

bashqueues includes common class templates for backups, batch processing, migrations, deployments, transfers, reports, alerts, sensitive exports, deadline-critical work, log housekeeping, and interactive priority jobs. The optional `bin/bashqueues-cron-class-selector.py` helper can classify cron commands when no explicit `#class`/`BASHQUEUES_CLASS` directive is present; the cron bridge still falls back to a generated strict safe class if no safe match is accepted.


### Gemini advisory provider

`queue ask` can use Gemini as a live advisory provider when explicitly enabled by policy. The provider is advisory-only, audited, and receives only policy-allowed context.

```bash
export QUEUEBASH_AI_LIVE_ENABLED=1
export QUEUEBASH_AI_GEMINI_API_KEY_FILE="$HOME/.queuebash/secrets/gemini_api_key"
queue ask --provider gemini --live --context docs,tests,classes "How do I submit a job?"
```

Provider output is data, never shell, and cannot approve, submit, cancel, patch, sign, or override policy.

## Module and Provider command contract

`queue module` is the standard extension surface for classes, assets, caps and
providers. It now includes provider configuration and policy discovery commands:

```bash
queue module help provider
queue module configure provider gemini --set QUEUEBASH_PROVIDER_KIND=ai
queue module policy provider gemini
queue module acl set provider gemini ai.ask BQ_AI_Users
```

Provider modules are configuration/data modules. They let enterprise installs
connect bashqueues to Microsoft, LDAP, PAM/NSS, IBM Cloud, PKI, Vault/HSM or
internal policy services while single-user installs remain simple and file-backed.
Provider output is data, never shell.

### AI advisory grounded status context

`queue ask` includes installed command and asset/facility grounding so live AI providers are less likely to invent non-installed commands. Redacted queue/job status is available only when explicitly enabled with `QUEUEBASH_AI_ALLOW_QUEUE_STATUS=1`, `QUEUEBASH_AI_ALLOW_JOB_STATUS=1`, and/or `QUEUEBASH_AI_ALLOW_JOB_METADATA=1`. Job log/tail excerpts remain separately gated by `QUEUEBASH_AI_ALLOW_JOB_TAIL=1`.

### AI safety event reporting

`queue ask` runs a deterministic local safety classifier before live Gemini/Ollama provider invocation. Obvious policy-bypass, security-probe, coercion, abuse, or self-harm/distress prompts are refused locally, logged to `~/.queuebash/logs/ai-safety.audit.jsonl`, and given safe operational alternatives such as `queue explain <job_id>`. The response must not claim HR, emergency services, or ticket creation unless a configured reporter later returns a real ticket ID. See `docs/ADVISORY_SAFETY_GOVERNANCE.md`.
### ITSM reporter contract

`queue itsm` exposes a contract-only event outbox for support, security, operations, legal, integrity, FinOps, and AI safety events. Enable it with `QUEUEBASH_ITSM_ENABLED=1`; events are written as JSONL to `~/.queuebash/logs/itsm-events.jsonl` by default. 0.18.8 does not create live ServiceNow/Jira/Freshservice/Zendesk/BMC/ManageEngine tickets by itself and does not claim ticket creation unless a future configured reporter returns a real ticket ID. See `docs/ITSM_REPORTER_CONTRACT.md`.


### AI high-risk operation governance (0.18.9)

`queue ask` now treats destructive or retention-affecting operations as high-risk advisory work. Legitimate prompts such as approved decommissioning or customer-record retention changes are not refused by default, but the response is governed: verify authority/change ticket, legal hold/retention status, trusted authorisation/signature, class isolation/exclusive claims, approved change window, `queue explain` review, and preserved audit evidence.

Destructive misuse such as `rm -rf /` through a queue is refused. Policy-bypass destructive prompts, such as bypassing `pol_blocked` to drop a database, remain policy-bypass refusals. High-risk events are recorded as `advisory_high_risk_operation` with `ticket_requested=false` and `ticket_created=false` unless a future configured reporter proves otherwise.

### Policy setup wizard contract (0.18.10)

0.18.10 adds `bin/queue-policy-wizard`, a conservative setup assistant for
creating initial bashqueues policy files. This is a contract/hardening release,
not a live provider installer.

Key properties:

- `--dryrun` prints the plan and generated file contents without writing files.
- `--non-interactive` accepts deterministic defaults for CI and repeatable setup.
- user scope writes under `~/.queuebash`; system scope writes under `/etc/queuebash`.
- secrets are never prompted into policy files; only secret-file paths are stored.
- AI live configuration uses `QUEUEBASH_AI_LIVE_ENABLED`, not legacy names.
- optional ITSM settings are contract-only and do not claim ticket creation.
- optional dogfood verification jobs are non-blocking and clearly reported.

Examples:

```bash
bin/queue-policy-wizard --dryrun --non-interactive
bin/queue-policy-wizard --dryrun --non-interactive --json
bin/queue-policy-wizard --non-interactive --apply
sudo bin/queue-policy-wizard --scope system --non-interactive --apply
```

See `docs/POLICY_SETUP_WIZARD.md` for the contract and generated policy paths.

### IBM Cloud identity and sovereignty (0.18.11)

0.18.11 adds a narrow IBM Cloud governance rail without turning IBM support into a live-everything integration.

Delivered components:

- `assets.d/ibm_identity.sh`
- `classes/CLOUD_IBM_GDPR.env`
- `classes/CLOUD_IBM_FINREG.env`
- `classes/CLOUD_IBM_LEGAL_READONLY.env`
- `classes/CLOUD_IBM_LEGAL_COMPLIANCE.env`
- `docs/IBM_CLOUD_GOVERNANCE.md`
- `policies.d/sovereign/ibm.env.example`

The IBM asset family is `ibm_identity` and exposes:

```text
ibm_identity:auth_active
ibm_identity:target_region_allowed
```

Environment knobs:

```bash
QUEUEBASH_IBM_REGION=eu-gb
QUEUEBASH_IBM_ACCOUNT_ID=
QUEUEBASH_IBM_RESOURCE_GROUP=
QUEUEBASH_IBM_AUTH_REQUIRED=1
```

The release intentionally excludes IBM FinOps scraping, IBM Cloud Logs/Activity Tracker reporters, HPCS key-provider behaviour, Watson advisory, and Satellite worker identity. Those remain future provider/reporter packages.

### 0.18.12 IBM Cloud FinOps/legal/integrity contract

IBM regulated workload templates now have a cache-backed FinOps contract.
`assets.d/ibm_finops.sh` reads local cache and health files only; it does not
call IBM Cloud APIs in worker preflight. Example files live in
`policies.d/finops/ibm.env.example`, `examples/ibm/`,
`policies.d/legal-registry/ibm.example.tsv`, and
`examples/manifests/ibm_finreg.manifest.example`.

Canonical system paths use `/etc/queuebash`, for example
`/etc/queuebash/finops/ibm_cost_cache.json`,
`/etc/queuebash/legal_registry.tsv`, and
`/etc/queuebash/manifests/ibm_finreg.manifest`.


## 0.18.13 - enterprise ACL provider modules

- Added contract-first ACL provider command surface (`queue acl`).
- Documented normalized ACL decisions: allow, deny, error, reason, evidence, TTL/cache policy.
- Added ACL and key/trust provider contract docs.
- Added file, LDAP, and PAM/NSS provider examples using `/etc/queuebash` paths.
- Privileged provider errors remain fail-closed; providers supply data, never shell.

### 0.18.15 file ACL provider

`queue acl check` can now use `QUEUEBASH_ACL_PROVIDER=file` with a local TSV policy. The file provider is intended for single-user and test installs and remains a provider-backed decision path rather than global hard-coded ACL enforcement.

### 0.18.15 key provider registry contract

0.18.15 adds a normalized `queue key-provider` / `queue trust-provider` contract for key lookup, signer delegation, revocation, and rotation decisions. The release includes a local file-backed key registry for single-user installs and tests, while keeping live PKI, Vault/HSM, IBM HPCS, Azure Key Vault, Microsoft, LDAP, and PAM/NSS providers for later packages. Providers return normalized JSON data only; core command logic enforces decisions and fails closed on missing or malformed provider output.

### 0.18.17 profile multi-signature contract

0.18.16 adds a contract-first profile multi-signature sidecar model. Profiles may carry `signatures.json` beside the profile directory using schema `queuebash.profile_signatures.v1`, with signers such as `self:hc3`, `team:security-review`, `org:bashqueues`, `external:vendor`, and `trusted-ca:root`. The `queue profile-signature` command validates the sidecar and optional required-signer policy, returning `queuebash.profile_signature_verification.v1` responses. This release does not force migration of legacy signed profiles and does not perform cryptographic verification yet; later releases can connect this contract to key-provider lookup, signer revocation, delegation, and approval enforcement.


### Profile multi-signature file verifier

`queue profile-signature verify PROFILE_DIR --policy FILE --json` validates the `signatures.json` sidecar, checks required signer/role policy, and consults the key-provider registry contract for `profile.sign` trust. Cryptographic signature verification is deliberately not performed in 0.18.17.

### 0.18.18 internal refactor: bundled installers

0.18.18 reduces repeated installer boilerplate in `queuebash.sh` by introducing shared helpers for bundled source-directory resolution and non-overwriting flat-file installation. Behaviour is intended to be unchanged: bundled classes, env profiles, assets, caps, reporters, and supported policy files are copied into the selected queue root only when no local or disabled file already exists.



### 0.18.19 policy installer backfill

Bundled policy installation now covers newer ACL/key/profile-signature/IBM/governance policy example families while preserving local no-overwrite and `.disabled` behaviour.
