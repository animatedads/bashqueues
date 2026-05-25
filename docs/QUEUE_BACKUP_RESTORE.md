# Queue backup and restore

bashqueues is filesystem-backed, so backup is a consistent archive of the queue root. The backup command refuses to snapshot while jobs are in `running` unless `--force` is supplied.

```bash
queue backup create /secure/backups/bashqueues-$(date +%F).tar.gz
queue backup /secure/backups/bashqueues-latest.tar.gz
```

Restore is deliberately namespaced under `queue backup restore` so it cannot be confused with job undelete/restore.

```bash
queue backup restore /secure/backups/bashqueues-latest.tar.gz --to /tmp/restored-queue
```

By default restore requires `--to` and refuses to overwrite an existing destination unless `--force` is supplied. To promote a restored queue, inspect it first and then set `QUEUEBASH_ROOT` or copy it into place during a maintenance window.
