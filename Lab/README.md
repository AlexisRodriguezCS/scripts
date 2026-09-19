# Lab

Tools for the test tenant only. **Never run these against production.**

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
