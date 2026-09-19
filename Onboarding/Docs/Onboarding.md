## Onboarding Module – Processing Pipeline

### Overview

This module processes HR-provided onboarding data through a structured pipeline.
Each stage has a single responsibility. No stage performs multiple roles.

---

## Processing Order

### 1. Import

**Function:** `Import-OnboardingCsv`

* Reads raw CSV from HR
* Wraps each row in a pipeline object
* Initializes:

  * `Raw`
  * `Errors`
  * `Plan`
  * `Status` (`Pending`)

No data changes occur here.

---

### 2. Convert

**Function:** `ConvertTo-OnboardingStandard`

* Trims whitespace
* Standardizes casing
* Cleans input formatting

No validation occurs here.

Purpose: normalize data before evaluation.

---

### 3. Test

**Function:** `Test-OnboardingData`

* Validates required fields
* Checks for missing or invalid values
* Appends errors to `.Errors`
* Sets `Status` to `Valid` or `Invalid`

Invalid users are logged and skipped.

---

### 4. Policy

**Function:** `Set-OnboardingPolicy`

* Determines:

  * Distribution lists (department, managers, all staff)
  * Security groups (role based + defaults)
  * License

---

### 5. Plan

**Function:** `New-OnboardingPlan`

* Turns the policy into a list of actions:

  * `WaitForEntra`
  * `AddToGroup`
  * `AssignLicense`
  * `AddToDistributionList` (after the license, the mailbox only exists once licensed)
* Populates `.Plan`

No changes are made to Active Directory at this stage.

---

### 6. Build Identity

**Function:** `New-OnboardingIdentity`

* Generates:

  * `SamAccountName` (AD-safe characters, max 20)
  * `UserPrincipalName`
  * `EntraUPN`
  * `DisplayName`
  * `OU`

Transforms HR data into technical identity.

---

### 7. Create User (`-Apply` only)

**Function:** `New-OnboardingUser`

* Creates the AD user
* Sets `Status` to `Created`, or `AlreadyExists` if the account is already there

Then **`Invoke-EntraSync`** triggers one delta sync for all new users.

---

### 8. Execute (`-Apply` only)

**Function:** `Start-Onboarding`

* Runs each plan action with retries and backoff
* Waits for the user to show up in Entra first
* Stops if the user never syncs

---

### 9. Report

**Function:** `New-Report` (shared)

Writes a report to `Reports/` per user:

* Validation
* Policy
* Plan results
* Status

---

## Design Principles

* Separation of concerns
* No stage performs more than one responsibility
* No AD modification before validation
* Safe to re-run
* Internal helpers remain private

---

## Summary Flow

```
Import: read CSV

Convert: normalize fields

Test: validate required info

Policy: decide groups, DLs, licenses, other rules

Plan: build a list of actions from the policy

Build: generate system-ready attributes (samAccountName, UserPrincipalName, DisplayName, OU)

Create: create the AD user, sync to Entra

Execute: apply the plan (add to groups, DLs, assign licenses)

Report: log results, counts, pass/fail
```
