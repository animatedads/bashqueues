# 0.18.87 BOB_MERGER13 command JSON contract wave 1 merge

Merged command/JSON contract patch streams onto accepted 0.18.86 mobile-fetch base.

Inputs:
- bashqueues_0.18.87_command_json_contract_first_pass_patchset.zip
- bashqueues_0.18.87_BOB12_command_json_contract_first_fixes.patchset.zip
- bashqueues_0.18.87_BOB13_queue_command_json_contract_wave1.patchset.zip

Merge notes:
- Bob12 queuebash fixes were used as the base for env/draft JSON because they carried the more complete first-fixes implementation.
- Bob13 ACL/version/queue-user JSON additions, release identity, README/CHANGELOG, and scratchpad item were reconciled manually.
- Tests were normalized to avoid expensive full queue initialization in the smoke path.
