## Name Change Module – Processing Pipeline

### Overview

A rename is riskier than an attribute change: it touches the account's own name (CN), the sign-in name, and the email address every outside contact has. This script does it in an order that never leaves the account half-renamed, and never silently drops mail.

---

## Processing Order

### 1. Request

**Function:** `New-NameChangeRequest`

* Builds a pipeline object from a CSV row or from parameters
* `KeepOldEmail` defaults to **true**: mail sent to the old address has to keep arriving

---

### 2. Test

**Function:** `Test-NameChangeData`

* Username valid, and something is actually being changed
* Names can't contain `, \ # + < > ; " =` — the characters AD rejects in an object name
* A new username has to fit the 20-character SamAccountName limit

---

### 3. Lookup Identity

**Function:** `Get-NameChangeIdentity`

* Loads the user with `GivenName`, `Surname`, `DisplayName`, `proxyAddresses` and `adminCount`
* Admin and VIP accounts are refused unless IT passes `-AllowProtected`
* Only the parts given are changed: a blank first name keeps the current one
* **The new username must be free.** If someone else already has it, the request is `Invalid` — two accounts fighting over one username is a much worse problem than a rename that didn't happen
* The UPN suffix is taken from the account's existing UPN, so multi-domain tenants keep their domain

---

### 4. Plan

**Function:** `New-NameChangePlan`

| Action | When |
|---|---|
| `RenameAccount` | The first name, last name or display name differs (compared case-sensitively, so a capitalisation fix counts) |
| `ChangeLogonName` | A new username was given |
| `UpdateEmail` | A new username was given (the address follows the username) |
| `SyncToEntra` | Anything is changing |

Nothing different → `NoChange`, and the account is not touched.

---

### 5. Execute

**Function:** `Start-NameChange` → shared `Invoke-Plan`

`RenameAccount` is the **stop-on-failure** step: every later action uses the renamed object, so if the rename fails nothing else runs.

| Action | What it does |
|---|---|
| `Rename-UserAccount` | Sets `GivenName`, `Surname` and `DisplayName`, then `Rename-ADObject` for the CN. It updates the DN it holds in memory, because renaming the object changes the path every later step needs |
| `Set-UserLogonName` | Sets `SamAccountName` and `UserPrincipalName` together. Returns `AlreadyRenamed` if a previous run did it, so re-running is safe. Logs a **warning**: the old username stops working the moment this runs |
| `Update-UserEmailAddress` | Rewrites `proxyAddresses`: the new address becomes `SMTP:` (primary), the old primary becomes `smtp:` (alias). In a hybrid tenant Exchange Online reads these from AD, so this is where the change belongs |
| `Invoke-EntraSync` | Triggers a delta sync. Only 2 attempts — if it fails the scheduled cycle picks the change up anyway |

Before and after snapshots are written to `Reports/Snapshots/NameChange_<date>/`, so [Rollback](../../Rollback/README.md) can undo the whole thing.

---

## Why the old email address is kept

Dropping it looks tidy and breaks things quietly: every external contact, mailing list, invoice portal and saved contact card still points at the old address. Mail to it bounces, and nobody tells the person — they just stop hearing from people. Keeping it as an alias costs nothing: new mail goes out from the new address, old mail still arrives.

`-DropOldEmail` exists for the rare case where the address must not exist any more.

---

## Not covered

* **Cloud-only users** — this writes to AD. A cloud-only tenant needs `Update-MgUser`; see the Environment work in the roadmap
* **Teams and Outlook caches** — the directory updates immediately, clients can take a few hours
* **Old certificates or signatures** holding the old name
