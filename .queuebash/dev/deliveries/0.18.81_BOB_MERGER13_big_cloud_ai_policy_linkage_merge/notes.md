# 0.18.81 BOB_MERGER13 great big cloud/AI policy linkage merge

Inputs:
- 0.18.80 BOB_MERGER13 deterministic class inference full delivery
- 0.18.80 BOB10 queue cloud broker front patchset
- 0.18.81 BOB10 cloud broker policy reference linkage patchset
- 0.18.80 BOB11 AI broker policy links patchset

Merge method:
- Treated md5/version overlaps as expected multi-lane merge noise.
- Inserted cloud broker queuebash functions at function/dispatcher level.
- Copied non-conflicting docs, providers, policies, tests, fixtures and helper updates.
- Merged scratchpad by item id.
- Moved all root delivery records to .queuebash/dev/deliveries/legacy-root-evidence/.

Boundaries preserved: no live cloud API calls, no provisioning/destruction, no queue dispatch refactor beyond additive queue cloud front routing, no job lifecycle binding, no AI live call posture change.
