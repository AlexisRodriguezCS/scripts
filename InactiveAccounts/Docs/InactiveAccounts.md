## Inactive Accounts Module – Processing Pipeline

### Overview

Reviews every enabled account against sign-in activity. Review-only by default.

---

## Processing Order

### 1. Get Data

**Function:** `Get-InactiveAccountData`

* All enabled users from Graph with `signInActivity`
* Last sign-in = latest of interactive, non-interactive and successful sign-ins

---

### 2. Test

**Function:** `Test-InactiveAccount`

* `Excluded`: on the exclusion list
* `Inactive`: over the threshold for members or guests
* `Active`: everyone else

---

### 3. Plan

**Function:** `New-InactiveAccountPlan`

* Members → `DisableAccount`
* Guests → `RemoveGuest`

---

### 4. Safety Stop

**Function:** `Invoke-InactiveAccountReview`

* If more than `MaxPercentToDisable` of accounts are inactive, nothing runs and everyone is flagged

---

### 5. Execute (`-Apply` only)

**Function:** `Start-InactiveAccountCleanup`

* Before/after snapshot
* Synced users disabled in AD (AD is the source), cloud users in Entra
* Retries via shared `Invoke-Plan`

---

### 6. Report

* Text report (only inactive accounts) + CSV for Excel

---

## Summary Flow

```
Get: every enabled account + last sign-in

Test: active / inactive / excluded

Plan: disable members, remove guests

Safety: stop if too many look inactive

Execute: disable / remove

Report: who, why, what happened
```
