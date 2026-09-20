# Inactive Accounts

Finds accounts nobody uses. Inactive employees are **disabled**, inactive guests are **removed**.
Unused accounts are an easy way in for attackers and still cost licenses.

Pipeline details: [Docs/InactiveAccounts.md](Docs/InactiveAccounts.md)

---

## Steps

1. Get every enabled account and its last sign-in from Entra
2. Skip anyone on the exclusion list (`ExcludeAccounts`) or the protected list (`ProtectedAccounts`): break-glass, service and VIP accounts
3. Mark as inactive:
   * Employees: no sign-in for `MemberInactiveDays` (default 90)
   * Guests: no sign-in for `GuestInactiveDays` (default 90)
   * Never signed in: counted from the day the account was created, so new hires aren't caught
4. An idle account that **holds an admin role** is never disabled automatically: it goes in the report as `AdminReview` for a human (an unused admin account is often break-glass, on purpose)
5. Plan: disable employees, remove guests
6. **Safety stop:** if more than `MaxPercentToDisable` (default 10%) of accounts look inactive, nothing is changed (usually means sign-in data is missing)
7. Save **before** snapshot
8. Disable (synced users in AD, cloud users in Entra) or remove guest
9. Save **after** snapshot
10. Write a report + CSV to `Reports/`
11. Alert if there's anything to review

Steps 7–9 only run with `-Apply`.

---

## Usage

Review only (recommended first, then weekly):
```powershell
.\InactiveAccounts\InactiveAccounts.ps1 -Client "ClientA"
```
Make the changes:
```powershell
.\InactiveAccounts\InactiveAccounts.ps1 -Client "ClientA" -Apply
```

---

## Notes

* Needs Entra ID P1 (for sign-in data) and Graph permissions `User.ReadWrite.All`, `AuditLog.Read.All`.
* Disabled accounts can be re-enabled. Removed guests can be restored for 30 days.
