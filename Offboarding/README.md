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
7. Remove company data from their phones and laptops (Intune retire; personal data untouched)
8. Remove from every AD group (logged so it can be restored)
9. Move to the disabled OU
10. Remove from cloud distribution lists
11. Remove from Teams, Microsoft 365 groups and cloud security groups (and so from those teams' SharePoint sites). If they were a team's **only owner**, the manager becomes owner first; with no manager, the report flags the team
12. Convert the mailbox to shared
13. Turn on out of office pointing to the manager (or `DefaultContact`)
14. Give the manager full access to the mailbox
15. Give the manager access to the OneDrive
16. Hide them from the address book (people can't pick them for new email; the manager still has the mailbox)
17. Remove all M365 licenses
18. Write a report to `Reports/`

A **before** and **after** snapshot of the user (groups, licenses, mailbox, OU...) is saved to `Reports/Snapshots/` around steps 5–17.

Steps 5–17 only run with `-Apply`. Steps 14–15 only run when a `Manager` is given.

**Why this order:** lock them out first (5–7), then remove access (8–11), then hand off data and hide them (12–16). Licenses go last because removing them before the mailbox is converted would delete the mailbox.

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
