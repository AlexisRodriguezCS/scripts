# Offboarding

Removes access for leaving users and hands their mailbox and OneDrive to their manager.

Pipeline details: [Docs/Offboarding.md](Docs/Offboarding.md)

---

## Steps

1. Read the CSV
2. Validate `SamAccountName` and `Manager` (skip invalid rows)
3. Look up the user in AD (skip if not found)
4. Build the plan of actions
5. Disable the AD account, reset the password, stamp the description
6. Remove from every AD group (logged so it can be restored)
7. Move to the disabled OU
8. Revoke all M365 sign-in sessions
9. Convert the mailbox to shared
10. Turn on out of office pointing to the manager (or `DefaultContact`)
11. Give the manager full access to the mailbox
12. Give the manager access to the OneDrive
13. Remove all M365 licenses
14. Write a report to `Reports/`

Steps 5–13 only run with `-Apply`. Steps 11–12 only run when a `Manager` is given.

---

## Usage

Dry run (no changes):
```powershell
.\Offboarding\Offboarding.ps1 -Client "ClientA" -Path .\Offboarding\Data\test.csv
```
Apply:
```powershell
.\Offboarding\Offboarding.ps1 -Client "ClientA" -Path .\Offboarding\Data\test.csv -Apply
```

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
