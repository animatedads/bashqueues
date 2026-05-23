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


## Asset hints

QueueManager can show target and parameter hints:

```bash
queue mgr hints
queue mgr hint net:http_status
queue mgr hint runnable:script
queue mgr picker
```

Interactive class creation also supports `?` at the asset-family prompt.

Hints are advisory and do not replace plugin contract validation. Plugins remain the source of truth for whether an asset check passes.


## Plugin-published hints

QueueManager hinting is driven by asset helpers.

A helper may define:

```bash
queue_asset_hints() {
    cat <<'EOF'
net:http_status	target=URL or host	params=timeout=5	example=queue_class_shared_asset net http_status "https://github.com" timeout=5	notes=Checks HTTP status.
EOF
}
```

Fields are tab-separated. Supported metadata keys are `target`, `params`, `example`, and `notes`.
