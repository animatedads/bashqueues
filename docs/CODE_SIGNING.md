# bashqueues code and plugin signing

bashqueues can sign and verify executable code and plugin material under a source,
installed, or queue root tree.  This covers the main engine plus plugin surfaces:

- `queuebash.sh`, installer/panel helper scripts, `bin/*.sh`, `bin/*.py`
- `assets.d/*.sh`
- `caps.d/*.sh`
- `reporters.d/*.sh`
- `classes/*.env`
- bundled policy env files

Signatures are stored under `.queuebash-signatures/` in the signed tree.  They are
sidecar env files containing the relative path, file SHA256, signer name, signing
public key fingerprint, embedded public key, and Ed25519 signature over the
canonical signing payload.

## Commands

Generate a signing key.  Code-signing keys use the same Ed25519 key store as
queue authorisation keys so an admin can manage them with existing tooling:

```bash
queue keygen code root
```

Trust a public key for code/plugin signatures:

```bash
queue code trust --public-key /root/.queuebash/keys/public/root.ed25519.pub.pem --shared
```

Sign a tree:

```bash
queue code sign --tree /usr/local/share/bashqueues --key root --signer-root /root/.queuebash
```

Verify a tree:

```bash
queue code verify --tree /usr/local/share/bashqueues --mode warn
queue code verify --tree /usr/local/share/bashqueues --mode enforce --json
```

Audit every signed component with category, signer fingerprint, signature path, and verification status:

```bash
queue code audit --tree /usr/local/share/bashqueues --mode warn
queue code audit --tree /usr/local/share/bashqueues --mode enforce --json
```

Aliases for the same component inventory are:

```bash
queue code components --tree /usr/local/share/bashqueues
queue code inventory --tree /usr/local/share/bashqueues --json
```

Plugin-focused alias:

```bash
queue plugins verify --tree /usr/local/share/bashqueues --mode enforce
```

## Policy

Shared policy lives at:

```text
/etc/bashqueues/policies.d/code-signing/default.env
```

Queue-local policy can live at:

```text
$QUEUEBASH_ROOT/policies.d/code-signing/default.env
```

Important settings:

```bash
QUEUEBASH_CODE_SIGNATURE_MODE="warn"       # off|warn|enforce
QUEUEBASH_PLUGIN_SIGNATURE_MODE="warn"     # defaults to code mode
QUEUEBASH_CODE_TRUSTED_PUBLIC_KEY_SHA256S="..."
```

`warn` is deliberately usable during rollout.  `enforce` is the production mode
when all local plugin trees have been signed and trusted.

## Override model

The requirement is explicitly overrideable by policy:

```bash
QUEUEBASH_CODE_SIGNATURE_MODE="off"
QUEUEBASH_PLUGIN_SIGNATURE_MODE="off"
```

An admin can make their own work legitimate by signing it with their own key and
adding that key fingerprint to `QUEUEBASH_CODE_TRUSTED_PUBLIC_KEY_SHA256S`.

## Runtime checks

When enabled, plugin loading checks signatures before sourcing asset, cap, and
reporter plugins.  In `warn` mode failures are reported but execution continues.
In `enforce` mode signature failures block the plugin from being sourced.
