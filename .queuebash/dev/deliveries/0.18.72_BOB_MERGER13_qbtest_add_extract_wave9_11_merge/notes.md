# 0.18.72 Bob Merger 13 QBTEST merge notes

This patchset rebases Bob13 QBTEST coverage onto the 0.18.71 grid/energy/cost platform base. It includes only developer-tooling changes for `queue dev test qbtest extract` and `queue dev test qbtest add`, plus test-only embedded QBTEST comment blocks restored from the Bob13 wave9-wave11 line.

It deliberately excludes provider, cloud, dispatch, provisioning, remote-admin, and live API behaviour changes.
