# Scripts

A collection of PowerShell automation scripts for Active Directory and M365 administration.

## Structure

```
scripts/
├── .github/workflows/      # CI/CD pipelines *(Planned)*
├── Config/                 # Environment configuration (domain, OU, licensing etc.)
├── Modules/Shared/         # Shared functions used across all scripts
├── Onboarding/             # User onboarding automation *(In progress)*
├── Offboarding/            # User offboarding automation *(Planned)*
└── Tests/                  # Tests *(Planned)*
```

## Scripts

### Onboarding
Automates new user creation end-to-end from a CSV input file. Handles AD account creation, group membership, distribution lists, and license assignment with built-in validation, retry logic, and structured logging.

### Offboarding
*(In progress)*

## Requirements

- PowerShell 5.1+
- ActiveDirectory module
- Exchange Management Shell (for distribution list management)
- Microsoft Graph / MSOL module (for license assignment)

## Configuration

Edit the files in `Config/` before running:

- `Shared.json` — domain, UPN suffix, default OU
- `Onboarding.json` — username format, default license, default groups
- `Offboarding.json` — disabled OU, retention policy

## Usage

```powershell
# Onboarding
.\Onboarding\Onboarding.ps1 -Path "C:\path\to\users.csv"
```

## CI/CD
*(In progress)*
