# Audits

Read-only checks for security, cost and compliance. **Nothing is ever changed.**
Each check writes a short report (problems first) and a full CSV for Excel.

Details: [Docs/Audits.md](Docs/Audits.md)

---

## Checks

| Check | What it finds | Why it matters |
|---|---|---|
| `Mfa` | Users with no MFA, admins on SMS/voice only | #1 way accounts get taken over; cyber insurance asks |
| `AdminRoles` | Who holds admin roles, too many Global Admins, guests with admin | More admins = bigger damage if one is hacked |
| `MailForwarding` | Mailboxes and inbox rules forwarding outside the company | First thing attackers set up after a break-in |
| `AppCredentials` | App secrets/certificates expired or expiring in 30 days | Expired secrets silently break integrations |
| `ConditionalAccess` | Backs up every Conditional Access policy to JSON; flags policies added, deleted or changed since the last backup | A changed policy can lock everyone out or quietly turn MFA off; the backup is the restore point |
| `Licenses` | Unused licenses, licenses on disabled/idle accounts, cost per department | Money: often 10–20% of licenses are wasted |
| `AccessReview` | One sheet per manager listing their team's access (Keep/Remove), users with no manager | Required by most audits (SOC 2, ISO 27001, HIPAA) |
| `OffboardingCheck` | Leavers who are still enabled, in groups, or licensed | Proves offboarding actually happened |

---

## Steps (every check)

1. Connect (read-only)
2. Collect the data
3. Flag anything risky, with the reason
4. Write `Audit_<Check>_<date>.txt` (NEEDS ATTENTION first) and `.csv`
5. Alert if anything was flagged

One check failing (e.g. missing permission) doesn't stop the others.

---

## Usage

```powershell
.\Audits\Audit.ps1 -Client "ClientA"                                   # all checks
.\Audits\Audit.ps1 -Client "ClientA" -Check Licenses, Mfa              # some checks
.\Audits\Audit.ps1 -Client "ClientA" -Check OffboardingCheck -Path .\leavers.csv
```

---

## Notes

* License prices aren't in Microsoft Graph; set them in config (`LicensePrices`, monthly per license).
* `Mfa` and sign-in based checks need Entra ID P1.
* Graph permissions: `User.Read.All`, `AuditLog.Read.All`, `Directory.Read.All`, `Application.Read.All`, `Organization.Read.All`. Exchange: `View-Only Recipients`.
