# Compromised Account Response

The "someone got phished" playbook as one command. IT runs it by hand, the moment a compromise is suspected.

Pipeline details: [Docs/IncidentResponse.md](Docs/IncidentResponse.md)

---

## Steps

1. Look up the user in Entra (cloud-only or synced from AD)
2. **Collect evidence first** (always, even without `-Apply`), saved to `Backups/Incidents/<user>_<date>/`:
   * `inbox-rules.json`: every inbox rule
   * `sign-ins.csv`: sign-ins from the last 7 days (time, IP, country, app, result)
   * `mfa-methods.json`: registered MFA methods and when they were added
   * Mailbox forwarding settings
3. Plan the containment
4. Save a **before** snapshot
5. **Disable the account** (in AD for synced users, so the next sync doesn't undo it, and in Entra)
6. **Reset the password** to a long random one nobody knows
7. **Sign out every session** (refresh tokens revoked)
8. **Remove mailbox forwarding**
9. **Disable suspicious inbox rules**: ones that forward, redirect, delete, or move mail to folders nobody checks (RSS Feeds, Conversation History, Archive...). Disabled, not deleted, so they stay as evidence
10. Save an **after** snapshot
11. Write a report with a **FOLLOW UP** list for a human:
    * MFA methods added recently (attackers register their own to get back in)
    * Sign-ins from more than one country
    * Check sent items and recently shared files
    * Give the user new sign-in details once it's safe
12. Alert the team (always: an incident is never routine)

Steps 4–10 only run with `-Apply`. If one containment step fails, the rest still run: partly contained is better than open.

---

## Usage

Evidence only (changes nothing):
```powershell
.\IncidentResponse\Invoke-CompromisedAccountResponse.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com
```
Contain:
```powershell
.\IncidentResponse\Invoke-CompromisedAccountResponse.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com -Apply
```
Look further back: `-SignInDays 30`

---

## Config (`IncidentResponse.json`)

Just sign-in details and optional alerts:
```json
{
    "TenantDomain": "contoso.onmicrosoft.com",
    "TenantId": "00000000-0000-0000-0000-000000000000",
    "ClientId": "11111111-1111-1111-1111-111111111111",
    "CertThumbprint": "0000000000000000000000000000000000000000",
    "AlertWebhookUrl": "secret:ClientA-TeamsWebhook"
}
```

Graph: `User.ReadWrite.All`, `AuditLog.Read.All`, `UserAuthenticationMethod.Read.All`. Exchange: *Mail Recipients*. AD: disable and reset password on user OUs.
Protected accounts are **not** blocked here on purpose: a compromised admin is exactly who you need to lock out.
