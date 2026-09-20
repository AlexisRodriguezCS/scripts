# Mailbox Size Warnings

Emails people before their mailbox fills up. A full mailbox stops sending (and then receiving) mail, which always turns into an urgent ticket.

Pipeline details: [Docs/MailboxQuota.md](Docs/MailboxQuota.md)

---

## Steps

1. Get every user mailbox and its size limit (mailboxes with no limit are skipped)
2. Get how much each one is using
3. Pick the highest warning level reached: 80%, 90% or 95% (configurable `WarnAtPercent`)
4. Skip if that warning was already sent this month (no daily spam, safe to run as often as you like)
5. Email the user from the IT mailbox
6. Remember what was sent
7. Write a report to `Reports/` (only mailboxes over a level)

Steps 5–6 only run with `-Apply`. Run it once a day on a schedule.

---

## Usage

Preview:
```powershell
.\MailboxQuota\MailboxQuota.ps1 -Client "ClientA"
```
Send:
```powershell
.\MailboxQuota\MailboxQuota.ps1 -Client "ClientA" -Apply
```

---

## Config (`MailboxQuota.json`)

```json
{
    "WarnAtPercent": [80, 90, 95],
    "SenderMailbox": "it-helpdesk@contoso.com",
    "EmailSubject": "Your mailbox is {Percent}% full",
    "EmailBody": "Hi {Name},\n\nYour mailbox is using {Used} GB of {Quota} GB.\nPlease empty Deleted Items and archive or delete old mail.\n\nIT Help Desk",
    "TenantDomain": "contoso.onmicrosoft.com",
    "TenantId": "00000000-0000-0000-0000-000000000000",
    "ClientId": "11111111-1111-1111-1111-111111111111",
    "CertThumbprint": "0000000000000000000000000000000000000000"
}
```

Exchange: *View-Only Recipients*. Graph: `Mail.Send` (limit it to the sender mailbox with an application access policy).
