## User Attributes Module – Processing Pipeline

### Overview

Changes AD attributes safely: validated, only what differs, one logged action per value, before/after snapshot.

---

## Processing Order

### 1. Request

**Function:** `New-UserAttributesRequest`

* Builds a pipeline object from a CSV row or from parameters
* Keeps only the attributes that were given a value

---

### 2. Test

**Function:** `Test-UserAttributesData`

* Username valid
* At least one attribute
* Only allowed attributes, nothing empty, max 128 characters
* Manager must be a username

---

### 3. Lookup Identity

**Function:** `Get-UserAttributesIdentity`

* Finds the user with all managed attributes
* Resolves the manager's username to the DN AD needs
* `NotFound` / `Invalid` if either doesn't exist

---

### 4. Plan

**Function:** `New-UserAttributesPlan` → `Get-UserAttributeChanges`

* One `SetAttribute` per value that is different (case-sensitive)
* Nothing different → `NoChange`

---

### 5. Execute (`-Apply` only)

**Function:** `Start-UserAttributesUpdate`

* Before/after snapshot
* Runs the plan with retries (shared `Invoke-Plan`)

---

### 6. Report

**Function:** `New-Report` (shared)

---

## Summary Flow

```
Request: one person or CSV

Test: validate values

Lookup: current values in AD

Plan: only what's different

Execute: set each value

Report: old -> new, pass/fail
```
