# Full Disclosure: The `bashqueues` Origin Story

In the spirit of open-source transparency and Zero-Trust architecture, we believe in putting our cards on the table about how this system was built.

`bashqueues` was not created by pretending AI was not involved. It was created by treating AI assistance as something that should be visible, reviewable, criticised, corrected, and subordinated to deterministic engineering.

## The Blueprint

`bashqueues` was architected by a human with decades of battle scars in software architecture, shell operations, and enterprise systems management. The human design set the physical laws of the system:

- distributed governance rather than an opaque central broker;
- filesystem-backed state that administrators can inspect;
- class policy, asset gates, caps, exceptions, and clearance evidence;
- cryptographic approval paths;
- behavioural interrogation profiles;
- fail-closed security decisions;
- distro-friendly packaging and normal Linux operational boundaries.

The project is intentionally boring where boring matters. It uses files, shell, process IDs, systemd properties, signatures, policy records, and audit logs because those are things administrators can inspect and recover.

## The Assembly Line

With the architecture set, construction was carried out with an openly acknowledged AI-assisted software factory. Different AI systems were used for different roles:

- core Bash implementation and hot-path assembly;
- security posture review, capability drops, and seccomp modelling;
- integration-path checking and regression-test generation;
- Microsoft-stack infrastructure modelling, including Active Directory, WinRM, Exchange, DNS, file services, and certificate services;
- cloud integration, sovereignty, multi-jurisdiction routing, and FinOps modelling;
- documentation, packaging strategy, and marketing copy;
- adversarial critique of design claims and runtime assumptions.

That process is not hidden. It is part of the audit trail. The point was not to ask an AI to invent an operations model; the point was to use AI as a high-throughput assembly and review line under human architectural control.

## The Prime Directive

The most important fact about `bashqueues` is this:

**Like all trustworthy enterprise packages, it does not use AI to make runtime decisions about job management.**

There are no Large Language Models in the critical path. There are no stochastic guesses about:

- when a job should run;
- where it should be routed;
- which class policy applies;
- whether an exception is valid;
- whether a profile signature is trusted;
- which system calls a profiled job is allowed to make.

At runtime, `bashqueues` is deterministic, inspectable, policy-verifiable, and designed to fail closed. Where configured, enforcement is delegated to ordinary Linux controls such as filesystem permissions, process ownership, systemd sandbox properties, seccomp syscall filters, capabilities, namespaces, and cryptographic signature verification.

AI helped build the code. Deterministic policy enforces the law.

## Practical consequence

The development process may be modern, but the operational contract is conservative:

- no AI daemon is required;
- no network model is required to decide whether a local job may run;
- no stochastic runtime decision is trusted;
- no generated behavioural profile is accepted until it is reviewed, approved, and verified according to policy;
- enterprise trust sources may be integrated through providers, but local file-backed policy remains a valid small-site/default model.

That is the intended bargain: use AI to accelerate construction and review, but keep runtime authority deterministic, auditable, and enforceable by normal systems engineering controls.
