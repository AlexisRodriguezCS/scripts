# Name Change

Someone got married, divorced, or legally changed their name. Updates the name everyone sees, and optionally the username and email address, **without losing mail sent to the old address**.

Pipeline details: [Docs/NameChange.md](Docs/NameChange.md)

---

## Steps

1. Read the request (one person or a CSV)
2. Validate: username exists, something is actually changing, names have no characters AD rejects
3. Look up the user in AD, work out the new name, and check the new username isn't taken
4. Plan only what's different
5. Save a **before** snapshot
6. Rename: first name, last name, display name and the AD object name
7. Change the sign-in name (only if a new username was given): username and Microsoft 365 sign-in
8. Update email: the new address becomes the main one, **the old one stays as an alias**
9. Trigger an Entra Connect sync so Microsoft 365 sees it now instead of in 30 minutes
10. Save an **after** snapshot
11. Write a report to `Reports/`

Steps 5–10 only run with `-Apply`. Admin and VIP accounts are refused unless IT passes `-AllowProtected`.

---

## Usage

**Just the name** (keeps username and email — the safest option)
```powershell
.\NameChange\Set-UserName.ps1 -Client "ClientA" -SamAccountName jsmith -NewLastName "Johnson"
```

**Name, username and email**
```powershell
.\NameChange\Set-UserName.ps1 -Client "ClientA" -SamAccountName jsmith -NewLastName "Johnson" -NewUsername jjohnson
```

**Many people**
```powershell
.\NameChange\Set-UserName.ps1 -Client "ClientA" -Path .\NameChange\Data\test.csv
```

Both are a dry run (no changes). Add `-Apply` to make the changes.

---

## CSV

| SamAccountName | NewFirstName | NewLastName | NewUsername | KeepOldEmail |
|---|---|---|---|---|
| jsmith | | Johnson | jjohnson | Yes |
| mgarcia | Maria | | | Yes |

Leave a cell blank to keep what's there. `NewUsername` blank means they keep signing in the same way.

---

## What to tell the person

Changing the username changes how they sign in, so warn them first:

* They sign in with the **new** username from now on; the old one stops working
* Phones, saved passwords, mapped drives and VPN profiles holding the old username need updating
* Mail sent to the old address still arrives (it becomes an alias), but replies come **from** the new address

Not changing the username avoids all of that — the display name still updates everywhere, and it's the right call for most name changes.

---

## Notes

* Teams and Outlook can take a few hours to show the new name; the directory is updated immediately
* The old email address is kept unless the request says otherwise (`-DropOldEmail`, or `KeepOldEmail = No`)
* Safe to re-run: a rename that already happened is reported as already done, not repeated
* If something goes wrong, [Rollback](../Rollback/README.md) restores from the before-snapshot
