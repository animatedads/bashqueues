# 0.18.61 BOB_MERGER QBTEST wave1 embedded coverage merge

This package merges Claude/Bob12 QBTEST wave1 onto the accepted 0.18.60 IBM/OCI cloud enablement base.

The patchset was additive in intent: 0.18.60 already contained the IBM/OCI provider files carried in the patchset, so those entries were already-applied. The material queuebash.sh change is the addition of embedded QBTEST blocks.

Boundary: QBTEST blocks are developer-command comments only. They do not execute during normal sourcing, dispatch, provider checks, class checks, or asset evaluation.
