# Bob29 DNS/cache service coverage scratchpad

Base inspected: 0.18.123 BOB27 edge patch consolidation.

Carry-forward verified present before continuing: service_mesh, object_storage, api_gateway, package_registry, edge_cdn, load_balancer, license_manager, configuration_database.

Added fixture-first families: dns_service and cache_service.

Boundary: normalized JSON facts only; no live calls, credentials, provisioning, DNS mutation, cache flush/failover/scale mutation, or queue dispatch changes.
