# User Attributes

Update a user's details in AD: title, department, manager, phone, office and more.
Only the values you give are changed. Everything else is left alone.
Changes sync to Microsoft 365 automatically (hybrid).

Pipeline details: [Docs/UserAttributes.md](Docs/UserAttributes.md)

---

## Steps

1. Read the request (one person or a CSV)
2. Validate: username, only allowed attributes, nothing empty or too long
3. Look up the user in AD (and the manager, if changing manager), and stop if the account is protected (admin or VIP)
4. Plan one change per value that is actually different
5. Save a **before** snapshot
6. Apply each change
7. Save an **after** snapshot
8. Write a report to `Reports/`

Steps 5–7 only run with `-Apply`. If nothing is different, nothing is changed (`NoChange`).

Admin and VIP accounts (`adminCount = 1`, or on the `ProtectedAccounts` list) are refused, so an HR request can't edit them. IT can override by running the script by hand with `-AllowProtected`.

---

## Usage

**One person**
```powershell
.\UserAttributes\Set-UserAttributes.ps1 -Client "ClientA" -SamAccountName jdoe -Title "Senior Accountant"
.\UserAttributes\Set-UserAttributes.ps1 -Client "ClientA" -SamAccountName jdoe -MobilePhone "312-555-0100" -Manager msmith -Apply
```

**Many people** (blank cells are skipped)
```powershell
.\UserAttributes\Set-UserAttributes.ps1 -Client "ClientA" -Path .\UserAttributes\Data\test.csv
```

---

## Attributes you can change

`Title`, `Department`, `Manager` (username), `Office`, `OfficePhone`, `MobilePhone`, `Company`, `EmployeeID`, `City`, `State`, `StreetAddress`, `PostalCode`, `Description`

The list lives in `Actions/Set-UserAttribute.ps1`.
