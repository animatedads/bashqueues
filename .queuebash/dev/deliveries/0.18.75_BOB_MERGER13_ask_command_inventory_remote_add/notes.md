# 0.18.75 BOB_MERGER13 ask command inventory remote add repair

Fixes stale ask command context where `queue remote --help` advertised `queue remote add`, but `queue ask --context commands` only exposed the older read-only remote command summary.

The dynamic command inventory now includes:
- expanded main `queue help` output,
- explicit `queue remote add` syntax in the main help summary,
- remote helper `--help` output when the helper is installed,
- a grounding rule naming `queue remote add` as an installed idiom when shown.

No provider, dispatch, provisioning, remote mutation, or live API behaviour changed. This only changes the context handed to `queue ask`.
