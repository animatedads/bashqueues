# Vector database explainability

The vector database helper explains why a vector collection or index may be
considered suitable for advisory use. Evidence is limited to normalized JSON:
collection identity, index dimensions, metric type, embedding-source policy,
retention metadata, and whether live embedding is disabled by default.

Provider helpers must never return shell commands. queuebash consumes facts
through policy/assets/classes, not by executing provider-supplied text.
