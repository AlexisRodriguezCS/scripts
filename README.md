# Scripts

PowerShell automation for Active Directory and Microsoft 365 administration.

---

## Structure

```
scripts/
├── .github/workflows/      # CI/CD pipelines (planned)
├── Config/                 # Environment configuration (domain, OU, licensing)
├── Modules/Shared/         # Shared functions used across all scripts
├── Onboarding/             # User onboarding automation (in progress)
└── Tests/                  # Pester tests
```

---

## Onboarding

End-to-end user provisioning from CSV input.

Includes:
- Active Directory account creation
- Group membership assignment
- Distribution list membership
- License assignment
- Validation, retry handling, structured logging

---

## Requirements

- PowerShell
- ActiveDirectory module
- Exchange Management Shell (distribution groups)
- Microsoft Graph PowerShell SDK (licensing)
---

## Configuration

- Config/Shared.json — domain, UPN suffix, default OU
- Config/Onboarding.json — username format, default groups, licenses


```json
{
    "Domain": "corp.local",
    "UPNSuffix": "@corp.local",
    "DefaultOU": "OU=Employees,OU=Users,OU=Identity,DC=corp,DC=local",
    "GroupsOU": "OU=Role-Based,OU=Security,OU=Groups,DC=corp,DC=local",
    "DepartmentOU": "OU=Employees,OU=Users,OU=Identity,DC=corp,DC=local",
    "UsernameFormat": "FirstLast",
    "DefaultLicense": "Microsoft365BusinessBasic",
    "DefaultDistributionList": "AllStaff",
    "DefaultGroups": ["GRP-AllStaff"],
    "LogPath": "Logs\\Onboarding.log",
    "DistributionLists": ["AllStaff", "Managers", "Finance", "IT", "Sales", "HR", "Marketing"],
    "TenantDomain": "exampletenant.onmicrosoft.com",
    "TenantId": "11111111-2222-3333-4444-555555555555",
    "ClientId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
    "CertThumbprint": "A1B2C3D4E5F60718293A4B5C6D7E8F9012345678",
    "ADConnectServer": "ADConnectServer",
    "KeyVaultName": "KeyVaultName",
    "LicenseSkuId": "00000000-0000-0000-0000-000000000000",
    "UsageLocation": "US"
}
```
---

## Data.csv Example:


| FirstName | LastName | Title                | Manager       | Location | Department | Role | EmploymentType | StartDate   |
|----------|----------|----------------------|--------------|----------|------------|------|----------------|------------|
| Alex     | Johnson  | Systems Administrator | Mary Smith   | New York | IT         | Admin | Full-Time      | 2026-02-26 |
| Emma     | Williams | Accountant            | Bob Brown    | Chicago  | Finance    | Accountant | Full-Time | 2026-03-23 |

---

## Usage
Dry run (no changes):
```powershell
 .\Onboarding\Onboarding.ps1 -Client "ClientA"
```
Apply (real execution):
```powershell
 .\Onboarding\Onboarding.ps1 -Client "ClientA" -Apply
```
---

## CI/CD

In progress.
