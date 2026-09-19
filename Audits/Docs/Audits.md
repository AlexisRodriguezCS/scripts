## Audits Module – How It Works

### Overview

Every check is a function that returns **findings**. A finding is one row:

| Field | Meaning |
|---|---|
| `Check` | Which audit |
| `Name` | User, app, role or license |
| `Detail` | What was found |
| `Flagged` | `true` = needs attention |
| `Reason` | Why it was flagged, in plain words |

`Export-AuditReport` turns findings into a text summary (flagged first) and a CSV.
`Invoke-Audit` runs the chosen checks, one at a time, and keeps going if one fails.

---

## Checks

### Mfa – `Get-MfaAudit`

* Source: Graph authentication registration report
* Flag: no MFA registered; admin with only SMS/voice/email

### AdminRoles – `Get-AdminRoleAudit`

* Source: Graph directory roles + members
* Flag: more than `MaxGlobalAdmins` (default 4); guest account with a role

### MailForwarding – `Get-MailForwardingAudit`

* Source: Exchange mailboxes + inbox rules
* Flag: forwarding or inbox rule sending mail to a domain that isn't ours

### PrivilegedAccess – `Get-PrivilegedAccessAudit`

* Source: Graph role definitions + active and eligible role schedule instances (PIM)
* Only powerful roles (Global, Privileged Role, Security, Exchange, SharePoint, User, Application, Intune, Hybrid Identity admins...)
* Flag: standing (`Assigned`, no end date) assignment, except `BreakGlassAccounts`
* Listed, not flagged: PIM-activated and eligible assignments

### RiskyUsers – `Get-RiskyUserAudit`

* Source: Entra ID Protection risky users (needs Entra ID P2)
* Flag: every user at risk or confirmed compromised, with a next step based on the risk level

### Groups – `Get-GroupHygieneAudit`

* Source: Graph groups (cloud only; synced groups are managed in AD), owners, members
* Labels each as Team, Microsoft 365 group, distribution list or security group
* Flag: no owner; no members for more than 30 days

### SharedMailboxes – `Get-SharedMailboxAudit`

* Source: Exchange shared mailboxes, mailbox permissions (FullAccess), recipient permissions (SendAs)
* Flag: sign-in not blocked on the shared mailbox; access held by a disabled account; nobody has access

### EmailSecurity – `Get-EmailSecurityAudit`

* Source: verified domains from Graph (skips `*.onmicrosoft.com`), public DNS
* Flag SPF: missing, more than one record, `+all`, `?all`
* Flag DMARC: missing, `p=none` (monitor only)
* Flag DKIM: no `selector1` / `selector2` CNAME (how Microsoft 365 publishes DKIM keys)

### ConditionalAccess – `Get-ConditionalAccessAudit`

* Source: Graph Conditional Access policies (raw JSON, all pages)
* Saves `Backups/ConditionalAccess/policies_<date>.json` every run (outside `Reports/`, so the 90-day cleanup keeps them)
* Compares with the previous backup by policy ID and `modifiedDateTime`
* Flag: new policy, changed policy (and state change, e.g. enabled → report-only), deleted policy
* First run just saves a baseline

### AppCredentials – `Get-AppCredentialAudit`

* Source: Graph app registrations (secrets + certificates)
* Flag: expired, or expires within `CredentialWarningDays` (default 30)

### Licenses – `Get-LicenseAudit`

* Source: Graph subscribed SKUs + users
* Flag: unused paid licenses; licenses on disabled accounts or accounts idle for `InactiveDays`
* Extra: monthly cost per department

### AccessReview – `Get-AccessReview`

* Source: AD users under `DefaultOU` with manager + groups
* Output: one CSV per manager with a blank `Decision` column (Keep / Remove)
* Flag: users with no manager

### OffboardingCheck – `Get-OffboardingCheck`

* Source: HR leavers CSV, AD, Graph
* Flag: still enabled, still in groups, still licensed
