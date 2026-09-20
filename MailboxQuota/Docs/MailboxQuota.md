## Mailbox Quota Module – Processing Pipeline

### Overview

Warns people before their mailbox is full, so IT hears about it before "I can't send email". Runs daily; each warning level is sent once a month at most.

---

## Processing Order

### 1. Collect

**Function:** `Get-MailboxQuotaData`

* Every user mailbox from Exchange Online with its send quota
* `ConvertTo-Bytes` reads Exchange's size strings (`"49.5 GB (53,150,220,288 bytes)"`) and returns the byte count
* Mailboxes with an unlimited quota are skipped: they can't fill up
* Percentage used is worked out per mailbox

> One statistics call per mailbox. Fine for a few thousand; past that, switch to a scheduled usage report export.

---

### 2. Test

**Function:** `Test-MailboxQuota`

* Highest level in `WarnAtPercent` the mailbox has reached, e.g. 92% full → the 90% warning
* Under every level → `Ok`, and it never appears in the report
* Sent key is `mailbox | level | year-month`, so the same person gets one warning per level per month even though the script runs daily

---

### 3. Send

**Action:** `Send-MailboxQuotaWarning`

* Subject and body come from config, with `{Name}`, `{Percent}`, `{Used}` and `{Quota}` filled in literally (a name containing `$1` stays as typed)
* Sent from `SenderMailbox` through Graph, not saved to Sent Items
* Retried 3 times through the shared retry engine

---

### 4. Remember

* Sent warnings are written to `Logs/SentWarnings_<Client>.json`
* Entries older than ~2 months are dropped on load, so the file never grows without limit
* In a dry run nothing is sent and nothing is remembered

---

### 5. Report

* `Reports/MailboxQuotaReport_<date>.txt` — only mailboxes over a level
* Alert and exit code 1 if any email failed to send

---

## Config

| Key | Example | Meaning |
|---|---|---|
| `WarnAtPercent` | `[80, 90, 95]` | Levels that trigger a warning |
| `SenderMailbox` | `it-helpdesk@contoso.com` | Who the email comes from |
| `EmailSubject` | `Your mailbox is {Percent}% full` | Template |
| `EmailBody` | `Hi {Name}, {Used} of {Quota} GB used.` | Template |

---

## Permissions

Exchange Online `Exchange.ManageAsApp` (read mailbox sizes) and Graph `Mail.Send` (send as the sender mailbox).
