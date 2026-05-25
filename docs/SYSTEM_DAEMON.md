# bashqueues system daemon

The system daemon is the root-owned, multi-user control loop for installations
where bashqueues is replacing cron or acting as the normal background queue
runner.

It does not run user payloads as root.  It quickly scans known user queue roots
(`/home/*/.queuebash` by default) and, for each queue found, delegates to that
queue owner to run:

```bash
queue daemon --once --min-workers 1
```

The per-user daemon/sentinel performs only cheap control-plane work:

- remove dead detached-worker PID files
- mark definitely stale running jobs as interrupted
- apply the shared/admin policy gate to pending jobs
- evaluate deadline monitor/panic assets
- start at least the configured number of detached user workers when that user
  has due/dependency-ready pending work

It does not run class asset preflight directly and it does not launch payloads in
the root process.

## Commands

```bash
sudo queue system-daemon --once
sudo queue system-daemon --interval 30
sudo queue system-daemon --interval 30 --detach
sudo queue system-daemon --once --dryrun
sudo queue system-daemon --once --include-root
```

`queue daemon` remains the per-user control loop. `queue system-daemon` is the
root multi-user wrapper around it.

## System install

The system installer can install and enable the service:

```bash
sudo ./install-system.sh --with-daemon
```

To combine cron replacement with the background queue daemon:

```bash
sudo ./install-system.sh --with-cron --with-daemon
```

The cron timer submits jobs. The system daemon notices due pending jobs and
starts user workers as required.
