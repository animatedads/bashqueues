# VCS tenant contract

Bob26 adds a neutral version-control asset family so source-control systems are first-class bashqueue tenants even when they are not Git.

Existing `git:*` assets remain valid and preferred for Git-only classes such as `GITHUB_PUBLISH` and the current `DEPLOY_RELEASE` class. The new `vcs:*` assets are an abstraction layer for mixed estates and legacy systems: Git, Subversion, CVS, Mercurial, and Perforce.

## Asset facilities

`vcs:repo_exists` verifies that the target directory is a recognised working copy. `type=auto` detects `.git`, `.svn`, `CVS`, `.hg`, and Perforce config markers. A site can pin `type=git|svn|cvs|hg|p4` when auto-detection is not reliable.

`vcs:clean_tree` blocks admission when the VCS client reports pending edits, adds, deletes, conflicts, or unknown files. It uses the native read-only status command for each system and never mutates the checkout.

`vcs:branch` maps branch-like identity onto each VCS:

- Git and Mercurial use `require_branch=`.
- Subversion uses `require_url_contains=` because branch identity is usually a repository URL path such as `/trunk` or `/branches/release`.
- CVS uses `require_tag=` or `require_branch=` against the sticky tag marker in `CVS/Tag`.
- Perforce uses `require_stream=` or `require_client=` from `p4 client -o`.

`vcs:tool_available` lets a class fail clearly when a worker does not have the required client installed.

## Classes

`VCS_CHECKOUT` is a general source checkout/update class. It is parallel by default, gated by repository existence and client availability.

`VCS_RELEASE_GATE` is a serial release gate for mixed VCS estates. It requires repository existence, a clean tree, and the expected branch/tag/stream identity.

`VCS_LEGACY_SERIAL` is deliberately conservative for fragile legacy systems such as old CVS roots, old Subversion repositories, or Perforce installations where workspace/server locking needs a single queue tenant at a time.

## Helper

`bin/queue-vcs-detect` is a read-only helper that reports the likely VCS type for a path. It exists for admins, diagnostics, and class authoring; queue dispatch does not depend on it.


## Queue command surface

`queue vcs detect [PATH] [--json]` exposes the existing read-only `queue-vcs-detect` helper through the normal `queue` command surface. JSON output uses `queuebash.vcs.detect.v1` and reports the detected type, path, root, and marker.

`queue vcs types [--json]` lists supported tenant systems and emits `queuebash.vcs.types.v1` for scripts. This is deliberately diagnostic and read-only: it does not checkout, update, commit, tag, submit, or mutate workspace state.

`queue vcs probe [PATH] [--json] [--type TYPE] [--timeout SECONDS]` exposes `queue-vcs-probe` through the normal `queue` command surface. JSON output uses `queuebash.vcs.probe.v1` and reports the detected type, client availability, identity, revision, clean-tree summary, root, and marker. This facade is read-only and exists so operators can debug release/audit gates without knowing the helper path.

## Safety boundary

The VCS plugin is preflight-only. It does not run checkout, update, commit, merge, tag, submit, or revert operations. Those remain job payload responsibilities and continue to pass through the normal class, asset, sandbox, runtime cap, authorisation, and audit paths.

## Probe and reproducibility gate

`bin/queue-vcs-probe` extends the read-only helper surface with a normalised JSON probe:

```text
queue-vcs-probe --json --type auto /srv/src/project
```

It reports `queuebash.vcs.probe.v1` with the detected type, root marker, client availability, branch/tag/stream/client identity, observed revision/changelist/hash, and clean-tree summary when the native client is available. For old CVS trees it can still report metadata-only identity such as `HEAD` or the sticky tag even when the CVS client is absent.

The `vcs:identity` and `vcs:revision` assets build on the probe helper for reproducible gates. They are intentionally read-only and are suitable for audit or release admission where “whatever is checked out on the worker” is not good enough.

`VCS_CHANGESET_AUDIT` is the conservative class for that case. It serialises by audit name, requires repository existence and a clean tree, and optionally pins `QUEUEBASH_VCS_AUDIT_IDENTITY` and `QUEUEBASH_VCS_AUDIT_REVISION`.
