# Microsoft-domain asset families

Queuebash includes Microsoft-oriented asset helpers for Linux-hosted hybrid automation. They are normal asset plugins and are listed by `queue assets list` / `queue assets list --json` without running network probes.

Families included:

- `msad` — Active Directory LDAP bind, Kerberos ticket, and group membership checks.
- `entra` — Entra JWT/Graph token checks.
- `msfs` — SMB/CIFS mountability and mounted-path RW permission checks.
- `mscloud` — SharePoint and OneDrive checks through Microsoft Graph.
- `exchange` — Exchange Online mailbox and explicit opt-in test-mail checks.
- `teams` — Teams presence and explicit opt-in webhook checks.
- `msdns` — AD-integrated DNS record checks using `dig`.
- `msca` — CRL and OCSP reachability checks.
- `winrm` — WinRM / pywinrm connectivity and simple command checks.
- `azure` — Azure Resource Manager resource, VM power state, and storage account checks.
- `vault` — Azure Key Vault secret and secret-version checks.

Side-effect rule:

- `teams:webhook_alive` refuses to post unless `allow_post=1` is supplied.
- `exchange:send_test_mail` refuses to send unless `allow_send=1` is supplied.

Secret rule:

Do not commit real passwords, bearer tokens, SAS tokens, or webhook URLs in class files. Prefer environment files under `/run`, operator-owned secrets, or short-lived tokens.
