# 0.18.55 BOB_MERGER legacy QBTEST placeholder removed

Reviewer instruction: the old malformed QBTEST demonstration entry must not appear in accepted packages. It was previously useful as a detection demonstration, but future validation treats its presence as a blocker.

This repair removes that legacy placeholder from `queuebash.sh` help text and documentation, replacing it with a real-shaped `_queue_now` example. Runtime/provider/cloud behaviour is otherwise unchanged.
