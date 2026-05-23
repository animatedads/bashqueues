# QueueManager

QueueManager is the text-mode operational front end for bashqueues.

It is intentionally separate from the core engine:

```text
queuebash.sh   core queue engine
queuemgr.sh    manager menus and class creation
```

## Launch

```bash
queue mgr
queue manager
queue qm
```

## Menus

```text
Jobs
Classes
Assets
Workers / Health / Trace
```

The manager mostly routes to existing trusted commands:

```bash
queue list
queue show
queue explain
queue assets
queue assets explain
queue classes list
queue classes explain
queue health
queue dispatch-trace
```

## Scriptable class creation

```bash
queue mgr class-create CLASS \
  --no-parallel \
  --max-concurrent 1 \
  --exclusive-claim some:claim \
  --shared-asset family check "target" key=value \
  --exclusive-asset family check "target" key=value
```

The output class uses record format only:

```bash
queue_class_shared_asset net http_status "https://github.com" timeout=5
queue_class_exclusive_claim "github_publish:slot"
```

Legacy `CLASS_SHARED_ASSETS`, `CLASS_EXCLUSIVE_ASSETS`, and `CLASS_ASSETS` are not generated.
