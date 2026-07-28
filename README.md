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
    "Domain": "contoso.local",
    "UPNSuffix": "@contoso.local",
    "DefaultOU": "OU=Employees,OU=Users,OU=Identity,DC=contoso,DC=local",
    "GroupsOU": "OU=Role-Based,OU=Security,OU=Groups,DC=contoso,DC=local",
    "DepartmentOU": "OU=Employees,OU=Users,OU=Identity,DC=contoso,DC=local",
    "UsernameFormat": "FirstLast",
    "DefaultLicense": "Microsoft365BusinessBasic",
    "DefaultDistributionList": "AllStaff",
    "DefaultGroups": ["GRP-AllStaff"],
    "LogPath": "Logs\\Onboarding.log",
    "DistributionLists": [
        "AllStaff",
        "Managers",
        "Finance",
        "IT",
        "Sales",
        "HR",
        "Marketing"
    ],
    "TenantDomain": "contoso.onmicrosoft.com",
    "TenantId": "00000000-0000-0000-0000-000000000000",
    "ClientId": "11111111-1111-1111-1111-111111111111",
    "CertThumbprint": "0000000000000000000000000000000000000000",
    "ADConnectServer": "CONTOSO-ADC01",
    "KeyVaultName": "contoso-kv-dev",
    "LicenseSkuId": "22222222-2222-2222-2222-222222222222",
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
