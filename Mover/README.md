# Mover (Role Change)

When someone changes job, department or manager: update their details and swap their access to match the new role.
Old role access is removed so people don't keep permissions from every job they've had.

Pipeline details: [Docs/Mover.md](Docs/Mover.md)

---

## Steps

1. Read the request (one person or a CSV)
2. Validate username, title, department, role, manager (skip invalid)
3. Look up the user and the new manager in AD
4. Work out the new access with the **same rules as onboarding**
5. Build the plan: only what's different from today
6. Save a **before** snapshot
7. Update title, department, manager
8. Add the new role groups
9. Remove the old role groups
10. Move to the new department OU
11. Swap department distribution lists (All Staff is never touched)
12. Save an **after** snapshot
13. Write a report to `Reports/`

Steps 6–12 only run with `-Apply`.

Only groups starting with `GRP_ROLE_` (configurable: `ManagedGroupPrefix`) are added or removed.
Anything granted by hand stays.

---

## Usage

**One person**
```powershell
.\Mover\Mover.ps1 -Client "ClientA" -SamAccountName lisataylor -Title "Finance Manager" -Department Finance -Role "Finance PowerUser" -Manager bobwilliams
```

**Many people**
```powershell
.\Mover\Mover.ps1 -Client "ClientA" -Path .\Mover\Data\test.csv
```

Add `-Apply` to make the changes.

---

## CSV

| SamAccountName | Title | Department | Role | Manager | EmploymentType |
|---|---|---|---|---|---|
| lisataylor | Finance Manager | Finance | Finance PowerUser | bobwilliams | Regular Full-Time |

`Manager` is the manager's username. Uses the client's `Onboarding.json` (same groups, lists and OUs).
