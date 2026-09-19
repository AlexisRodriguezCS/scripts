## Offboarding Module – Processing Pipeline

### Overview

This module processes a list of leaving users through a structured pipeline.
It uses the same pipeline object, step runner, retries, logging and report as onboarding.

---

## Processing Order

### 1. Import

**Function:** `Import-OffboardingCsv`

* Reads the CSV (`SamAccountName`, optional `Manager`)
* Wraps each row in a pipeline object

No data changes occur here.

---

### 2. Test

**Function:** `Test-OffboardingData`

* `SamAccountName` is required and must be AD-safe
* `Manager` is optional but must be a UPN
* Sets `Status` to `Valid` or `Invalid`

Invalid users are logged and skipped.

---

### 3. Lookup Identity

**Function:** `Get-OffboardingIdentity`

* Finds the user in AD (read-only, runs in dry run too)
* Stores:

  * `DistinguishedName`
  * `MemberOf`
  * `DisplayName`
  * `EntraUPN`
* Sets `Status` to `NotFound` if the account doesn't exist

---

### 4. Plan

**Function:** `New-OffboardingPlan`

* Builds the list of actions, in this order:

  * `DisableAccount`
  * `RevokeSessions`
  * `RemoveFromGroup` (one per group)
  * `MoveToDisabledOU`
  * `RemoveFromDistributionLists`
  * `ConvertMailbox`
  * `SetAutoReply`
  * `GrantMailboxAccess` (manager only)
  * `ShareOneDrive` (manager only)
  * `RemoveLicenses`
* Populates `.Plan`

Nothing is changed at this stage. In dry run the pipeline stops here.

---

### 5. Execute (`-Apply` only)

**Function:** `Start-Offboarding`

* Runs each plan action with retries and backoff
* Stops if the account can't be disabled
* Other failures are recorded and the rest of the plan still runs
* Sets `Status` to `Offboarded` or `Failed`

---

### 6. Report

**Function:** `New-Report` (shared)

Writes a report to `Reports/` with the plan results per user.

---

## Design Principles

* Disable first, cleanup after
* Convert the mailbox before removing the license (or the mailbox gets deleted)
* Every action is safe to re-run
* Group memberships are logged before removal so they can be restored

---

## Summary Flow

```
Import: read CSV

Test: validate SamAccountName / Manager

Lookup: find the user in AD

Plan: build the list of actions

Execute: disable, strip access, hand off mailbox + OneDrive, remove licenses

Report: log results, counts, pass/fail
```
