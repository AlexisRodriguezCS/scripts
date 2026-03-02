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

Does not stop execution.
Invalid objects continue through the pipeline with errors attached.

---

### 4. Build Identity

**Function:** `Build-UserIdentity`

* Generates:

  * `SamAccountName`
  * `UPN`
  * `Email`
  * `DisplayName`
* Ensures uniqueness

Transforms HR data into technical identity.

---

### 5. Plan

**Function:** `Resolve-OnboardingPlan`

* Determines:

  * Target OU
  * Security groups
  * License assignment
* Populates `.Plan`

No changes are made to Active Directory at this stage.

---

### 6. Execute

**Function:** `Invoke-OnboardingExecution`

* Creates AD user
* Assigns groups
* Applies licensing

Execution only occurs if:

* `.Errors` is empty
* User does not already exist

---

### 7. Report(WIP)

Returns structured results per user:

* Username
* Status
* Errors

Allows export to CSV or logging system.

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

Build: generate system-ready attributes (samAccountName, UserPrincipalName, DisplayName, OU)

Plan: compare Policy to current AD/state; build a plan of actions

Execute: apply the plan (create user, add to groups, assign licenses)

Report: log results, counts, pass/fail
```
