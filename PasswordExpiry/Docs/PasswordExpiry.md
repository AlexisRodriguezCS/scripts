## Password Expiry Module – Processing Pipeline

### Overview

Daily reminder emails with a sent-log so each reminder goes out exactly once.

---

## Processing Order

### 1. Get Data

**Function:** `Get-PasswordExpiryData`

* Enabled AD users, password can expire
* Expiry from `msDS-UserPasswordExpiryTimeComputed`

---

### 2. Test

**Function:** `Test-PasswordExpiry`

* `Expired`: already past
* `NotDue`: outside every reminder window
* `Invalid`: due but no email address
* `AlreadySent`: this reminder is in the sent-log
* `Due`: send it

The window is picked by "days left ≤ window", not "days left = window", so a missed run catches up.

---

### 3. Plan

**Function:** `New-PasswordExpiryPlan`

* `SendReminder`

---

### 4. Execute (`-Apply` only)

**Function:** `Start-PasswordExpiryReminder`

* Sends via Graph with retries (shared `Invoke-Plan`)
* Records `user | expiry date | window` in the sent-log

---

### 5. Report

* Everyone except `NotDue`

---

## Summary Flow

```
Get: users + expiry date

Test: which reminder, already sent?

Plan: send reminder

Execute: send, remember

Report: sent / skipped / flagged
```
