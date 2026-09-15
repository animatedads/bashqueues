# BashQueues

**BashQueues is a policy-aware, file-backed job queue and operations framework for Bash, with first-class ooRexx integration.**

It began with a deliberately simple idea — make queued work visible as ordinary files and shell commands — and has grown into a substantial operations toolkit for local jobs, servers, clusters, cloud and hybrid estates. The project is still recognisably Bash: you can inspect it, script it, recover it, and understand what it is doing without a database or opaque controller.

Current publication work is bringing the repository to the supplied **0.18.144** source delivery.

## What problems does it solve?

BashQueues is useful when work needs more than `command &`, cron, or an ad-hoc shell loop. It provides a common queue vocabulary for:

- submitting, prioritising, holding, releasing, cancelling, retrying and inspecting jobs;
- class-based admission, capabilities, environments, resources and policy gates;
- safe worker claim/ownership, state transitions, stale-job reconciliation and health checks;
- serial, batch, deadline, maintenance, deployment, backup, migration and security-sensitive work;
- JSON contracts for automation and ooRexx/API consumers as well as readable operator output;
- local and remote execution models, node placement and cluster coordination;
- cloud/provider contracts spanning major public, sovereign, edge, GPU and hybrid platforms;
- evidence, audit, authorisation, signatures, approvals and compliance-oriented controls;
- VCS, build/release, service and infrastructure preflight checks;
- optional AI advisory/policy tooling with explicit safety and live-use gates;
- developer tooling (`queue dev`) for extraction, patching, tests, embedded QBTESTs and scratchpad evidence.

It is not intended to hide the operating system. The design favours inspectable state, explicit authority, fail-closed policy decisions, and tools that remain useful on ordinary Unix/Linux systems.

## Quick start

The main implementation is `queuebash.sh`. It is **sourced**, rather than executed, because it installs the `queue` function into the current shell.

```bash
source ./queuebash.sh
queue --help
queue health
queue list
```

To load it in future interactive shells:

```bash
printf '%s\n' 'source /path/to/bashqueues/queuebash.sh' >> ~/.bashrc
```

For scripted/non-interactive use, export `QUEUEBASH_ALLOW_NONINTERACTIVE=1` before sourcing where required. System installation helpers are also provided; review the installer and your site policy before installing system-wide.

## Repository map

| Path | Purpose |
| --- | --- |
| `queuebash.sh` | Core queue implementation and command surface |
| `bin/` | Command helpers and operator/developer tooling |
| `classes/` | Queue classes and execution/admission profiles |
| `assets.d/` | Asset/capability probes and policy-facing facts |
| `caps.d/` | Capability providers |
| `providers.d/` | Provider integrations and provider contracts |
| `policies.d/` | Shipped policy material |
| `api/` | Programmatic APIs, including ooRexx frontage |
| `schemas/` | Machine-readable contract schemas |
| `resources.d/` | Display/help resources |
| `docs/` | Architecture, operator and feature documentation |
| `examples/` | Worked examples |
| `fixtures/` | Test fixtures |
| `tests/` / `testr/` | Static, smoke, contract and acceptance coverage |
| `systemd/` | systemd integration material |
| `CHANGELOG.md` | Detailed development/release history |

Runtime queue roots such as `.queuebash/`, `.qbroot/`, `pending/`, `running/`, `done/`, `logs/` and similar state directories are deliberately **not source** and are not part of the published source tree.

## ooRexx

BashQueues includes an ooRexx-facing API and examples so Rexx applications can submit and inspect queued work through stable JSON contracts rather than scraping terminal output. It also sits alongside the much larger [Alchemy ooRexx toolkit collection](https://github.com/animatedads/alchemy), which contains reusable ooRexx libraries, runtimes, services, UI, storage, AI, database, ML, emulation and worked application components.

## Design principles

BashQueues generally prefers:

1. **Visible state** — important queue state should be inspectable on disk and through commands.
2. **Explicit authority** — placement, execution, policy, authorisation and remote actions have clear ownership boundaries.
3. **Fail closed** — missing policy, permissions, signatures or required capabilities should not silently become permission to run.
4. **Recoverability** — interrupted/stale work is evidence to reconcile, not a reason to guess.
5. **Human and machine interfaces together** — readable CLI output and JSON contracts are both first-class.
6. **No dependency smuggling** — external dependencies belong to their own projects/packages, not copied invisibly into unrelated source trees.

## Documentation and history

Start with the material under `docs/`, then use `queue --help`, `queue --json`, `queue health --json`, and the feature-specific help surfaces. `CHANGELOG.md` is intentionally detailed and preserves the rapid development history.

The former top-level release-ledger README is retained under `docs/history/README_pre_publication_2026-09-15.md` so the repository loses no historical information during this documentation clean-up.

## Licence

BashQueues is distributed under **GPL-3.0**. See `LICENSE` and `COPYING_NOTE.md`.
