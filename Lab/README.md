# Lab

Tools for the test domain and tenant only. **Never run these against production.**

---

## Build the lab

One VM is enough to demo everything that touches Active Directory.

### 1. New-LabVM.ps1 (on your PC)

Creates the Hyper-V VM. You need a Windows Server ISO first — the [free 180-day evaluation](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025) is fine.

```powershell
.\Lab\New-LabVM.ps1 -IsoPath "C:\Users\me\Downloads\server2025.iso"
```

Makes a Generation 2 VM (4 GB dynamic RAM, 2 CPUs, 60 GB disk) on the Default Switch, boots from the ISO, and turns off checkpoints — snapshots of a domain controller cause more problems than they solve.

Then install Windows in the VM window: **Desktop Experience**, Custom, whole disk.

### 2. Initialize-LabDomain.ps1 (inside the VM)

Run it twice — once to promote, once after the reboot.

```powershell
.\Initialize-LabDomain.ps1 -DomainName lab.local
```

| Run | What happens |
|---|---|
| First | Installs AD DS, creates the forest, asks for a recovery password, reboots |
| Second | Builds the OUs and groups, and writes `Config\Clients\Lab\*.json` pointing at them |

It creates the structure the config samples assume:

```
OU=Identity
├── OU=Users
│   ├── OU=Employees   ← new hires land here, one OU per department
│   └── OU=Disabled    ← leavers get moved here
└── OU=Groups          ← GRP-AllStaff and the GRP_ROLE_* groups
```

Both scripts are safe to re-run: anything that already exists is left alone.

### 3. Try it

```powershell
.\Onboarding\Onboarding.ps1 -Client Lab -FirstName Lisa -LastName Taylor -Title Accountant -Department Finance -Role Accountant
```

Dry run by default. Add `-Apply` to create her.

The cloud steps (license, distribution lists, mailbox) stay empty until you add Microsoft 365 tenant details to the config — a [free developer tenant](https://developer.microsoft.com/microsoft-365/dev-program) covers it.

---

## Reset-LabTenant.ps1

Deletes every member user not on `exclude-users.txt`, so onboarding can be tested again from scratch.

### Steps

1. Load the exclusion list (abort if missing or empty)
2. Ask for confirmation (`YES`) in live mode
3. Check Microsoft Graph is connected
4. Get all member users from Entra
5. For each user not excluded:
   * Hybrid (synced) user → delete from AD, Entra follows on next sync
   * Cloud user → delete from Entra
6. Print processed / skipped / errors

### Usage

Dry run:
```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"
.\Lab\Reset-LabTenant.ps1
```
Live:
```powershell
.\Lab\Reset-LabTenant.ps1 -LiveRun
```
