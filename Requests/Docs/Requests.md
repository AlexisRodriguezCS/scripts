## Requests Module – How It Works

### Overview

A SharePoint list is the front door. The queue script is the back office.
The same scripts IT runs by hand do the work; the queue only translates.

```
HR fills in list ──► Approval ──► Queue (every 15 min) ──► Onboarding / Mover / Offboarding / UserAttributes
       ▲                                                              │
       └──────────────── Status + Result written back ◄───────────────┘
```

---

## Processing Order

### 1. Read

**Script:** `Invoke-RequestQueue.ps1`

* All list items with `Status = Approved`
* Items with a future **When** (`EffectiveDate`) are skipped until then

---

### 2. Claim

**Function:** `Set-RequestStatus`

* `Processing` before anything runs, so overlapping runs can't double-process

---

### 3. Translate

**Function:** `ConvertTo-RequestRow`

* Form fields → the row each script already understands (same as a CSV row)

---

### 4. Run

**Function:** `Invoke-Request`

* `New hire` → `Invoke-UserOnboarding`
* `Role change` → `Invoke-UserMover`
* `Leaver` → `Invoke-UserOffboarding`
* `Update info` → `Invoke-UserAttributesUpdate`
* Turns the script's result into one plain sentence for HR

---

### 5. Write Back

* `Done` or `Needs attention` + result
* Temp passwords emailed to `TempPasswordRecipient`, never stored in the list
* Alert if anything needs attention

---

## Why a SharePoint list (not a custom website)

* HR already has it; works in Teams and on phones
* Sign-in, permissions and version history come free with Microsoft 365
* No server to host, patch or secure (a website that can disable accounts is a big target)
* Power Automate adds approvals with no code
