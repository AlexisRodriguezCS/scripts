# Security

How these scripts handle secrets and access. Short version: **no passwords anywhere, nothing secret in the repo, least privilege per script.**

---

## What is secret, and where it lives

| Thing | Secret? | Where it lives | Who can read it |
|---|---|---|---|
| App sign-in (Graph, Exchange, SharePoint) | **Yes** – certificate private key | Windows certificate store on the automation server, **non-exportable** | The service account (gMSA) and local admins |
| Certificate thumbprint | No (an ID) | Client config | – |
| Tenant ID, client (app) ID | No (IDs) | Client config | – |
| Teams webhook URL | **Yes** (anyone with it can post) | Vault (SecretManagement) | The service account |
| Any other API key | **Yes** | Vault | The service account |
| Service account password | – | **None**: gMSA, Windows rotates it automatically | – |
| New hire temp passwords and access passes | **Yes** | Memory only: shown once on screen or emailed to IT | Never logged, never in reports or the SharePoint list |
| Client configs | No secrets inside | `Config/Clients/` (gitignored) or `SCRIPTS_CONFIG_ROOT` | – |

---

## How it works

**1. Certificates, not client secrets**
The Entra app registration only has a certificate, never a client secret.
[`Setup/New-AutomationCertificate.ps1`](Setup/New-AutomationCertificate.ps1) creates the key on the server, marks it non-exportable
and grants read access to the service account only. Only the public key is uploaded to Entra.

**2. Vault references in config**
Configs never hold a secret. They hold a reference:

```json
"AlertWebhookUrl": "secret:ClientA-TeamsWebhook"
```

`Get-Config` fetches the value from the vault at run time (`Microsoft.PowerShell.SecretManagement`):

- **Lab:** SecretStore (encrypted, tied to the service account's profile). [`Setup/Set-AutomationSecret.ps1`](Setup/Set-AutomationSecret.ps1) stores values without them touching the command line.
- **Production:** Azure Key Vault, registered under the same vault name. No code changes.

**3. Secrets never reach the logs**
Every secret `Get-Config` loads is remembered, and `Write-Log` replaces it with `***` in every line, including error messages that echo a URL.

**4. Scanning**
CI runs [gitleaks](https://github.com/gitleaks/gitleaks) on every push and pull request across the full history.
Turn on GitHub **secret scanning + push protection** in the repo settings as a second net.

---

## Least privilege

Each client config has its own `ClientId`, so **each script can use its own app registration** with only what it needs:

| Script | Microsoft Graph (application) | Exchange | SharePoint | AD (delegated to the gMSA) |
|---|---|---|---|---|
| Onboarding | `User.ReadWrite.All`, `LicenseAssignment.ReadWrite.All`, `UserAuthenticationMethod.ReadWrite.All` (access pass) | Exchange.ManageAsApp + *Recipient Management* | – | Create users in the employee OUs, manage role groups |
| Mover / User Attributes | – | Exchange.ManageAsApp + *Recipient Management* | – | Write user attributes, manage role groups, move within employee OUs |
| Offboarding | `User.ReadWrite.All`, `LicenseAssignment.ReadWrite.All`, `DeviceManagementManagedDevices.PrivilegedOperations.All` | Exchange.ManageAsApp + *Recipient Management* | `Sites.FullControl.All` (OneDrive handoff) | Disable, reset password, manage groups, move to Disabled OU |
| Inactive Accounts | `User.ReadWrite.All`, `AuditLog.Read.All` | – | – | Disable users |
| Stale Devices | `DeviceManagementManagedDevices.ReadWrite.All`, `DeviceManagementManagedDevices.PrivilegedOperations.All` | – | – | – |
| Password Expiry | `Mail.Send` (limit to the sender mailbox with an application access policy) | – | – | Read users |
| Mailbox Quota | `Mail.Send` (limit to the sender mailbox) | *View-Only Recipients* | – | – |
| Audits | `User.Read.All`, `AuditLog.Read.All`, `Directory.Read.All`, `Application.Read.All`, `Organization.Read.All`, `Policy.Read.All`, `Domain.Read.All`, `RoleManagement.Read.Directory`, `IdentityRiskyUser.Read.All`, `Group.Read.All` | *View-Only Recipients* | – | Read users |
| Requests | `Sites.Selected` (only the HR site), `Mail.Send` (sender mailbox) | – | – | Unlock, reset password, manage `RequestableGroups` only |
| Incident Response | `User.ReadWrite.All`, `AuditLog.Read.All`, `UserAuthenticationMethod.Read.All` | *Mail Recipients* | – | Disable, reset password |

AD rights are **delegated on specific OUs**, not Domain Admin.

---

## Guard rails in the code

- **Protected accounts:** offboarding and role changes refuse admin accounts (AD `adminCount = 1`) and anyone in `ProtectedAccounts`, unless IT runs the script by hand with `-AllowProtected`. The HR request queue can never touch them.
- **Approval is verified, not trusted:** the request queue checks the list item's version history. The change to *Approved* must be made by someone in `Approvers`, and not by the person who submitted it.
- **Account collisions:** onboarding never reuses an existing account unless the Employee ID matches; otherwise it picks the next free username.
- **Dry run by default**, before/after snapshots of every change, and a safety stop on mass-disabling accounts.

---

## Rotation

| What | How often | Reminder |
|---|---|---|
| App certificate | 12 months (script default) | `Audits -Check AppCredentials` flags it 30 days before expiry |
| Webhook URLs / API keys | When someone with access leaves, or yearly | Update the vault entry; configs don't change |
| gMSA password | Automatic (30 days) | – |

---

## Data retention

Reports and before/after snapshots contain personal data (names, groups, managers), so they don't live forever:

| What | Kept | How |
|---|---|---|
| Reports, snapshots, access review sheets | 90 days (`-Days`) | [`Setup/Remove-OldReports.ps1`](Setup/Remove-OldReports.ps1), weekly scheduled task |
| Log files | Last 5 × 10 MB per script | `Write-Log` rotates automatically |
| Conditional Access backups | Kept (they are restore points, not personal data) | `Backups/ConditionalAccess/`, gitignored |
| Incident evidence | Kept until the incident is closed; delete by hand after | `Backups/Incidents/`, gitignored |
| Temp passwords | Never stored | Memory only |

Reports and logs are gitignored and never committed.

---

## Reporting a problem

Open a private security advisory on GitHub rather than a public issue.
