## Stale Devices Module – Processing Pipeline

### Overview

Cleans up Intune devices that stopped checking in: retire first, delete the record once the device is clearly gone. Read-only until `-Apply`.

---

## Processing Order

### 1. Collect

**Function:** `Get-DeviceData`

* Every Intune managed device from Graph, with `lastSyncDateTime`, owner, OS, serial, compliance and `managementState`
* One pipeline object per device (same shape as the people scripts, so the shared report and retry engine work unchanged)

---

### 2. Test

**Function:** `Test-StaleDevice`

* Devices named in `ExcludeDevices` → `Excluded` (kiosks, conference room PCs, spares in a drawer)
* No check-in for `RetireAfterDays` (default 90) → `Stale`
* Never checked in at all → `Stale`, counted as the oldest possible
* Anything else → `Active`

---

### 3. Plan

**Function:** `New-StaleDevicePlan`

* `DaysSinceSync ≥ DeleteAfterDays` (default 180) → **DeleteRecord**: the device is gone, remove the Intune record
* Otherwise → **Retire**: company data, apps and mail profiles are removed the next time it checks in; personal data is untouched
* A device already showing `retirePending` isn't sent a second retire (idempotent)

---

### 4. Safety stop

**Function:** `Invoke-StaleDeviceCleanup`

* If more than `MaxPercentToChange` (default 20%) of all devices would change, nothing runs
* A number that high nearly always means sync data is wrong, not that every laptop vanished
* The devices are still reported, marked `Failed`, with the reason

---

### 5. Execute

**Actions:** `Invoke-DeviceRetire`, `Remove-DeviceRecord`

* Run through the shared `Invoke-Plan` retry engine (3 attempts, growing backoff)
* Status ends as `Retired`, `Deleted` or `Failed`

---

### 6. Report

* `Reports/StaleDevicesReport_<date>.txt` — problems first
* `Reports/StaleDevices_<date>.csv` — full list for Excel
* Alert if anything failed, and a second alert on a review-only run when there is something to approve

---

## Config

| Key | Default | Meaning |
|---|---|---|
| `RetireAfterDays` | 90 | No check-in for this long → retire |
| `DeleteAfterDays` | 180 | No check-in for this long → delete the record |
| `MaxPercentToChange` | 20 | Safety stop |
| `ExcludeDevices` | — | Device names never touched |

---

## Permissions

Graph application permissions: `DeviceManagementManagedDevices.ReadWrite.All`.
