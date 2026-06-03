# 0.18.83 BOB_MERGER13 dev merge-plan manifest normalization

Merged Bob2's manifest-normalization repair onto the accepted 0.18.82 dev merge-plan integration base.

The nightmare fixture now produces a plan across five logical patchsets, including two patchsets nested inside the Bob10 outer zip. It reports same-path collisions across docs/tests_merge_planning.md, merge_test.py, and merge_test.sh, and same-function conflicts around the Bob-specific functions and main_test_function. It also detects 0.0.1/0.0.2 release identity overlap and keeps it classified as ledger overlap rather than an automatic runtime conflict.

Scope remains read-only planning only. No automatic conflict resolution or merge apply is introduced.
