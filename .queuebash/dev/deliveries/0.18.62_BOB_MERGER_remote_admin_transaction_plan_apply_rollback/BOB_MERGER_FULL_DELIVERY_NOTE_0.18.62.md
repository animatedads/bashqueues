# 0.18.62 BOB_MERGER remote-admin transaction plan/apply/rollback merge

Merged Bob10 remote-admin transaction plan/apply/rollback functionality onto the accepted 0.18.61 QBTEST wave1 base. The incoming patch carried an older 0.18.60 branch identity; Bob the Merger treated that as patch identity only and assigned the current merger line version 0.18.62.

Preserved boundaries: no generic editor, no arbitrary shell, no secret disclosure, no queue dispatch refactor. Secrets remain excluded from transaction plans. Rollback snapshots are local recovery records.
