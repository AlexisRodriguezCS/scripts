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
6. Generate username, UPN, display name and OU, and look the manager up in AD
7. Create the AD user with a random temp password, job title, department, office, company and manager (skip if it already exists)
8. Trigger an Entra Connect delta sync
9. Wait for the user to appear in Entra
    * Optional: create a **Temporary Access Pass** (one-time sign-in code for day one, valid from 8:00 on the start date) when `UseTemporaryAccessPass` is on
10. Add to AD groups
11. Assign the M365 license (this creates the mailbox)
12. Add to distribution lists (waits for the mailbox to exist)
13. Write a report to `Reports/`
14. Show the temp passwords on screen, once

Steps 7–12 and 14 only run with `-Apply`. Temp passwords and access passes are never written to logs or reports; temp passwords must be changed at first sign-in.

---

## Usage

**One person**
```powershell
.\Onboarding\Onboarding.ps1 -Client "ClientA" -FirstName Alex -LastName Johnson -Title "Accountant" -Department Finance -Role Accountant -Manager "Mary Smith"
```

**Many people**
```powershell
.\Onboarding\Onboarding.ps1 -Client "ClientA" -Path .\Onboarding\Data\test.csv
```

Both are a dry run (no changes). Add `-Apply` to make the changes.

---

## CSV

| FirstName | LastName | Title | Manager | Location | Department | Role | EmploymentType | StartDate |
|-----------|----------|-------|---------|----------|------------|------|----------------|-----------|
| Alex | Johnson | Systems Administrator | Mary Smith | New York | IT | Admin | Regular Full-Time | 2026-02-26 |

**Manager** can be a full name or a username. If nobody in AD matches (or two people share the name), the account is still created and the report says the manager wasn't set.

---

## Setup

One-time lab setup (department OUs, role groups, distribution lists):
```powershell
.\Onboarding\Setup\Initialize-OnboardingEnvironment.ps1 -Client "ClientA" -AdminUPN "admin@contoso.onmicrosoft.com"
```
