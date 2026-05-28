# ACL provider contract

Version: 0.18.15

`bashqueues` core must not hard-code PAM, LDAP, Microsoft, IBM, keyrings, or local files into privileged command logic. Core asks an ACL provider a normalized question and enforces the normalized answer.

```text
Can subject X perform operation Y on resource Z in context C?
```

Providers return data, never shell. Providers never supply shell. The core command logic enforces the provider's normalized decision.

## Decision schema

```json
{
  "schema": "queuebash.acl_decision.v1",
  "provider": "file",
  "subject": "hc3",
  "operation": "job.submit",
  "resource": "*",
  "decision": "allow",
  "reason": "local user may submit jobs",
  "evidence": [
    {"type": "file_acl", "policy_file": "/home/hc3/.queuebash/policy/acl/file_acl.tsv", "line": 2}
  ],
  "ttl_seconds": 0,
  "cache_policy": "no-store",
  "fail_closed": false,
  "contract_only": false
}
```

Decision values:

```text
allow
deny
error
```

Privileged operations must fail closed on missing providers, malformed JSON, helper failure, or `decision=error`.

## Normalized operations

```text
job.submit
job.cancel
job.delete
queue.clear
queue.health.fix
profile.approve
profile.sign
profile.verify
trust-provider.add
trust-provider.revoke
class.manage
policy.override
module.configure
dev.extract
dev.patch
ai.ask
ai.context.queue_status
ai.context.job_metadata
```

## File ACL provider

0.18.15 makes the ACL provider contract real with a simple local file-backed provider. It is intended for single-user installs, test systems, and as a reference implementation for later LDAP/PAM/Microsoft/IBM providers.

Configuration:

```bash
QUEUEBASH_ACL_PROVIDER=file
QUEUEBASH_FILE_ACL_POLICY="$HOME/.queuebash/policy/acl/file_acl.tsv"
QUEUEBASH_FILE_ACL_DEFAULT=deny
```

System example:

```bash
QUEUEBASH_ACL_PROVIDER=file
QUEUEBASH_FILE_ACL_POLICY=/etc/queuebash/policy/acl/file_acl.tsv
QUEUEBASH_FILE_ACL_DEFAULT=deny
```

Canonical policy paths:

```text
~/.queuebash/policy/acl/file_acl.tsv
/etc/queuebash/policy/acl/file_acl.tsv
```

Policy TSV format:

```text
# subject<TAB>operation<TAB>resource<TAB>decision<TAB>reason
hc3	job.submit	*	allow	local user may submit jobs
hc3	ai.ask	*	allow	local user may ask AI
hc3	ai.context.queue_status	*	allow	local user may expose queue status
hc3	dev.patch	*	deny	dev patch requires explicit admin
*	profile.approve	*	deny	profile approval denied by default
```

Comments and blank lines are ignored. Malformed policy lines cause `decision=error`, `reason=file_acl_policy_malformed`, and `fail_closed=true`.

Matching rules are deterministic:

```text
subject exact beats subject *
operation exact beats operation *
resource exact beats resource *
first most-specific match wins
no active provider -> error/fail_closed
active file provider but no matching rule -> deny/fail_closed (`reason=no_matching_file_acl_rule`)
malformed file -> error/fail_closed (`reason=file_acl_policy_malformed`)
```

Specificity order is subject, then operation, then resource. If two rules have the same specificity, the first matching rule in the file wins.

## Command surface

Contract commands:

```bash
queue acl check SUBJECT OPERATION RESOURCE
queue acl check SUBJECT OPERATION RESOURCE --json
queue acl explain SUBJECT OPERATION RESOURCE
queue acl operations
queue acl set module provider:file job.submit hc3 '*'
queue acl set module provider:file job.submit hc3 '*' --decision deny --reason "maintenance freeze"
queue acl remove module provider:file job.submit hc3 '*'
```

LDAP/PAM/NSS/Microsoft/IBM commands remain contract handoffs until their provider releases exist:

```bash
queue acl set module provider:ldap job.submit cn=bashqueues-submitters,ou=groups,dc=example,dc=com
queue acl remove module provider:ldap job.submit cn=bashqueues-submitters,ou=groups,dc=example,dc=com
```

Module handoff commands remain aligned:

```bash
queue module help provider
queue module configure provider ldap --set LDAP_URI=ldaps://ldap.example.com
queue module policy provider ldap
queue module acl set provider ldap job.submit cn=bashqueues-submitters,ou=groups,dc=example,dc=com
```

## Provider/module families

```text
file_acl      single-user/default file-backed ACLs; implemented as QUEUEBASH_ACL_PROVIDER=file
ldap_acl      LDAP group/OU/role lookup; future provider
pam_account   PAM account/session validity; future provider
nss_identity  local/domain user identity resolution; future provider
```

0.18.15 implements only the local file ACL provider. It does not add global enforcement to every command path. Commands that explicitly call `queue acl check` or `queue acl explain` exercise the provider. Future releases can route privileged command decisions through the same contract.
