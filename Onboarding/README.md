# Onboarding

Creates new users from an HR CSV: AD account, groups, distribution lists and M365 license.

Pipeline details: [Docs/Onboarding.md](Docs/Onboarding.md)

---

## Steps

1. Read the CSV
2. Clean up names, titles, departments (trim, casing)
3. Validate required fields (skip invalid rows)
4. Pick distribution lists, AD groups and license from department, title and role
5. Build the plan of actions
6. Generate username, UPN, display name and OU
7. Create the AD user with a random temp password (skip if it already exists)
8. Trigger an Entra Connect delta sync
9. Wait for the user to appear in Entra
10. Add to AD groups
11. Assign the M365 license (this creates the mailbox)
12. Add to distribution lists (waits for the mailbox to exist)
13. Write a report to `Reports/`
14. Show the temp passwords on screen, once

Steps 7–12 and 14 only run with `-Apply`. Temp passwords are never written to logs or reports, and users must change them at first sign-in.

---

## Usage

Dry run (no changes):
```powershell
.\Onboarding\Onboarding.ps1 -Client "ClientA" -Path .\Onboarding\Data\test.csv
```
Apply:
```powershell
.\Onboarding\Onboarding.ps1 -Client "ClientA" -Path .\Onboarding\Data\test.csv -Apply
```

---

## CSV

| FirstName | LastName | Title | Manager | Location | Department | Role | EmploymentType | StartDate |
|-----------|----------|-------|---------|----------|------------|------|----------------|-----------|
| Alex | Johnson | Systems Administrator | Mary Smith | New York | IT | Admin | Regular Full-Time | 2026-02-26 |

---

## Setup

One-time lab setup (department OUs, role groups, distribution lists):
```powershell
.\Onboarding\Setup\Initialize-OnboardingEnvironment.ps1 -Client "ClientA" -AdminUPN "admin@contoso.onmicrosoft.com"
```
