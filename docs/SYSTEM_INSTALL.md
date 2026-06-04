# System installation

`install-system.sh` installs bashqueues for all users from a checked-out or unpacked release tree.  It is intended for root use on normal Linux distributions, including openSUSE Tumbleweed.

The installer deliberately uses a temporary private bashqueues queue to run its privileged installation steps.  This dogfood queue lives under `/tmp` and is removed when the install succeeds, so existing root queue jobs are not dispatched by accident.

## Basic install

```bash
sudo ./install-system.sh
```

This installs:

- `/usr/local/share/bashqueues/queuebash.sh`
- bundled `assets.d`, `caps.d`, `classes`, `policies.d`, `docs`, `bin`, `systemd`, and tests under `/usr/local/share/bashqueues/`
- `/usr/local/bin/queue`, a non-interactive wrapper that sets `QUEUEBASH_ALLOW_NONINTERACTIVE=1`, sources the system copy, and executes `queue "$@"`
- `/usr/local/bin/queuemgr`, a compatibility symlink to the queue manager shim
- `/etc/profile.d/bashqueues.sh`, so new interactive shells get the `queue` function
- shared policy templates under `/etc/queuebash/policies.d` without overwriting existing site policy files

After installation, open a new shell or run:

```bash
source /etc/profile.d/bashqueues.sh
queue version
```


## Canonical system policy root

The active system policy root is:

```text
/etc/queuebash/policies.d
```

`install-system.sh --dryrun`, `queue-policy-wizard --scope system --dryrun --json`, root signer policy setup, code-signing policy setup, and remote-listener policy verification must all report this same tree. The older plural `/etc/bashqueues/policies.d` path is legacy documentation/history only and must not be used for new system policy writes.

## Shell function vs installed wrapper

Before system install, `queue` is a shell function and is available only in the shell where `queuebash.sh` has been sourced. That is suitable for interactive development, but it is not enough for scripts, cron, `timeout`, CI, or systemd units.

After system install, the installer creates a non-interactive wrapper, normally:

```text
/usr/local/bin/queue
```

The wrapper sets `QUEUEBASH_ALLOW_NONINTERACTIVE=1`, sources the installed system copy, and then runs `queue "$@"`. New interactive shells may also source `/etc/profile.d/bashqueues.sh` to get the shell function.

## Cron bridge

Cron bridge installation is opt-in:

```bash
sudo ./install-system.sh --with-cron
```

This installs the ticker and crontab wrapper, then enables the systemd timer when `systemctl` is available:

```bash
systemctl status bashqueues-cron.timer
bashqueues-crontab -l
queue cron tick --dryrun
```

The installer does not replace `/usr/bin/crontab`.

### Cron spool permissions

When `--with-cron` is used, the installer creates or repairs:

```text
/var/spool/bashqueues_cron
```

with mode `1777`. This allows a normal user to create or update their own bashqueues crontab using:

```bash
queue cron edit
```

while the sticky bit prevents users from deleting or replacing crontabs owned by other users. System-wide cron entries still belong under `/etc/bashqueues_cron.d` and should be managed by root.


## Root authorisation key

By default, the installer makes sure root has an Ed25519 authorisation signing key under:

```text
/root/.queuebash/keys/private/root.ed25519.pem
/root/.queuebash/keys/public/root.ed25519.pub.pem
```

It then installs root's public key into the shared class-statement policy if the policy does not already declare a root signer:

```text
/etc/queuebash/policies.d/class-statement/default.env
```

Existing keys and existing non-empty policy signer lines are preserved.  Use `--force-root-key` only when deliberately rotating the local root signing key.

Useful options:

```bash
sudo ./install-system.sh --no-root-key
sudo ./install-system.sh --force-root-key
sudo ./install-system.sh --lock-policy
sudo ./install-system.sh --prefix /usr/local
sudo ./install-system.sh --dryrun
```

`--lock-policy` changes the edited shared policy file to mode `0444` after installing the public key.  Root can still unlock and edit it later, but normal users cannot alter it.

## Safety behaviour

The installer refuses to run unless it is root.  Installation steps are submitted to an isolated temporary queue after setting `QUEUEBASH_ALLOW_NONINTERACTIVE=1`, then `queue run` processes that queue.  If any installation job lands in `failed`, `pol_blocked`, or `interrupted`, the installer prints the job/log paths and exits non-zero.
