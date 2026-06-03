# 0.18.73 BOB_MERGER13 QBTEST installer complete merge

Base: `bashqueues_0.18.71_BOB_MERGER_grid_energy_cost_model_full_delivery.zip`.

Merged Bob13 QBTEST add/extract support and restored function-level QBTEST coverage from the Bob13 line. Added Claude's portable `qbtest_installer.sh` as a compatibility route for future/older QBTEST waves. The installer uses the target `queuebash.sh` implementation of `queue dev test qbtest add`, so insertion is governed by the current tree rather than by old patch offsets.

No runtime/provider/dispatch/provisioning/cloud/live API changes are intended.
