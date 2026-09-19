# Password Expiry Reminders

Emails people before their password expires, so they change it in time instead of calling the help desk locked out.

Pipeline details: [Docs/PasswordExpiry.md](Docs/PasswordExpiry.md)

---

## Steps

1. Get every enabled AD user whose password expires
2. Work out days left
3. Pick the reminder: 14, 7 or 1 day (configurable `NotifyDays`)
4. Skip if that reminder was already sent (no duplicate emails, even if run many times a day)
5. Flag anyone due a reminder with no email address
6. Send the email from the IT mailbox
7. Remember what was sent
8. Write a report to `Reports/`

Steps 6–7 only run with `-Apply`.

If a day is missed (server down), the next run still sends the right reminder.

---

## Usage

Preview who would get an email:
```powershell
.\PasswordExpiry\PasswordExpiry.ps1 -Client "ClientA"
```
Send:
```powershell
.\PasswordExpiry\PasswordExpiry.ps1 -Client "ClientA" -Apply
```

Run it once a day on a schedule.

---

## Email

Subject and body come from config, so wording can change without touching code:

```json
"EmailSubject": "Your password expires in {Days}",
"EmailBody": "Hi {Name},\n\nYour password expires {Date} ({Days}).\nChange it here: {ResetUrl}\n\nIT Help Desk"
```

Needs Graph permission `Mail.Send` for `SenderMailbox`.
