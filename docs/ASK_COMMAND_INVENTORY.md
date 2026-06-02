# queue ask command inventory grounding

`queue ask` builds a bounded command context before invoking an AI provider.

As of 0.18.76 the command inventory is no longer limited to the compact top-level `_queue_help` text. It also includes discovered `Usage: queue ...` strings from the installed `queuebash.sh` tree and helper scripts. This is intended to prevent stale answers such as claiming `queue remote add` or `queue assets show` is missing when the installed command surface already exposes those commands.

The command context remains advisory and redacted. It should ground syntax, not execute operator actions.

The asset context also includes text-scanned bundled asset facility lines, such as `grid_energy:price_below`, `grid_energy:carbon_below`, and `grid_energy:negative_price`, without sourcing plugins during ask-context construction.

Validation targets include:

```bash
queue dev test qbtest --file queuebash.sh --function _queue_ai_usage_inventory_text --json
queue dev test qbtest --file queuebash.sh --function _queue_ai_command_inventory_text --json
queue dev test qbtest --file queuebash.sh --function _queue_ai_asset_inventory_text --json
```
