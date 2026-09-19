# Roadmap

What a business actually needs from identity automation: **stay secure, stop wasting money, pass audits, save help desk time.**

---

## Done

**Employee lifecycle (Joiner – Mover – Leaver)**
- [x] **Onboarding** – new hire gets account, groups, email lists, license, random temp password
- [x] **Role change (mover)** – new title/department/manager, old role access swapped for new
- [x] **User attributes** – HR/IT update details (title, phone, office...), only what changed
- [x] **Offboarding** – lock out, remove access, mailbox + OneDrive to manager, free licenses
- [x] **One person or bulk** – every people script takes parameters or a CSV

**Security**
- [x] **Inactive accounts** – disable unused employees, remove old guests, safety stop
- [x] **MFA gaps** – no MFA, admins on SMS only
- [x] **Admin audit** – role holders, too many Global Admins, guests with admin
- [x] **Mail forwarding audit** – forwarding and inbox rules to outside addresses
- [x] **Expiring app secrets / certificates**

**Save money**
- [x] **License report** – bought vs assigned, cost per department
- [x] **Wasted licenses** – unused, on disabled accounts, on idle accounts

**Audits and compliance**
- [x] **Access review** – one sheet per manager, Keep/Remove
- [x] **Offboarding check** – leavers still enabled, in groups, or licensed
- [x] **Before/after snapshots** – every change recorded as JSON

**Help desk**
- [x] **Password expiry emails** – 14/7/1 days, never duplicated

**Platform**
- [x] **HR self-service** – SharePoint list + approval, results written back in plain English
- [x] **Scheduled / emergency** – requests run at a set time (a leaver's last day at 5 PM) or ASAP
- [x] **Alerts** – Teams and/or email when anything needs attention
- [x] **Scheduled tasks** – one setup script, runs as a gMSA (no stored password)

---

## Next up

### Foundation
- [ ] **Home lab** – domain controller + Entra Connect on Proxmox/Hyper-V, run everything for real, add screenshots to the READMEs
- [ ] **Cloud / Hybrid / On-prem** – one `Environment` setting; shared pipeline, per-environment actions (`Actions/Cloud`, `Actions/Hybrid`, `Actions/OnPrem`), CI tests each environment separately

### 1. Gaps job postings ask for
- [x] **Intune device cleanup** – retire devices not seen in 90 days, delete records after 180 (`StaleDevices`)
  - *Why:* Intune is in almost every Microsoft 365 admin posting.
- [x] **Leaver device retire** – offboarding retires the leaver's phones/laptops (company data removed, personal data untouched)
  - *Why:* otherwise company data walks out the door on personal phones.
- [x] **Conditional Access backup + change detection** – every policy backed up to JSON, added/changed/deleted policies flagged (`Audits -Check ConditionalAccess`)
  - *Why:* a changed CA policy is a common cause of both breaches and outages, and CA is named in most postings.
- [x] **Temporary Access Pass onboarding** – optional one-time sign-in code for day one (`UseTemporaryAccessPass`)
  - *Why:* passwordless is the modern standard; no password ever exists to leak.

### 2. Security operations
- [x] **Compromised account response** – evidence first, then disable, reset, sign out, remove forwarding and malicious inbox rules (`IncidentResponse`)
  - *Why:* the "someone got phished" playbook, run in seconds instead of from memory.
- [ ] **Risky sign-ins report** – new countries, impossible travel, risky users from Entra
- [ ] **Privileged access review** – permanent vs PIM-eligible admin roles
- [x] **Email security check** – SPF, DKIM and DMARC for every domain (`Audits -Check EmailSecurity`)
  - *Why:* spoofing protection; also listed in postings.

### 3. Groups and access hygiene
- [ ] **Empty / ownerless groups and Teams** – clean up or assign an owner
- [ ] **Shared mailbox access report** – who can read which shared mailboxes
- [ ] **External sharing report** – SharePoint/OneDrive files shared outside the company

### 4. Help desk
- [ ] **Account unlock + password reset** through the request list
- [ ] **Group / distribution list membership requests** through the request list, with manager approval
- [ ] **Mailbox size warnings** before mailboxes fill up

### Later
- [ ] **Undo from snapshot** – restore a user's groups/attributes from a before-snapshot
- [ ] **Offboarding extras** – hide from address book, remove from Teams/SharePoint sites
- [ ] **Before/after HTML report** – readable page generated from the snapshots, for demos and tickets
- [ ] **PowerShell Universal portal** – live buttons for the scripts, written in PowerShell only

---

## Last: demo portal

A small web page, hosted on the lab PC, that shows what the scripts do in real time:

- Pick a request (new hire, role change, leaver, update info) and watch each step run with a progress animation
- Each change shown as it happens, e.g. **Lisa Taylor – Title: Accountant → Finance Manager ✓**
- Offboarding shows the user's **before** and **after** side by side (from the snapshots): enabled → disabled, 5 groups → 0, E3 license → none, mailbox → shared
- Reads the same reports and snapshots the scripts already write, so it doesn't change how anything works

Good for demos and interviews. The real HR front door stays the SharePoint list (sign-in, permissions and approvals come free with Microsoft 365).
