## User Activity Module – Processing Pipeline

### Overview

Read-only. Pulls from three sources, merges them into one timeline, then works out what the user is actually experiencing. The [README](../README.md) covers what it shows; this page covers how it decides.

---

## Processing Order

### 1. Collect

| Function | Source | Notes |
|---|---|---|
| `Get-SignInEvents` | Entra sign-in logs | Needs Entra ID P1; failures keep their error code |
| `Get-AuditEvents` | Entra audit logs | Password resets (self-service and admin), MFA changes, group changes |
| `Get-AdAccountEvents` | On-prem AD | Lockout state, password last set and expiry, plus event 4740 on `LockoutServer` for the device that caused a lockout |

Each source is wrapped on its own: a missing permission or a tenant without P1 loses that source, not the report. Everything becomes a common event shape through `New-ActivityEvent`, so the timeline sorts and prints uniformly.

---

### 2. Translate

**Function:** `ConvertTo-FriendlySignInError`

Entra returns numbers. The report shows words: `50126` → "Wrong password", `50053` → "Account locked", `50057` → "Account disabled", `53003` → "Blocked by Conditional Access", `50074` → "MFA not completed".

---

### 3. Summarise

**Function:** `Get-ActivitySummary`

The part that answers the ticket. It looks for the pattern behind most "my password doesn't work" calls:

> a password change, followed by sign-ins still failing with the **old** password

Two rules keep that honest:

* A password **change** event only counts if it really is one — matched on `(reset|change)\b.*password` or `password (set|reset|change)`
* Events whose text contains *failed* or *wrong* are excluded, so "wrong password (AD)" is never mistaken for a reset

When the pattern matches, the summary names the apps and device types still sending the old password (`Exchange ActiveSync on iOS (14x)`), because that is what has to be fixed — a phone mail app, a saved Wi-Fi or VPN profile, or a mapped drive.

It also reports: currently disabled, currently locked out and from which device, password expired, blocked by Conditional Access and which policy, MFA not completed, and the last successful sign-in.

---

### 4. Report

**Function:** `Invoke-UserActivityReport`

* `Reports/UserActivity_<user>_<date>.txt` — summary first, then the timeline newest first
* `Reports/UserActivity_<user>_<date>.csv` — the same events for Excel
* The summary also prints to the screen, so the help desk usually doesn't open the file at all

---

## Environments

`Get-UserActivity.ps1` has two parameter sets. A client whose config says `"Environment": "OnPrem"` uses `-SamAccountName` and never touches Graph; everyone else uses `-UserPrincipalName`. This is the only script that reads `Environment` today — see the roadmap for making it repo-wide.
