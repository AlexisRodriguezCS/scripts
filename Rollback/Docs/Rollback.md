## Rollback Module – Processing Pipeline

### Overview

Puts a user back the way a **before** snapshot recorded them. Every script that changes a user writes one of those snapshots first, so the undo is a diff between "then" and "now".

---

## Processing Order

### 1. Read the snapshot

**Function:** `New-RestorePlan`

* Loads `Reports/Snapshots/<Script>_<date>/<user>_before.json`
* Throws if it holds no AD section: there is nothing to restore from
* Loads the user as they are **today** — the plan is the difference, not a blind replay

---

### 2. Plan (order matters)

1. **EnableAccount** — first, so nothing else is spent on a disabled account
2. **SetAttribute** — title, department, manager, description, via the shared `Get-UserAttributeChanges`, so only values that actually differ are touched
3. **AddToGroup / RemoveFromGroup** — membership back to exactly what the snapshot held
4. **MoveToOU** — last, because moving changes the DN every earlier step used

Empty values in the snapshot are skipped: AD can't "set" a value to nothing.

---

### 3. Things AD can't undo

Listed in the report under **DO BY HAND**, never attempted:

* **Licenses** — reassign in Microsoft 365; the snapshot records which SKUs were held
* **Mailbox type** — converting a shared mailbox back to a user mailbox needs a license and a person's judgement

---

### 4. Execute

* Runs through the shared `Invoke-Plan` retry engine
* Status ends as `Restored`, `NoChange` or `Failed`
* Report: `Reports/RestoreReport_<date>.txt`

---

## Limits

* A user **deleted** from AD can't be restored this way — use the AD Recycle Bin, then run this to put their groups and attributes back
* Snapshots are kept 90 days (see [SECURITY.md](../../SECURITY.md))
* No alerts: this is run by hand with someone watching the output, unlike the scheduled scripts

---

## Usage

```powershell
# Preview
.\Rollback\Restore-FromSnapshot.ps1 -SnapshotFile .\Reports\Snapshots\Offboarding_20260919_101500\jdoe_before.json

# Restore
.\Rollback\Restore-FromSnapshot.ps1 -SnapshotFile .\Reports\Snapshots\Offboarding_20260919_101500\jdoe_before.json -Apply
```
