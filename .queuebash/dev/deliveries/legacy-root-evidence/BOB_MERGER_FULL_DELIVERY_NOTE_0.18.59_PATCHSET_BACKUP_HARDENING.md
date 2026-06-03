# 0.18.59 Bob Merger: patchset apply backup hardening

Merged Bob12 patchset apply backup hardening onto the accepted 0.18.58 Bob Merger remote-admin full-delivery line.

Key behaviour:
- generated apply_patchset.sh supports --help without running preconditions
- --check performs precondition checks only
- --json gives bounded JSON output
- --backup-dir DIR is supported
- apply creates a pre-apply backup manifest before overwriting modified target files
- new files are recorded in backup metadata for rollback deletion rather than content backup

Merge route:
- source queuebash.sh first
- queue dev patchset inspect --patchset PATCH --json
- apply_patchset.sh --check --json TARGET
- apply_patchset.sh --json TARGET

Preserved:
- 0.18.58 remote-admin ACL-gated policy commands
- 0.18.57 Cerebras, GPU provisioning templates, dev validate/scope gates, scratchpad required fields
- 0.18.56 QBTEST example escaping and timeout helper
- fake malformed QBTEST placeholder remains absent
- assets.d/net_usage.sh remains absent
