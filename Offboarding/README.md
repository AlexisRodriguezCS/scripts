# Offboarding

Removes access for leaving users and hands their mailbox and OneDrive to their manager.

Pipeline details: [Docs/Offboarding.md](Docs/Offboarding.md)

---

## Steps

1. Read the CSV
2. Validate `SamAccountName` and `Manager` (skip invalid rows)
3. Look up the user in AD (skip if not found)
4. Build the plan of actions
5. Disable the AD account, reset the password to a random one, stamp the description
6. Sign the user out of all M365 sessions
7. Remove from every AD group (logged so it can be restored)
8. Move to the disabled OU
9. Remove from cloud distribution lists
10. Convert the mailbox to shared
11. Turn on out of office pointing to the manager (or `DefaultContact`)
12. Give the manager full access to the mailbox
13. Give the manager access to the OneDrive
14. Remove all M365 licenses
15. Write a report to `Reports/`

A **before** and **after** snapshot of the user (groups, licenses, mailbox, OU...) is saved to `Reports/Snapshots/` around steps 5–14.

Steps 5–14 only run with `-Apply`. Steps 12–13 only run when a `Manager` is given.

**Why this order:** lock them out first (5–6), then remove access (7–9), then hand off data (10–13). Licenses go last because removing them before the mailbox is converted would delete the mailbox.

---

## Usage

**One person** (also the emergency option: runs right away)
```powershell
.\Offboarding\Offboarding.ps1 -Client "ClientA" -SamAccountName johnsmith -Manager maryjohnson@contoso.com
```

**Many people**
```powershell
.\Offboarding\Offboarding.ps1 -Client "ClientA" -Path .\Offboarding\Data\test.csv
```

Both are a dry run (no changes). Add `-Apply` to make the changes.

**Scheduled** (e.g. last day at 5 PM): HR submits a Leaver request with a "When" time. See [Requests](../Requests/README.md).

---

## CSV

| SamAccountName | Manager |
|----------------|---------|
| johnsmith | maryjohnson@contoso.onmicrosoft.com |
| lisataylor | |

---

## Notes

* The disabled OU must stay in Entra Connect sync scope. If it's out of scope the Entra user is deleted, and the mailbox with it.
* Unlicensed OneDrives are kept per your retention policy; plan to archive or delete them after the manager is done.
* App registration needs: `User.ReadWrite.All`, `Directory.ReadWrite.All` (Graph), `Exchange.ManageAsApp` (Exchange), `Sites.FullControl.All` (SharePoint).
