## Incident Response Module – Processing Pipeline

### Overview

The "someone got phished" playbook, run in seconds instead of from memory. **Evidence is collected before anything is changed**, because containment destroys the traces of what the attacker did.

---

## Processing Order

### 1. Who

**Function:** `Get-IncidentIdentity`

* Looks the account up in Entra
* Records whether it is synced from on-prem AD: a synced account must be disabled and reset **in AD**, not in the cloud, or the next sync undoes it

---

### 2. Evidence (always, dry run included)

**Function:** `Save-IncidentEvidence`

Written to `Backups/Incidents/<user>_<date>/` — outside `Reports/`, so the 90-day cleanup never deletes it.

| File | What it holds | Why |
|---|---|---|
| `inbox-rules.json` | Every inbox rule with its targets | Attackers add rules to forward, delete or hide mail |
| `sign-ins.csv` | Sign-ins for the last `-SignInDays` days: time, IP, app, country, result | Shows where they got in from |
| `mfa-methods.json` | Registered MFA methods and when they were added | Attackers register their own so they can come back |

---

### 3. Plan

**Function:** `New-IncidentPlan`

Order matters: lock the attacker out first, then stop data leaving.

1. **DisableAccount**
2. **ResetPassword** — random, nobody is told it
3. **RevokeSessions** — existing tokens keep working until revoked, so a disabled account can still be in use without this
4. **RemoveForwarding** — if the mailbox forwards outside
5. **DisableInboxRule** — one per suspicious rule: forwards, redirects, deletes, or files mail into a folder nobody reads (RSS Feeds, Conversation History, Archive, Junk)

Rules are **disabled, not deleted**: they stay as evidence.

---

### 4. Contain (`-Apply` only)

* A before/after snapshot is written into the same evidence folder
* Every step runs through the shared retry engine
* One failing step doesn't stop the rest: a partly contained account beats an open one
* Status ends as `Contained` or `Failed`

---

### 5. Follow up

The report ends with what only a person can judge:

* MFA methods added during the window — check they're really the user's
* Sign-ins from more than one country
* Check sent items and anything shared recently
* Give the user a new password or a Temporary Access Pass once you're sure the attacker is out

An alert is **always** sent, contained or not: an incident is never routine.

---

## Usage

```powershell
# Evidence only, changes nothing
.\IncidentResponse\Invoke-CompromisedAccountResponse.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com

# Contain
.\IncidentResponse\Invoke-CompromisedAccountResponse.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com -Apply
```

---

## Permissions

Graph: `User.ReadWrite.All`, `AuditLog.Read.All`, `UserAuthenticationMethod.Read.All`. Exchange: `Exchange.ManageAsApp`.
