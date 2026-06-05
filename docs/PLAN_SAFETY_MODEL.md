# Queue plan safety model

`queue plan` is an ingestion and staging surface. It must be fail-closed.

## Safety states

```text
accepted
accepted_with_warnings
needs_review
unsupported
unsafe_refused
```

## Review/refusal triggers

- privileged container or root execution;
- host networking, host PID/IPC, hostPath mounts or broad filesystem write access;
- public gateway/listener exposure;
- wildcard IAM, administrator roles or identity-expanding permissions;
- secret values embedded in source;
- destructive lifecycle actions;
- unknown CRDs or executable/dynamic plan code;
- Terraform/Pulumi/Airflow/Jenkins content that requires execution to understand safely.

## No execution during import

Adapters must parse and classify. They must not run shell code, Python DAGs, Jenkinsfiles, Terraform, Pulumi programs, cloud CLIs, or provider SDK calls while scanning/building a plan.
