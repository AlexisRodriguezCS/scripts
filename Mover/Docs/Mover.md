## Mover Module – Processing Pipeline

### Overview

Handles role changes. Reuses onboarding's policy (who gets what) and compares it to what the user has today.
Only the difference is changed.

---

## Processing Order

### 1. Request

**Function:** `New-MoverRequest`

* Builds a pipeline object from a CSV row or from parameters

---

### 2. Test

**Function:** `Test-MoverData`

* Username, title, department, role required
* Department must be one of the configured `Departments` (uses the configured spelling)
* Sets `Status` to `Valid` or `Invalid`

---

### 3. Lookup Identity

**Function:** `Get-MoverIdentity`

* Finds the user and the new manager in AD
* Stores current title, department, manager and groups
* Sets `Status` to `NotFound` if the user doesn't exist

---

### 4. Policy

**Function:** `Set-OnboardingPolicy` (from onboarding)

* Same rules as a new hire in that role: groups, distribution lists

---

### 5. Plan

**Function:** `New-MoverPlan`

* Compares new vs current and plans only the changes:

  * `SetAttribute` (one per changed value)
  * `AddToGroup`
  * `RemoveFromGroup`
  * `MoveToDepartmentOU`
  * `SyncDistributionLists`

New access is added before old access is removed, and the OU move comes after group changes.

---

### 6. Execute (`-Apply` only)

**Function:** `Start-Mover`

* Before/after snapshot
* Runs the plan with retries (shared `Invoke-Plan`)
* Sets `Status` to `Moved` or `Failed`

---

### 7. Report

**Function:** `New-Report` (shared)

---

## Summary Flow

```
Request: one person or CSV

Test: validate the new role

Lookup: current state in AD

Policy: what the new role should have

Plan: difference between new and current

Execute: attributes, add groups, remove groups, move OU, swap DLs

Report: log results, pass/fail
```
