# Module and Provider Command Contract

`queue module` is the standard command surface for bashqueues extension modules.
It gives users and enterprise administrators one place to discover, configure,
explain, and apply policy around extension points.

## Supported module kinds

- `class` — execution class definitions under `classes/`
- `asset` — preflight/resource policy plugins under `assets.d/`
- `cap` — runtime capability plugins under `caps.d/`
- `provider` — provider configuration modules under `policy/providers.d/`

Provider modules are especially important for enterprise installations. They
represent the local configuration needed to reach external governance systems
such as Microsoft/Entra, LDAP, PAM/NSS, IBM Cloud, enterprise PKI, Vault/HSM, or
an internal policy service.

Single-user installations do not need to know about the enterprise backplate. The
file-backed/default provider model remains sufficient.

## Command surface

```bash
queue module list [--json]
queue module explain class:NAME|asset:NAME|cap:NAME|provider:NAME
queue module help [class|asset|cap|provider|kind:NAME]
queue module configure provider NAME [--show|--path|--set KEY=VALUE ...]
queue module policy class|asset|cap|provider NAME
queue module acl set|remove KIND NAME OPERATION SUBJECT
queue module enable class|asset|cap|provider NAME
queue module disable class|asset|cap|provider NAME [--force]
```

`queue modules` is an alias for `queue module`.

## Provider configuration

User queue roots store provider module configuration at:

```text
~/.queuebash/policy/providers.d/NAME.env
```

System packaging may also provide site policy under:

```text
/etc/queuebash/policy/providers.d/NAME.env
```

The module command deliberately creates provider configuration as data. Provider
output is still normalized JSON/data and must never be executed as shell.

Example:

```bash
queue module configure provider gemini --set QUEUEBASH_PROVIDER_KIND=ai --set QUEUEBASH_AI_PROVIDER=gemini
queue module configure provider gemini --show
queue module policy provider gemini
```

## Module ACL handoff

`queue module acl` reserves the command surface for command-operation ACLs. It is
intended to be equivalent to the future/enterprise ACL form:

```bash
queue acl set module provider:gemini ai.ask BQ_AI_Users
queue acl remove module provider:gemini ai.ask BQ_AI_Users
```

Until the ACL subsystem is active, `queue module acl` reports the normalized
resource/action it would hand off and exits without changing policy.

## Policy rule

Enterprise tools may own the answer to whether a subject can perform an operation
on a module. bashqueues consumes that answer through the provider/ACL contract and
fails closed when the answer is missing, malformed, denied, or stale.
