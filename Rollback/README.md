# Restore from Snapshot

Puts a user back the way a **before** snapshot recorded them. For mistakes: the wrong person offboarded, a role change that has to be undone, attributes changed by accident.

Every script that changes a user (onboarding excluded) saves `Reports/Snapshots/<Script>_<date>/<user>_before.json` first. This script uses that file.

---

## Steps

1. Read the snapshot
2. Look up the user as they are today
3. Plan **only the difference**:
   1. Re-enable the account (if it was enabled)
   2. Restore title, department, manager, description
   3. Add back groups they had; remove groups they didn't have
   4. Move back to the original OU (last, because moving changes the account's path)
4. Run the plan with retries
5. Write a report, with a **DO BY HAND** list for what AD can't restore:
   * Licenses (reassign in Microsoft 365)
   * Mailbox type (convert back from shared)

Step 4 only runs with `-Apply`. If the user already matches the snapshot: `NoChange`.

---

## Usage

Preview:
```powershell
.\Rollback\Restore-FromSnapshot.ps1 -SnapshotFile .\Reports\Snapshots\Offboarding_20260919_101500\jdoe_before.json
```
Restore:
```powershell
.\Rollback\Restore-FromSnapshot.ps1 -SnapshotFile .\Reports\Snapshots\Offboarding_20260919_101500\jdoe_before.json -Apply
```

Snapshots are kept 90 days (see [SECURITY.md](../SECURITY.md)). A user deleted from AD can't be restored this way; use the AD Recycle Bin.

**No alerts.** The scheduled scripts alert because nobody is watching them. This one is run by hand, so the result is on screen and in `Reports/RestoreReport_*.txt`; anything the restore couldn't do (licenses, mailbox type) is listed under **DO BY HAND**.
