# QBTEST portable installer

`qbtest_installer.sh` is a compatibility bridge for QBTEST waves produced from a different source line.

It does not patch `queuebash.sh` directly. Instead it sources the target file and calls the target tree's own command:

```bash
queue dev test qbtest add --file FILE --function NAME --b64 PAYLOAD
```

Usage:

```bash
bash qbtest_installer.sh --file queuebash.sh
bash qbtest_installer.sh --file queuebash.sh --force
```

Default mode skips blocks that already exist. `--force` asks the target tree to replace existing blocks. The script reports added, existing, and failed insertions, and exits non-zero if any insertion fails.

This delivery treats the installer as a developer/test migration helper only. It must not change queue runtime behaviour, provider behaviour, dispatch, provisioning, or live API posture.
