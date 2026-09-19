# Scripts

[![PowerShell CI](https://github.com/AlexisRodriguezCS/scripts/actions/workflows/ci.yml/badge.svg)](https://github.com/AlexisRodriguezCS/scripts/actions/workflows/ci.yml)

PowerShell automation for Active Directory and Microsoft 365 administration.

Built for a **hybrid** environment: users live in on-prem Active Directory and sync to Entra ID with Entra Connect; licenses, mailboxes and OneDrive are in Microsoft 365.

```
On-prem AD ──(Entra Connect sync)──► Entra ID ──► Exchange Online / OneDrive / Licenses
  accounts, groups, OUs                                 mailboxes, DLs, files
```

---

## Structure

```
scripts/
├── .github/workflows/      # CI: lint (PSScriptAnalyzer) + tests (Pester)
├── Config/Clients/         # Per-client config (gitignored)
├── Modules/Shared/         # Logging, config, errors, step runner, report
├── Onboarding/             # New user provisioning from HR CSV
├── Offboarding/            # Leaver deprovisioning + handoff to manager
├── Lab/                    # Test tenant tools
└── Tests/                  # Pester tests
```

---

## Scripts

| Script | What it does |
|--------|--------------|
| [Onboarding](Onboarding/README.md) | AD account, groups, distribution lists, M365 license |
| [Offboarding](Offboarding/README.md) | Disable, strip access, shared mailbox, out of office, OneDrive to manager, remove licenses |
| [Lab](Lab/README.md) | Reset the test tenant |

---

## How it works

Both pipelines share the same engine (`Modules/Shared`):

**Dry run by default**
- Nothing changes without `-Apply`
- Dry run still validates, looks up and plans, so you see exactly what would happen

**Validate → Plan → Execute**
- Every row is validated before anything touches AD or M365
- Bad rows are skipped and reported, the rest keep going
- Each user gets a plan (list of actions) that is logged before it runs

**Retries**
- Each action has its own retry count and delay (e.g. waiting for Entra sync retries longer than a group add)
- Backoff grows each attempt, with jitter so parallel runs don't retry in lockstep
- Errors are classified (Network, Throttle, Auth, Conflict, Dependency) and flagged retryable or not

**Idempotent (safe to re-run)**
- Checks before acting: user already exists, already in group, license already assigned, mailbox already shared
- No duplicate accounts, memberships or licenses if a run is repeated
- Each pipeline step records that it completed, so it won't run twice for the same user
- A failed run can simply be run again

**Logging**
- Every line tagged with a per-user correlation ID, so one user's journey can be followed through the log
- Levels: DEBUG / INFO / WARN / ERROR
- Objects are logged as JSON
- Step timings recorded per user

**Flags anything that breaks**
- A user that can't be found, fails validation, or has an action fail after all retries is marked
- Every report starts with a **NEEDS ATTENTION** section listing those users and exactly what failed and why
- The run keeps going for everyone else; one bad user doesn't stop the batch
- Exit code 1 if anything was flagged, so a scheduler or pipeline shows the run as failed

**Reporting**
- Report per run in `Reports/`: validation, plan, result of every action, final status, totals

---

## Requirements

- PowerShell 7
- ActiveDirectory module (RSAT)
- ExchangeOnlineManagement
- Microsoft.Graph
- PnP.PowerShell (offboarding only)
- An Entra app registration with a certificate (app-only auth)

---

## Configuration

One folder per client: `Config/Clients/<Client>/Onboarding.json` and `Offboarding.json`.

Onboarding.json
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
    "DistributionLists": ["AllStaff", "Managers", "Finance", "IT", "Sales", "HR", "Marketing"],
    "TenantDomain": "contoso.onmicrosoft.com",
    "TenantId": "00000000-0000-0000-0000-000000000000",
    "ClientId": "11111111-1111-1111-1111-111111111111",
    "CertThumbprint": "0000000000000000000000000000000000000000",
    "ADConnectServer": "CONTOSO-ADC01",
    "LicenseSkuId": "22222222-2222-2222-2222-222222222222",
    "UsageLocation": "US"
}
```

Offboarding.json
```json
{
    "DisabledOU": "OU=Disabled,OU=Users,OU=Identity,DC=contoso,DC=local",
    "DefaultContact": "helpdesk@contoso.com",
    "AutoReplyMessage": "{Name} is no longer with the company. Please contact {Contact}.",
    "LogPath": "Logs\\Offboarding.log",
    "TenantDomain": "contoso.onmicrosoft.com",
    "SharePointAdminUrl": "https://contoso-admin.sharepoint.com",
    "TenantId": "00000000-0000-0000-0000-000000000000",
    "ClientId": "11111111-1111-1111-1111-111111111111",
    "CertThumbprint": "0000000000000000000000000000000000000000"
}
```

---

## Tests

```powershell
Invoke-Pester ./Tests
```

AD, Graph, Exchange and PnP cmdlets are mocked, so tests run anywhere (including CI) without a tenant.
