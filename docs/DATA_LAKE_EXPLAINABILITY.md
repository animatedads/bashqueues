# Data lake explainability

The data lake helper explains dataset suitability using bounded facts: catalog
identity, dataset format, partition keys, classification labels, residency,
retention metadata, and whether sample access is disabled.

Provider helpers must never return shell commands or executable plans. Their
output is advisory evidence for queue policy, not a shell instruction source.
