# Mandatory Policy Assets

`CLASS_POLICY_MANDATORY_ASSETS` lets class-statement policy require asset
preflight checks for every job, independent of the selected class.

The important property is that these checks run in a separate mandatory pass and
are **not** bypassed by `queue exception add`. Normal class assets remain
exception-aware; mandatory policy assets do not.

## Policy syntax

Use a newline-delimited, tab-separated value in a class-statement policy file:

```bash
CLASS_POLICY_MANDATORY_ASSETS=$'path\texists\t/etc/queuebash/maintenance.ok\nsecaudit\tstring_safe\t${COMMAND_TEXT}'
```

Each line is:

```text
family<TAB>check<TAB>target<TAB>optional key=value params
```

Examples:

```bash
CLASS_POLICY_MANDATORY_ASSETS=$'path\texists\t/etc/queuebash/maintenance.ok'
```

```bash
CLASS_POLICY_MANDATORY_ASSETS=$'runnable\tpath\tbash,curl,jq'
```

`CLASS_POLICY_MANDATORY_ASSET_SPECS` is accepted as a compatibility alias, but
`CLASS_POLICY_MANDATORY_ASSETS` is the preferred name.

## Notes

- Mandatory assets are evaluated after the normal class assets.
- Mandatory assets are loaded from all active class-statement policies using the
  same merged policy model as emergency class/command blocks.
- Duplicate mandatory lines are de-duplicated during policy aggregation.
- Use stable targets. Do not rely on command-specific variables unless the policy
  guarantees that they are populated for every submission path.
