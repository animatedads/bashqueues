# Bob31 review: additional ooRexx examples

Inputs inspected:

- `oorexxTUI.zip` — mature text-mode UI experiment with a `WindowManager`, widgets, keyboard dispatch, logging and the DADT dynamic attribute helper.
- `oorexxserialized.zip` — custom runtime object serializer/deserializer examples, including collection handlers and object-reference tracking.

## Useful patterns adopted

### TUI package

The TUI code is useful as a style reference, especially:

- central manager object owns shared services and accepts child objects through a generic `add` method;
- key ideas are message-passing and duck-typing rather than brittle class coupling;
- `DynamicAttributeDataType` uses `UNKNOWN` to create lazy getters/setters at object scope.

For the BashQueues API this confirms the existing direction: keep the queue object small, expose results through `BQData`, and let `UNKNOWN` map JSON fields and command namespaces into ooRexx messages.

The full TUI framework is not included as a runtime dependency in the BashQueues API. It is old, broad, terminal-specific, and would make the API heavier than needed. Instead this drop adds a small status-panel example that borrows the usability idea without importing the full framework.

### Serialization package

The serializer package shows an ooRexx-native approach to preserving object graphs. It is useful, but not suitable as the default BashQueues result format because bashq now exports JSON consistently. JSON should remain the interchange format.

The practical adoption is therefore:

- keep `BQData~raw` and `BQCollection~makeArray` for callers that want to serialize using their own object serializer;
- add examples that persist queue snapshots as JSON/text rather than inventing a second queue data format;
- leave deep ooRexx object-graph serialization as a future optional adapter.

## Explicit non-adoption

The following are intentionally not included in the API package:

- banking/alchemy learning scripts;
- the full TUI framework;
- the full custom serializer framework.

They remain reference material for ooRexx idioms, not public BashQueues API surface.

## Next API direction

1. Keep the ooRexx API JSON-first and dependency-light.
2. Add small, practical examples only: status display, list/filter, submit/explain/cancel, and snapshot export.
3. After the ooRexx surface stabilises, mirror the same shape in Python:
   - `BashQueues.stats()` returns a dictionary-like object;
   - `BashQueues.list().json()` returns list-like result wrappers;
   - dynamic namespace chaining is optional in Python but should be available for parity.
